class_name LeoHUD
extends Control

var game: Node3D
var heading_font: Font
var body_font: Font
var menu_root: Control
var hud_root: Control
var modal_root: Control
var scene_mode := "menu"
var labels := {}
var time := 0.0
var announcement := ""
var announcement_time := 0.0
var accent := Color("00f2fe")
var gold := Color("ff9000")
var ink := Color("090f17")
var muted := Color("9aafb7")
var photo_mode := false
var speed_overlay: ColorRect
var display_speed := 0.0
var display_nitro := 1.0
var nitro_liquid: ColorRect
var arcade_audio: AudioStreamPlayer
var arcade_streams := {}
var interaction_buttons: Array[Button] = []
var garage_buttons: Array[Button] = []
var local_lobby: LeoLocalLobby
var garage_selector: ModularCarSelector
var frontend: LeoFrontend
var unified_hud: LeoPlayerHUD
var last_ready := true
var last_drift_charged := false
var ready_flash := 0.0
var selection_flash := 0.0

func _ready() -> void:
	# A centered 1600x900 design canvas scales as a unit on every aspect ratio.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1600,900)
	get_viewport().size_changed.connect(resize_canvas)
	resize_canvas()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_font = load("res://assets/fonts/heading.ttf")
	body_font = load("res://assets/fonts/body.ttf")
	arcade_audio = AudioStreamPlayer.new()
	arcade_audio.name = "ArcadeFeedback"
	arcade_audio.volume_db = -8.0
	add_child(arcade_audio)
	for key in ["select","lap","ready","bus_horn","tuk_horn"]:
		var audio_path := "res://assets/audio/astra_%s.wav" % key
		if ResourceLoader.exists(audio_path): arcade_streams[key] = load(audio_path)
	speed_overlay = ColorRect.new()
	speed_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var effect := ShaderMaterial.new()
	effect.shader = load("res://shaders/speed_edges.gdshader")
	speed_overlay.material = effect
	speed_overlay.hide()
	add_child(speed_overlay)
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_root)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	modal_root = Control.new()
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_root)
	frontend=LeoFrontend.new();frontend.game=game;frontend.hud=self;frontend.audio=game.ui_audio;add_child(frontend)

func clear(root: Control) -> void:
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

func text_at(parent: Node, p: Vector2, size: Vector2, words: String, font_size: int = 24, color: Color = Color.WHITE, heading: bool = false) -> Label:
	var l := Label.new()
	l.position = p
	l.size = size
	l.text = words
	l.add_theme_font_override("font", heading_font if heading else body_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0 else 0)
	s.set_corner_radius_all(mini(radius,4))
	s.content_margin_left = 24
	s.content_margin_right = 24
	return s

func button(parent: Node, p: Vector2, size: Vector2, words: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.position = p
	b.size = size
	b.text = words
	b.add_theme_font_override("font", heading_font)
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", ink if primary else Color.WHITE)
	b.add_theme_color_override("font_hover_color", ink if primary else gold)
	b.add_theme_color_override("font_focus_color", ink if primary else gold)
	b.add_theme_stylebox_override("normal", style(gold if primary else Color("132746e8"), Color.TRANSPARENT if primary else Color("38506a")))
	b.add_theme_stylebox_override("hover", style(Color("ffeaa1") if primary else Color("254967"), accent))
	b.add_theme_stylebox_override("pressed", style(Color("f4bc45") if primary else Color("0b1a31"), gold))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), accent))
	b.pressed.connect(func(): play_arcade_cue("select"); callback.call())
	parent.add_child(b)
	b.pivot_offset = size * .5
	b.set_meta("selected",false)
	interaction_buttons.append(b)
	return b

## Independent player so menu cues never replace gameplay's shared sound stream.
func play_arcade_cue(key: String) -> void:
	if not is_instance_valid(arcade_audio) or not arcade_streams.has(key): return
	arcade_audio.stream = arcade_streams[key]
	arcade_audio.volume_db = -8.0 if key == "select" else -4.0
	arcade_audio.play()

func focus_link(control: Control, direction: String, target: Control) -> void:
	control.set("focus_neighbor_" + direction,control.get_path_to(target))

func choose_driver(index: int) -> void:
	game.select_driver(index)
	selection_flash = .7
	show_garage("driver")

func choose_vehicle(index: int) -> void:
	game.select_kart(index)
	selection_flash = .7
	show_garage("vehicle")

func panel(parent: Node, p: Vector2, size: Vector2, bg: Color) -> Panel:
	var n := Panel.new()
	n.position = p
	n.size = size
	n.add_theme_stylebox_override("panel", style(bg))
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/ui_glass.gdshader")
	glass.set_shader_parameter("panel_size",size)
	glass.set_shader_parameter("panel_color",Color(.025,.042,.052,.92))
	n.material = glass
	parent.add_child(n)
	return n

func backdrop(parent: Node, alpha: float = .7) -> void:
	var color := ColorRect.new()
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color.color = Color(.015, .035, .09, alpha)
	parent.add_child(color)

