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
var accent := Color("4cdaff")
var gold := Color("ffdb65")
var ink := Color("0a1734")
var muted := Color("b9cce3")
var photo_mode := false
var speed_overlay: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_font = load("res://assets/fonts/heading.ttf")
	body_font = load("res://assets/fonts/body.ttf")
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
	s.set_corner_radius_all(radius)
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
	b.pressed.connect(func(): game.ui_click(); callback.call())
	parent.add_child(b)
	return b

func panel(parent: Node, p: Vector2, size: Vector2, bg: Color) -> Panel:
	var n := Panel.new()
	n.position = p
	n.size = size
	n.add_theme_stylebox_override("panel", style(bg))
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
	text_at(menu_root, Vector2(89, 374), Vector2(600, 37), "Big drifts. Island energy.", 29, Color.WHITE, true)
	text_at(menu_root, Vector2(89, 417), Vector2(600, 54), "Chase the coast. Light up the Lotus.", 20, muted)
	var first := button(menu_root, Vector2(88, 507), Vector2(389, 76), "LET'S RACE     →", game.start_race, true)
	button(menu_root, Vector2(88, 600), Vector2(389, 62), "GARAGE & RACERS", show_garage)
	button(menu_root, Vector2(88, 678), Vector2(185, 57), "GUIDE", show_guide)
	button(menu_root, Vector2(288, 678), Vector2(189, 57), "SETTINGS", show_settings)
	text_at(menu_root, Vector2(89, 812), Vector2(800, 26), "LOTUS COAST    /    3 LAPS    /    6 RACERS", 17, Color("d8e7ef"), true)
	text_at(menu_root, Vector2(1230, 835), Vector2(320, 28), "LEO RACER  /  LOCAL EDITION", 14, Color.WHITE, true)
	button(menu_root, Vector2(1430, 40), Vector2(120, 46), "QUIT", game.quit_game)
	first.grab_focus()
	queue_redraw()

func show_garage() -> void:
	game.enter_garage()
	scene_mode = "garage"
	clear(menu_root)
	clear(modal_root)
	menu_root.show()
	hud_root.hide()
	panel(menu_root, Vector2.ZERO, Vector2(530, 900), Color("08162af2"))
	text_at(menu_root, Vector2(65, 50), Vector2(400, 30), "MAKE IT YOUR RACE", 18, gold, true)
	text_at(menu_root, Vector2(62, 95), Vector2(450, 70), "THE GARAGE", 50, Color.WHITE, true)
	text_at(menu_root, Vector2(65, 174), Vector2(450, 38), "01  /  CHOOSE YOUR DRIVER", 18, accent, true)
	for i in game.ROSTER.size():
		var r: Dictionary = game.ROSTER[i]
		var b := button(menu_root, Vector2(64 + (i % 2) * 212, 226 + (i / 2) * 89), Vector2(197, 72), r.name, func(): game.select_driver(i); show_garage())
		if i == game.selected_driver: b.add_theme_stylebox_override("normal", style(Color("254b69"), gold))
	text_at(menu_root, Vector2(65, 433), Vector2(400, 32), "02  /  CHOOSE YOUR KART", 18, accent, true)
	for i in game.KARTS.size():
		var k: Dictionary = game.KARTS[i]
		var b := button(menu_root, Vector2(64 + (i % 2) * 212, 479 + (i / 2) * 76), Vector2(197, 61), k.name, func(): game.select_kart(i); show_garage())
		if i == game.selected_kart: b.add_theme_stylebox_override("normal", style(Color("254b69"), gold))
	text_at(menu_root, Vector2(65, 660), Vector2(410, 55), game.ROSTER[game.selected_driver].tagline, 19, muted)
	button(menu_root, Vector2(64, 749), Vector2(303, 68), "RACE THIS COMBO  →", game.start_race, true)
	button(menu_root, Vector2(383, 749), Vector2(120, 68), "BACK", game.return_menu)
	text_at(menu_root, Vector2(970, 85), Vector2(540, 65), game.ROSTER[game.selected_driver].name.to_upper(), 55, Color.WHITE, true)
	text_at(menu_root, Vector2(973, 154), Vector2(500, 36), game.KARTS[game.selected_kart].name + "  /  COAST COLLECTION", 17, gold, true)
	var stats := [game.KARTS[game.selected_kart].speed, game.KARTS[game.selected_kart].grip, game.KARTS[game.selected_kart].accel]
	for j in range(3):
		text_at(menu_root, Vector2(1020, 680 + j * 43), Vector2(180, 30), ["TOP SPEED", "HANDLING", "ACCELERATION"][j], 16, muted, true)
		var bar := ProgressBar.new()
		bar.position = Vector2(1225, 690 + j * 43)
		bar.size = Vector2(260, 10)
		bar.show_percentage = false
		bar.value = stats[j] * 20
		bar.add_theme_stylebox_override("background", style(Color("18304b"), Color.TRANSPARENT, 5))
		bar.add_theme_stylebox_override("fill", style(gold, Color.TRANSPARENT, 5))
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
	var lines := [["WASD / ARROWS", "Accelerate, brake & steer"], ["SPACE + STEER", "Hold a drift. Release after the sparks for a boost."], ["LEFT SHIFT", "Nitro: use a full meter for a burst of speed."], ["R", "Recover at your last checkpoint"], ["ESC / P", "Pause, resume & restart"], ["CONTROLLER", "Left stick steer · RT drive · LT brake · A drift · X nitro"]]
	for i in lines.size():
		text_at(modal_root, Vector2(482, 305 + i * 57), Vector2(620, 26), lines[i][0], 17, gold, true)
		text_at(modal_root, Vector2(482, 330 + i * 57), Vector2(660, 28), lines[i][1], 17, muted)
	button(modal_root, Vector2(482, 694), Vector2(634, 54), "GOT IT", func(): clear(modal_root))

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
	button(modal_root, Vector2(482, 694), Vector2(634, 54), "BACK TO IT", close_settings)

