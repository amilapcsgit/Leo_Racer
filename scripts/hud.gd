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
	scene_mode = "menu"
	clear(menu_root)
	clear(modal_root)
	hud_root.hide()
	menu_root.show()
	var art := TextureRect.new()
	art.texture = load("res://assets/art/menu.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_root.add_child(art)
	var gradient := Gradient.new()
	gradient.set_color(0, Color("071630f5"))
	gradient.set_color(1, Color("07163000"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(.77, 0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(shade)
	text_at(menu_root, Vector2(88, 78), Vector2(420, 30), "THE COLOMBO GRAND PRIX", 18, gold, true)
	var title := text_at(menu_root, Vector2(78, 121), Vector2(600, 130), "LEO", 118, Color.WHITE, true)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", ink)
	title = text_at(menu_root, Vector2(78, 223), Vector2(600, 140), "RACER", 118, accent, true)
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", ink)
	text_at(menu_root, Vector2(89, 374), Vector2(600, 37), "ASTRA // COLOMBO COAST", 29, Color.WHITE, true)
	text_at(menu_root, Vector2(89, 417), Vector2(620, 65), "More coast. More corners. One wild harbour circuit.", 20, muted)
	var first := button(menu_root, Vector2(88, 507), Vector2(389, 76), "LET'S RACE     →", game.start_race, true)
	button(menu_root, Vector2(88, 600), Vector2(389, 62), "GARAGE & RACERS", show_garage)
	button(menu_root, Vector2(88, 678), Vector2(185, 57), "GUIDE", show_guide)
	button(menu_root, Vector2(288, 678), Vector2(189, 57), "SETTINGS", show_settings)
	text_at(menu_root, Vector2(89, 812), Vector2(800, 26), "LOTUS COAST    /    3 LAPS    /    6 RACERS", 17, Color("d8e7ef"), true)
	text_at(menu_root, Vector2(1200, 835), Vector2(350, 28), "ASTRA EDITION  //  v1.4.0", 17, accent, true)
	button(menu_root, Vector2(1430, 40), Vector2(120, 46), "QUIT", game.quit_game)
	first.grab_focus()
	queue_redraw()

func show_garage(focus_group: String = "vehicle") -> void:
	game.enter_garage()
	scene_mode = "garage"
	clear(menu_root)
	clear(modal_root)
	garage_buttons.clear()
	menu_root.show()
	hud_root.hide()
	panel(menu_root,Vector2.ZERO,Vector2(668,900),Color("081622f5"))
	text_at(menu_root,Vector2(46,32),Vector2(580,28),"ASTRA MOTOR CLUB  //  COLOMBO 2026",17,gold,true)
	text_at(menu_root,Vector2(43,69),Vector2(580,65),"THE PIT SHOP",53,Color.WHITE,true)
	text_at(menu_root,Vector2(48,145),Vector2(420,30),"01  /  PICK YOUR PERSONALITY",17,accent,true)
	text_at(menu_root,Vector2(540,145),Vector2(85,30),"%02d / %02d" % [game.selected_driver+1,game.ROSTER.size()],17,gold,true)
	var driver_buttons: Array[Button] = []
	for i in game.ROSTER.size():
		var racer: Dictionary = game.ROSTER[i]
		var driver_words: String = racer.name.to_upper().replace("SHAVEN LEO","SHAVEN\nLEO")
		var b := button(menu_root,Vector2(48+i*117,185),Vector2(108,72),driver_words,choose_driver.bind(i))
		b.add_theme_font_size_override("font_size",20)
		b.tooltip_text = racer.name + " — " + racer.tagline
		b.set_meta("selected",i==game.selected_driver)
		if i==game.selected_driver: b.add_theme_stylebox_override("normal",style(Color("164952"),gold))
		driver_buttons.append(b)
		garage_buttons.append(b)
	text_at(menu_root,Vector2(48,270),Vector2(577,34),game.ROSTER[game.selected_driver].tagline,17,muted)
	text_at(menu_root,Vector2(48,321),Vector2(470,30),"02  /  CHOOSE YOUR MACHINE",17,accent,true)
	text_at(menu_root,Vector2(540,321),Vector2(85,30),"%02d / %02d" % [game.selected_kart+1,game.KARTS.size()],17,gold,true)
	var vehicle_buttons: Array[Button] = []
	for i in game.KARTS.size():
		var vehicle: Dictionary = game.KARTS[i]
		var b := button(menu_root,Vector2(48+(i%3)*195,365+(i/3)*86),Vector2(186,74),vehicle.name.to_upper(),choose_vehicle.bind(i))
		b.add_theme_font_size_override("font_size",21 if vehicle.name.length()<14 else 18)
		b.tooltip_text = "%s | Speed %.1f | Grip %.1f | Launch %.1f" % [vehicle.name,vehicle.speed,vehicle.grip,vehicle.accel]
		b.set_meta("selected",i==game.selected_kart)
		if i==game.selected_kart: b.add_theme_stylebox_override("normal",style(Color("164952"),gold))
		vehicle_buttons.append(b)
		garage_buttons.append(b)
	text_at(menu_root,Vector2(48,639),Vector2(570,34),"YOUR COMBO. YOUR COAST.",22,gold,true)
	text_at(menu_root,Vector2(48,678),Vector2(580,55),"Every racer. Every ride. Mix it up and chase the podium.",17,muted)
	text_at(menu_root,Vector2(48,730),Vector2(580,27),"ARROWS / STICK  SELECT     ENTER / A  CONFIRM",14,accent,true)
	var race_button := button(menu_root,Vector2(48,778),Vector2(430,66),"LET'S MAKE SOME NOISE  →",game.start_race,true)
	race_button.add_theme_font_size_override("font_size",24)
	var back_button := button(menu_root,Vector2(495,778),Vector2(129,66),"BACK",game.return_menu)
	garage_buttons.append(race_button)
	garage_buttons.append(back_button)
	# Explicit spatial focus routes keep every combination accessible with a controller.
	for i in driver_buttons.size():
		focus_link(driver_buttons[i],"left",driver_buttons[posmod(i-1,driver_buttons.size())])
		focus_link(driver_buttons[i],"right",driver_buttons[(i+1)%driver_buttons.size()])
		focus_link(driver_buttons[i],"top",race_button)
		focus_link(driver_buttons[i],"bottom",vehicle_buttons[mini(2,int(round(i*2.0/maxi(1,driver_buttons.size()-1))))])
	for i in vehicle_buttons.size():
		var row := i/3
		var col := i%3
		var row_start := row*3
		focus_link(vehicle_buttons[i],"left",vehicle_buttons[row_start+posmod(col-1,mini(3,vehicle_buttons.size()-row_start))])
		focus_link(vehicle_buttons[i],"right",vehicle_buttons[row_start+(col+1)%mini(3,vehicle_buttons.size()-row_start)])
		focus_link(vehicle_buttons[i],"top",vehicle_buttons[i-3] if i>=3 else driver_buttons[mini(driver_buttons.size()-1,int(round(col*(driver_buttons.size()-1)/2.0)))])
		focus_link(vehicle_buttons[i],"bottom",vehicle_buttons[i+3] if i+3<vehicle_buttons.size() else (race_button if col<2 else back_button))
	focus_link(race_button,"right",back_button)
	focus_link(race_button,"left",back_button)
	focus_link(back_button,"left",race_button)
	focus_link(back_button,"right",race_button)
	focus_link(race_button,"top",vehicle_buttons[maxi(0,vehicle_buttons.size()-3)])
	focus_link(back_button,"top",vehicle_buttons.back())
	focus_link(race_button,"bottom",driver_buttons[game.selected_driver])
	focus_link(back_button,"bottom",driver_buttons[game.selected_driver])
	if focus_group=="driver": driver_buttons[game.selected_driver].grab_focus()
	else: vehicle_buttons[game.selected_kart].grab_focus()
	text_at(menu_root,Vector2(741,56),Vector2(790,72),game.ROSTER[game.selected_driver].name.to_upper(),56,Color.WHITE,true)
	text_at(menu_root,Vector2(745,137),Vector2(800,44),game.KARTS[game.selected_kart].name.to_upper(),31,gold,true)
	text_at(menu_root,Vector2(747,189),Vector2(790,31),"%d RACERS  ×  %d MACHINES  =  %d WAYS TO PLAY" % [game.ROSTER.size(),game.KARTS.size(),game.ROSTER.size()*game.KARTS.size()],16,accent,true)
	var stats: Array = [game.KARTS[game.selected_kart].speed,game.KARTS[game.selected_kart].grip,game.KARTS[game.selected_kart].accel]
	for j in range(3):
		text_at(menu_root,Vector2(1043,699+j*43),Vector2(190,30),["TOP SPEED","CORNER GRIP","LAUNCH POWER"][j],16,muted,true)
		var bar := ProgressBar.new()
		bar.position = Vector2(1242,710+j*43)
		bar.size = Vector2(260,11)
		bar.show_percentage = false
		bar.value = stats[j]*20.0
		bar.add_theme_stylebox_override("background",style(Color("18304b"),Color.TRANSPARENT,4))
		bar.add_theme_stylebox_override("fill",style(accent if j==1 else gold,Color.TRANSPARENT,4))
		menu_root.add_child(bar)
	queue_redraw()

func modal(title: String, subtitle: String = "") -> void:
	clear(modal_root)
	backdrop(modal_root)
	panel(modal_root, Vector2(425, 135), Vector2(750, 645), Color("0a1933"))
	text_at(modal_root, Vector2(480, 175), Vector2(650, 63), title, 43, Color.WHITE, true)
	if not subtitle.is_empty(): text_at(modal_root, Vector2(482, 247), Vector2(640, 35), subtitle, 18, accent)

func show_guide() -> void:
	modal("FIND YOUR FLOW", "A little sideways. A lot faster.")
	var lines := [["WASD / ARROWS", "Accelerate, brake & steer"], ["SPACE + STEER", "Hold a drift. Release after the sparks for a boost."], ["LEFT SHIFT", "Nitro: use a full meter for a burst of speed."], ["H / CONTROLLER B", "Honk your ride's horn. Own the harbour."], ["R", "Recover at your last checkpoint"], ["ESC / P", "Pause, resume & restart"], ["CONTROLLER", "Left stick steer · RT drive · LT brake · A drift · X nitro"]]
	for i in lines.size():
		text_at(modal_root, Vector2(482, 299 + i * 49), Vector2(620, 26), lines[i][0], 16, gold, true)
		text_at(modal_root, Vector2(482, 321 + i * 49), Vector2(660, 28), lines[i][1], 16, muted)
	button(modal_root, Vector2(482, 694), Vector2(634, 54), "GOT IT", func(): clear(modal_root)).grab_focus()

func show_settings() -> void:
	modal("PIT SETTINGS", "Changes are saved automatically on this PC.")
	text_at(modal_root, Vector2(482, 320), Vector2(250, 30), "MASTER VOLUME", 20, gold, true)
	var slider := HSlider.new()
	slider.position = Vector2(482, 378)
	slider.size = Vector2(630, 38)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .01
	slider.value = game.master_volume
	slider.value_changed.connect(game.set_volume)
	modal_root.add_child(slider)
	slider.grab_focus()
	var check := CheckButton.new()
	check.position = Vector2(482, 455)
	check.size = Vector2(630, 55)
	check.text = "Fullscreen"
	check.add_theme_font_size_override("font_size", 24)
	check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	check.toggled.connect(game.set_fullscreen)
	modal_root.add_child(check)
	var music_check := CheckButton.new()
	music_check.position = Vector2(482, 536)
	music_check.text = "Island soundtrack"
	music_check.add_theme_font_size_override("font_size", 24)
	music_check.button_pressed = game.music_enabled
	music_check.toggled.connect(game.set_music)
	modal_root.add_child(music_check)
	var motion_check := CheckButton.new()
	motion_check.position = Vector2(482,602)
	motion_check.text = "Reduced Motion"
	motion_check.add_theme_font_size_override("font_size",24)
	motion_check.button_pressed = game.reduced_motion
	motion_check.toggled.connect(game.set_reduced_motion)
	modal_root.add_child(motion_check)
	button(modal_root, Vector2(482, 694), Vector2(634, 54), "BACK TO IT", close_settings)

func close_settings() -> void:
	if game.paused: pause_menu()
	else: clear(modal_root)

func show_race() -> void:
	scene_mode = "race"
	# Race restarts must discard photo mode, previous callouts and smoothed values.
	photo_mode = false
	announcement = ""
	announcement_time = 0.0
	display_speed = 0.0
	display_nitro = 1.0
	menu_root.hide()
	clear(modal_root)
	clear(hud_root)
	labels.clear()
	last_ready = true
	last_drift_charged = false
	ready_flash = 0.0
	hud_root.show()
	labels.position = text_at(hud_root, Vector2(65, 46), Vector2(170, 80), "1", 76, accent, true)
	labels.position.add_theme_constant_override("outline_size",1)
	labels.position.add_theme_color_override("font_outline_color",Color("d4af37"))
	text_at(hud_root, Vector2(142, 88), Vector2(140, 35), "/ 6", 27, Color.WHITE, true)
	text_at(hud_root, Vector2(68, 133), Vector2(180, 25), "POSITION", 16, muted, true)
	labels.lap = text_at(hud_root,Vector2(325,48),Vector2(200,52),"1 / 3",42,accent,true)
	labels.timer = text_at(hud_root,Vector2(325,106),Vector2(215,30),"00:00.000",21,Color.WHITE)
	text_at(hud_root,Vector2(326,140),Vector2(180,25),"LAP // RACE TIME",14,muted,true)
	text_at(hud_root,Vector2(590,36),Vector2(575,35),"ASTRA // COLOMBO COAST",21,Color("bce7e7"),true)
	labels.sector = text_at(hud_root,Vector2(755,77),Vector2(400,28),"COASTAL PROMENADE",16,gold,true)
	labels.progress = text_at(hud_root,Vector2(595,106),Vector2(270,25),"LAP PROGRESS  0%",14,muted,true)
	labels.corner = text_at(hud_root,Vector2(858,106),Vector2(300,25),"",14,accent,true)
	labels.corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_at(hud_root,Vector2(1282,51),Vector2(280,55),"LEO RACER",37,Color("e7f5f7"),true)
	var lion := TextureRect.new()
	lion.texture = load("res://assets/art/neon_lion.svg")
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lion.position = Vector2(1207,44)
	lion.size = Vector2(64,64)
	lion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(lion)
	labels.speed = text_at(hud_root,Vector2(1293,663),Vector2(220,110),"000",91,Color("c3fcff"),true)
	labels.speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.speed.add_theme_constant_override("shadow_outline_size",4)
	labels.speed.add_theme_color_override("font_shadow_color",Color(0,.8,.9,.24))
	text_at(hud_root,Vector2(1370,773),Vector2(110,27),"KM/H",18,muted,true)
	labels.nitro = text_at(hud_root,Vector2(1198,854),Vector2(160,25),"NITRO READY",17,Color("69e9b2"),true)
	labels.drift = text_at(hud_root, Vector2(575, 758), Vector2(500, 35), "", 23, accent, true)
	labels.drift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var carbon:=ColorRect.new()
	carbon.position=Vector2(47,840)
	carbon.size=Vector2(836,36)
	carbon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var carbon_material:=ShaderMaterial.new()
	carbon_material.shader=load("res://shaders/control_carbon.gdshader")
	carbon.material=carbon_material
	hud_root.add_child(carbon)
	var x:=59.0
	for prompt in [["SPACE","DRIFT"],["SHIFT","NITRO"],["R","RECOVER"],["H","HORN"],["ESC","PAUSE"]]:
		text_at(hud_root,Vector2(x,842),Vector2(72,28),prompt[0],15,accent,true)
		x+=66 if prompt[0].length()>3 else 36
		text_at(hud_root,Vector2(x,842),Vector2(100,28),prompt[1],15,Color("dfebf2"),true)
		x+=105
	nitro_liquid=ColorRect.new()
	nitro_liquid.position=Vector2(1200,520)
	nitro_liquid.size=Vector2(400,400)
	nitro_liquid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var liquid:=ShaderMaterial.new()
	liquid.shader=load("res://shaders/nitro_liquid.gdshader")
	nitro_liquid.material=liquid
	hud_root.add_child(nitro_liquid)
	labels.countdown = text_at(hud_root, Vector2(250, 310), Vector2(1100, 180), "3", 126, gold, true)
	labels.countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.callout = text_at(hud_root, Vector2(400, 225), Vector2(800, 65), "", 37, gold, true)
	labels.callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.launch = text_at(hud_root,Vector2(380,517),Vector2(840,35),"TAP ACCELERATE ON THE FINAL BEAT FOR A LAUNCH BOOST",20,accent,true)
	labels.launch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_redraw()

func announce(words: String, duration: float = 1.8) -> void:
	announcement = words
	announcement_time = duration

func pause_menu() -> void:
	modal("TAKE A BREATHER", "Your island lap will be right here.")
	button(modal_root, Vector2(482, 320), Vector2(634, 65), "RESUME RACE", game.toggle_pause, true).grab_focus()
	button(modal_root, Vector2(482, 408), Vector2(634, 65), "RESTART RACE", game.start_race)
	button(modal_root, Vector2(482, 496), Vector2(634, 65), "SETTINGS", show_settings)
	button(modal_root, Vector2(482, 584), Vector2(634, 65), "MAIN MENU", game.return_menu)

func show_results() -> void:
	scene_mode = "results"
	hud_root.hide()
	clear(modal_root)
	backdrop(modal_root, .68)
	panel(modal_root, Vector2(370, 65), Vector2(860, 770), Color("091a34f5"))
	text_at(modal_root, Vector2(430, 101), Vector2(750, 32), "COLOMBO GRAND PRIX   /   LOTUS COAST", 18, accent, true)
	text_at(modal_root, Vector2(425, 149), Vector2(780, 85), "ISLAND CHAMPION!" if game.finish_place == 1 else "WHAT A RIDE!", 55, gold, true)
	text_at(modal_root, Vector2(430, 246), Vector2(760, 35), "YOUR TIME  %s     •     BEST  %s" % [game.format_time(game.player.finish_time), game.format_time(game.best_time)], 22, Color.WHITE, true)
	text_at(modal_root, Vector2(432, 306), Vector2(760, 28), "POS        RACER                                         RACE TIME", 16, muted, true)
	var order: Array = game.ranking()
	for i in order.size():
		var k: LeoKart = order[i]
		if k.is_player: panel(modal_root, Vector2(417, 349 + i * 47), Vector2(765, 44), Color("214669"))
		text_at(modal_root, Vector2(438, 351 + i * 47), Vector2(65, 38), "%02d" % (i + 1), 24, gold if k.is_player else Color.WHITE, true)
		text_at(modal_root, Vector2(526, 351 + i * 47), Vector2(375, 38), k.racer_name + ("  /  YOU" if k.is_player else ""), 24, Color.WHITE, true)
		text_at(modal_root, Vector2(962, 351 + i * 47), Vector2(220, 38), game.format_time(k.finish_time) if k.finished else "%dm BEHIND" % int(game.circuit.length * 3 - k.progress), 22, muted)
	text_at(modal_root, Vector2(432, 663), Vector2(750, 32), "BEST LAP  %s     /     %d BOOSTS" % [game.format_time(game.best_lap), game.boost_count], 19, accent, true)
	button(modal_root, Vector2(430, 735), Vector2(350, 62), "RACE AGAIN  →", game.start_race, true).grab_focus()
	button(modal_root, Vector2(803, 735), Vector2(365, 62), "BACK TO GARAGE", show_garage)
	queue_redraw()

func _process(dt: float) -> void:
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
	if scene_mode == "race" and not labels.is_empty():
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
	if scene_mode=="garage":
		draw_line(Vector2(668,28),Vector2(668,868),Color(accent,.36),2,true)
		draw_line(Vector2(48,307),Vector2(624,307),Color(accent,.24),1,true)
		draw_line(Vector2(48,627),Vector2(624,627),Color(accent,.24),1,true)
		for b in garage_buttons:
			if not is_instance_valid(b) or not b.get_meta("selected",false): continue
			var r := Rect2(b.position-Vector2(3,3),b.size+Vector2(6,6))
			draw_rect(r,Color(gold,.55),false,2)
			draw_line(r.position,r.position+Vector2(22,0),accent,3,true)
			draw_line(r.end-Vector2(22,0),r.end,accent,3,true)
		return
	if scene_mode!="race" or not game or not game.player or photo_mode: return
	LeoTelemetry.draw(self)