func show_menu() -> void:
	frontend.show_home()

func show_garage(_focus_group: String = "driver") -> void:
	var retaining:=_focus_group=="pause"
	var from_lobby:=_focus_group in ["lobby","setup"]
	var from_home:=_focus_group=="home"
	frontend.close_modal(false)
	game.input_router.gameplay_enabled=false;game.input_router.clear_all()
	if not retaining and not from_lobby:game.selected_player_slot=0
	var local: LeoLocalPlayer=game.local_players[game.selected_player_slot]
	if game.selected_player_slot==0:
		local.driver_id=game.catalog.drivers[game.selected_driver].id
		local.vehicle_id=game.catalog.vehicles[game.selected_kart].id
		local.player_name=game.custom_player_name
	game.enter_garage(retaining)
	scene_mode="garage";hud_root.hide();clear(modal_root);clear(menu_root);menu_root.show()
	garage_selector=preload("res://scenes/ModularCarSelector.tscn").instantiate()
	garage_selector.configure(game.catalog,local.driver_id,local.vehicle_id,game.reduced_motion)
	garage_selector.custom_name=local.player_name;garage_selector.race_context=retaining
	garage_selector.input_device=-2
	menu_root.add_child(garage_selector)
	garage_selector.race_button.text="Use This Ride" if from_lobby else "Back" if from_home else garage_selector.race_button.text
	garage_selector.selection_changed.connect(func(d: StringName,v: StringName):
		game.preview=garage_selector.assembly
		if not retaining:game.apply_garage_selection(d,v,garage_selector.custom_name)
		play_arcade_cue("select");game.ui_audio.say("choice");garage_selector.identity.text="Nice choice!")
	garage_selector.name_changed.connect(func(value: String):
		if not retaining:game.apply_garage_selection(garage_selector.driver_id,garage_selector.vehicle_id,value))
	garage_selector.race_requested.connect(func(d: StringName,v: StringName):
		game.apply_garage_selection(d,v,garage_selector.custom_name)
		if from_lobby:frontend.show_setup()
		else:game.return_menu())
	garage_selector.continue_requested.connect(func(d: StringName,v: StringName):game.swap_player_vehicle(d,v,garage_selector.custom_name))
	garage_selector.back_requested.connect(func():
		if retaining:game.cancel_pause_garage()
		elif from_lobby:frontend.show_setup()
		else:game.return_menu())
	game.preview=garage_selector.assembly
	garage_selector.driver_buttons[game.catalog.driver_index(local.driver_id)].grab_focus()
	queue_redraw()

func modal(title: String, subtitle: String = "") -> void:
	clear(modal_root)
	backdrop(modal_root)
	panel(modal_root, Vector2(425, 135), Vector2(750, 645), Color("0a1933"))
	text_at(modal_root, Vector2(480, 175), Vector2(650, 63), title, 43, Color.WHITE, true)
	if not subtitle.is_empty(): text_at(modal_root, Vector2(482, 247), Vector2(640, 35), subtitle, 18, accent)

func show_guide() -> void:
	frontend.show_guide()

func show_settings() -> void:
	frontend.show_settings()

func close_settings() -> void:
	frontend.close_modal()

func show_race() -> void:
	frontend.close_modal(false)
	scene_mode="race";photo_mode=false;labels.clear();clear(hud_root);menu_root.hide();speed_overlay.hide()
	game.input_router.gameplay_enabled=true;game.input_router.assignment_locked=true;game.input_router.clear_all()
	if game.human_count==2:hud_root.hide();return
	hud_root.show()
	unified_hud=LeoPlayerHUD.new();unified_hud.game=game;unified_hud.slot=0;hud_root.add_child(unified_hud)

func announce(words: String, duration: float = 1.8) -> void:
	announcement = words
	announcement_time = duration
	if game and not game.local_players.is_empty():
		game.local_players[0].announcement=words;game.local_players[0].announcement_time=duration

func pause_menu() -> void:
	frontend.show_pause()

func show_results() -> void:
	frontend.show_results()