func close_settings() -> void:
	if game.paused: pause_menu()
	else: clear(modal_root)

func show_race() -> void:
	scene_mode = "race"
	menu_root.hide()
	clear(modal_root)
	clear(hud_root)
	labels.clear()
	hud_root.show()
	labels.position = text_at(hud_root, Vector2(65, 46), Vector2(170, 80), "1", 76, gold, true)
	text_at(hud_root, Vector2(142, 88), Vector2(140, 35), "/ 6", 27, Color.WHITE, true)
	text_at(hud_root, Vector2(68, 133), Vector2(180, 25), "POSITION", 16, muted, true)
	labels.lap = text_at(hud_root, Vector2(335, 58), Vector2(220, 45), "LAP  1 / 3", 29, Color.WHITE, true)
	labels.timer = text_at(hud_root, Vector2(335, 105), Vector2(250, 30), "00:00.000", 21, muted)
	text_at(hud_root, Vector2(1260, 46), Vector2(260, 32), "LOTUS COAST", 23, Color.WHITE, true)
	labels.sector = text_at(hud_root, Vector2(1260, 81), Vector2(300, 30), "COASTAL PROMENADE", 15, gold, true)
	labels.speed = text_at(hud_root, Vector2(1326, 685), Vector2(230, 106), "000", 84, Color.WHITE, true)
	text_at(hud_root, Vector2(1440, 789), Vector2(120, 30), "KM/H", 17, muted, true)
	labels.nitro = text_at(hud_root, Vector2(1205, 849), Vector2(345, 25), "SHIFT   NITRO READY", 15, gold, true)
	labels.drift = text_at(hud_root, Vector2(575, 758), Vector2(500, 35), "", 23, accent, true)
	labels.drift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_at(hud_root, Vector2(55, 842), Vector2(1100, 28), "SPACE  DRIFT     SHIFT  NITRO     R  RECOVER     ESC  PAUSE", 15, Color("dfebf2"), true)
	labels.countdown = text_at(hud_root, Vector2(250, 310), Vector2(1100, 180), "3", 126, gold, true)
	labels.countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.callout = text_at(hud_root, Vector2(400, 225), Vector2(800, 65), "", 37, gold, true)
	labels.callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	time += dt
	if scene_mode == "race" and not labels.is_empty():
		var p: LeoKart = game.player
		speed_overlay.visible = not photo_mode
		var intensity := (1.0 if p.boost_time > 0 else clampf((absf(p.speed)-24.0)/30.0,0,.22)) if p.active else 0.0
		(speed_overlay.material as ShaderMaterial).set_shader_parameter("strength",intensity)
		labels.position.text = str(game.player_place())
		labels.lap.text = "LAP  %d / 3" % p.lap
		labels.timer.text = game.format_time(p.finish_time if p.finished else game.race_time)
		labels.speed.text = "%03d" % int(absf(p.speed) * 3.6)
		labels.drift.text = "RELEASE FOR BOOST!" if p.drift_charge >= .65 else ("BUILDING DRIFT..." if p.drifting else "")
		labels.nitro.text = "SHIFT   NITRO READY" if p.boost_fuel >= 1 else "NITRO   %d%%" % int(p.boost_fuel * 100)
		labels.sector.text = ["COASTAL PROMENADE", "FORT QUARTER", "LOTUS PLAZA", "INDEPENDENCE GARDENS"][mini(3, int(fposmod(p.last_s / game.circuit.length, 1) * 4))]
		if game.state == "countdown": labels.countdown.text = str(maxi(1, int(ceil(game.countdown))))
		else: labels.countdown.text = "GO!" if game.race_time < .85 else ""
		if not game.paused: announcement_time = maxf(0, announcement_time - dt)
		labels.callout.text = announcement if announcement_time > 0 else ""
		if game.wrong_way_time > 1.0: labels.callout.text = "WRONG WAY  /  TURN AROUND"
	else:
		speed_overlay.hide()
	queue_redraw()