func _process(dt: float) -> void:
	if scene_mode=="race" and game.human_count==2:
		hud_root.hide();speed_overlay.hide();return
	var visual_dt := 0.0 if game and game.paused else dt
	time += visual_dt
	ready_flash = maxf(0.0,ready_flash-visual_dt)
	selection_flash = maxf(0.0,selection_flash-visual_dt)
	for i in range(interaction_buttons.size()-1,-1,-1):
		var b := interaction_buttons[i]
		if not is_instance_valid(b):
			interaction_buttons.remove_at(i)
			continue
		var selected: bool = b.get_meta("selected",false)
		var focused := b.has_focus() or b.is_hovered()
		var motion: bool = not game or not game.reduced_motion
		var pulse := sin(time*4.5)*.045 if selected and motion else 0.0
		var brightness := 1.0+pulse if selected else (1.06 if focused else 1.0)
		b.modulate = Color(brightness,brightness,brightness,1.0)
		var target_scale := Vector2.ONE*(1.018 if focused and motion else 1.0)
		b.scale = b.scale.lerp(target_scale,1.0-exp(-visual_dt*16.0))
	if scene_mode == "race" and not labels.is_empty() and is_instance_valid(game.player):
		var p: LeoKart = game.player
		var actual_speed := absf(p.wheel_motion_speed)
		speed_overlay.visible = not photo_mode
		var intensity := speed_line_strength(actual_speed,p.boost_time>0,p.active,game.reduced_motion)
		(speed_overlay.material as ShaderMaterial).set_shader_parameter("strength",intensity)
		(speed_overlay.material as ShaderMaterial).set_shader_parameter("animation_time",time)
		(speed_overlay.material as ShaderMaterial).set_shader_parameter("glitch",game.feedback.get_recover_glitch())
		labels.position.text = str(game.player_place())
		labels.lap.text = "%d / 3" % p.lap
		labels.timer.text = game.format_time(p.finish_time if p.finished else game.race_time)
		display_speed = lerpf(display_speed,actual_speed*3.6,1.0-exp(-visual_dt*12))
		display_nitro = lerpf(display_nitro,p.boost_fuel,1.0-exp(-visual_dt*10))
		if is_instance_valid(nitro_liquid):
			(nitro_liquid.material as ShaderMaterial).set_shader_parameter("fuel",display_nitro)
			(nitro_liquid.material as ShaderMaterial).set_shader_parameter("animation_time",time)
			(nitro_liquid.material as ShaderMaterial).set_shader_parameter("motion",0.0 if game.reduced_motion else 1.0)
		labels.speed.text = "%03d" % int(actual_speed*3.6)
		var drift_charged := p.drifting and p.drift_charge>=.65
		var nitro_ready := p.boost_fuel>=.999
		if p.active and not game.paused:
			if nitro_ready and not last_ready:
				play_arcade_cue("ready")
				ready_flash = 1.25
				if announcement_time<.2: announce("NITRO FULL // LET IT RIP!",1.35)
			if drift_charged and not last_drift_charged:
				play_arcade_cue("ready")
				if announcement_time<.2: announce("DRIFT CHARGED // RELEASE!",.95)
			last_ready = nitro_ready
			last_drift_charged = drift_charged
		labels.drift.text = "RELEASE FOR BOOST!" if drift_charged else ("BUILDING DRIFT..." if p.drifting else "")
		labels.drift.modulate = Color(1.0,1.0,1.0,1.0 if not drift_charged or game.reduced_motion else .8+sin(time*9.0)*.2)
		labels.nitro.text = "NITRO READY" if nitro_ready else "CHARGING %d%%"%int(p.boost_fuel*100)
		labels.nitro.modulate = Color(1.0,1.0,1.0,1.0 if game.reduced_motion or ready_flash<=0 else .8+sin(time*12.0)*.2)
		labels.sector.text = game.circuit.sector_name(p.last_s)
		labels.progress.text = "LAP PROGRESS  %02d%%" % int(fposmod(p.last_s/game.circuit.length,1.0)*100.0)
		var approach: Vector3 = game.circuit.direction(p.last_s+4.0)
		var bend: Vector3 = game.circuit.direction(p.last_s+28.0+actual_speed*.35)
		var bend_angle := atan2(approach.cross(bend).y,approach.dot(bend))
		labels.corner.text = (("HARD " if absf(bend_angle)>.85 else "")+("RIGHT AHEAD" if bend_angle>0 else "LEFT AHEAD")) if p.active and actual_speed>4.0 and absf(bend_angle)>.3 else "FIND YOUR FLOW"
		labels.launch.visible = game.state=="countdown"
		if game.state == "countdown": labels.countdown.text = str(clampi(int(ceil(game.countdown)),1,3))
		else: labels.countdown.text = "GO!" if game.race_time < .85 else ""
		if not game.paused: announcement_time = maxf(0, announcement_time - dt)
		labels.callout.text = announcement if announcement_time > 0 else ""
		if game.wrong_way_time > 1.0: labels.callout.text = "WRONG WAY  /  TURN AROUND"
	else:
		speed_overlay.hide()
	queue_redraw()

func resize_canvas() -> void:
	var available := get_viewport_rect().size
	var factor := minf(available.x/1600.0,available.y/900.0)
	scale = Vector2.ONE*factor
	position = (available-Vector2(1600,900)*factor)*.5

static func speed_line_strength(speed_mps: float,boosting: bool,active: bool,reduced: bool) -> float:
	if not active or reduced:return 0.0
	return maxf(1.0 if boosting and speed_mps>8 else 0.0,smoothstep(150.0,180.0,absf(speed_mps)*3.6)*.65)

func _draw() -> void:
	pass

func show_controls(slot: int = 0) -> void:
	frontend.show_controls(slot)

func show_lobby() -> void:
	frontend.show_setup(2)

func show_local_results() -> void:
	frontend.show_results()

func show_rankings() -> void:
	frontend.show_records()

func show_tracks() -> void:
	frontend.show_tracks()