func _draw() -> void:
	if scene_mode != "race" or not game or not game.player or photo_mode: return
	var shade := Color(.025, .06, .13, .78)
	draw_style_box(style(shade), Rect2(42, 36, 230, 142))
	draw_style_box(style(shade), Rect2(306, 40, 244, 121))
	draw_style_box(style(shade), Rect2(1234, 36, 321, 91))
	draw_style_box(style(shade), Rect2(1193, 668, 365, 163))
	draw_style_box(style(shade), Rect2(42, 836, 720, 45))
	draw_rect(Rect2(1208, 834, 342, 8), Color("24364c"))
	draw_rect(Rect2(1208, 834, 342 * game.player.boost_fuel, 8), gold)
	# Live track map: sampled from the exact centreline used by AI and checkpoints.
	var center := Vector2(156, 665)
	draw_style_box(style(shade), Rect2(42, 498, 242, 311))
	var line := PackedVector2Array()
	for i in range(0, game.circuit.points.size(), 3):
		var p: Vector3 = game.circuit.points[i]
		line.append(center + Vector2(p.x, p.z) * .86)
	line.append(line[0])
	draw_polyline(line, Color("7a99b2"), 9, true)
	draw_polyline(line, Color("122a40"), 5, true)
	for k in game.karts:
		var dot := center + Vector2(k.position.x, k.position.z) * .86
		draw_circle(dot, 7 if k.is_player else 4, gold if k.is_player else accent)
		if k.is_player: draw_arc(dot, 11, 0, TAU, 20, Color.WHITE, 2, true)
	if game.player.drifting:
		draw_style_box(style(shade), Rect2(600, 805, 400, 10))
		draw_rect(Rect2(600, 805, 400 * minf(1, game.player.drift_charge / 2.5), 10), gold if game.player.drift_charge > .65 else accent)
	if game.player.boost_time > 0:
		for i in range(13):
			var a := i * TAU / 13 + .16
			var c := Vector2(800, 450)
			var v := Vector2(cos(a), sin(a))
			draw_line(c + v * (650 + sin(time * 14 + i) * 40), c + v * 900, Color(.4, .9, 1, .4), 3, true)
