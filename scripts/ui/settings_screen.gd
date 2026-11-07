extends RefCounted
static func build(front: LeoFrontend) -> void:
	var game:=front.game
	var graphics: LeoGraphicsSettings=game.graphics
	var leave: Callable=front.show_pause if game.paused else front.close_modal
	var box:=front.dialog("SETTINGS","Make yourself comfortable.",func():graphics.revert_display();leave.call(),1160)
	var tabs:=TabContainer.new();tabs.name="SettingsTabs";tabs.custom_minimum_size=Vector2(0,500);tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(tabs)
	var pages: Dictionary={}
	for title in ["Graphics","Audio","Controls","Accessibility","Game Logic"]:
		var scroll:=ScrollContainer.new();scroll.name="GameLogicTab" if title=="Game Logic" else title;scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
		if title=="Game Logic":tabs.set_tab_title(tabs.get_tab_count()-1,"Game Logic")
		var margin:=MarginContainer.new();margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,16)
		scroll.add_child(margin)
		var page:=VBoxContainer.new();page.add_theme_constant_override("separation",12);page.size_flags_horizontal=Control.SIZE_EXPAND_FILL;margin.add_child(page);pages[title]=page
	var display: VBoxContainer=pages.Graphics
	front.label(display,"DISPLAY",26,Color("67d6db"))
	front.label(display,"Windowed: output resolution. Fullscreen: 3D render resolution; the display and HUD stay native.",20,Color("b9c7d6"))
	var sizes: Array[Vector2i]=[Vector2i(1280,720),Vector2i(1920,1080)]
	var native:=DisplayServer.screen_get_size()
	if native.x>=640 and native.y>=480 and native not in sizes:sizes.append(native)
	var captions: Array[String]=[]
	for size in sizes:captions.append("%d × %d%s"%[size.x,size.y," · Native" if size==native else ""])
	var resolution:=choice(front,display,"Resolution",captions,maxi(0,sizes.find(graphics.resolution)))
	var fullscreen:=CheckButton.new();fullscreen.text="Fullscreen";fullscreen.button_pressed=DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED;display.add_child(fullscreen)
	var actions:=HBoxContainer.new();display.add_child(actions)
	var status:=front.label(display,"Display changes revert after 15 seconds unless confirmed.",20)
	var apply:=front.action(actions,"Apply Display",func():graphics.preview_display(sizes[resolution.selected],fullscreen.button_pressed))
	apply.name="ApplyDisplay"
	var keep:=front.action(actions,"Keep Changes",graphics.confirm_display)
	var revert:=front.action(actions,"Revert",graphics.revert_display)
	keep.disabled=true;revert.disabled=true
	var timer:=Timer.new();timer.wait_time=.2;timer.process_mode=Node.PROCESS_MODE_ALWAYS;box.add_child(timer)
	var was_pending:=[false]
	timer.timeout.connect(func():
		if was_pending[0] and not graphics.pending:
			resolution.select(maxi(0,sizes.find(graphics.resolution)));fullscreen.button_pressed=DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED
		was_pending[0]=graphics.pending
		keep.disabled=not graphics.pending;revert.disabled=not graphics.pending
		status.text="Keep this display? Reverting in %d seconds."%graphics.remaining() if graphics.pending else "Display ready. Changes are saved when confirmed.")
	timer.start()
	front.label(display,"RENDERING",26,Color("67d6db"))
	var quality:=choice(front,display,"Quality",["Low","Medium","High","Custom"],3 if graphics.custom else game.graphics_quality)
	quality.set_item_disabled(3,true)
	var aa:=CheckButton.new();aa.text="Anti-aliasing · MSAA 2×";aa.button_pressed=graphics.aa;display.add_child(aa)
	var glow:=CheckButton.new();glow.text="Glow";glow.button_pressed=graphics.glow;display.add_child(glow)
	var blur:=CheckButton.new();blur.text="Motion Blur";blur.button_pressed=graphics.motion_blur;blur.disabled=game.reduced_motion;display.add_child(blur)
	front.label(display,"Motion blur is subtle, affects the world only, and is disabled by Reduced Motion.",20,Color("b9c7d6"))
	var upscaling:=choice(front,display,"Upscaling",["Native / Bilinear","FSR 2 · Quality","FSR 2 · Balanced"],graphics.upscale if graphics.supported_upscaling() else 0)
	upscaling.disabled=not graphics.supported_upscaling()
	if not graphics.supported_upscaling():front.label(display,"FSR 2 requires Forward+. Compatibility uses native/bilinear scaling.",20,Color("b9c7d6"))
	for entry in [[aa,"aa"],[glow,"glow"],[blur,"motion_blur"]]:
		var key: String=entry[1]
		entry[0].toggled.connect(func(value):graphics.set_option(key,value);quality.select(3))
	upscaling.item_selected.connect(func(index):graphics.set_option("upscale",index);quality.select(3))
	quality.item_selected.connect(func(index):
		if index>=3:return
		game.set_graphics_quality(index);aa.set_pressed_no_signal(graphics.aa);glow.set_pressed_no_signal(graphics.glow);blur.set_pressed_no_signal(graphics.motion_blur);upscaling.select(0))
	front.label(display,"Split-screen caps scenery quality at Medium. Your AA, glow and blur choices apply to both views.",20,Color("b9c7d6"))
	var audio: VBoxContainer=pages.Audio
	front.label(audio,"AUDIO MIX",26,Color("67d6db"))
	front.add_slider(audio,"Master",game.master_volume,game.set_volume)
	for bus in ["Music","Effects","UI","Voice","Announcer"]:
		var name: String=bus
		front.add_slider(audio,bus,float(front.audio.levels[bus]),func(value):front.audio.set_level(name,value))
	front.add_toggle(audio,"Music",game.music_enabled,game.set_music)
	front.add_toggle(audio,"Spoken cheers",front.audio.voice_enabled,front.audio.set_voice)
	var controls: VBoxContainer=pages.Controls
	front.label(controls,"DRIVING & CAMERA",26,Color("67d6db"))
	front.label(controls,"Cockpit: right stick looks around the cabin and side mirrors. Camera look directions can be rebound below.",20,Color("b9c7d6"))
	front.action(controls,"Configure Buttons & Devices",front.show_controls)
	for slot in game.human_count:
		var index: int=slot
		var local: LeoLocalPlayer=game.local_players[slot]
		var vehicle: VehicleDefinition=local.kart.definition if is_instance_valid(local.kart) else LeoVehiclePresentation.resolve(game.catalog.vehicle(local.vehicle_id))
		var options:=LeoCameraViews.available(vehicle)
		var names: Array[String]=[]
		for mode in options:names.append(LeoCameraViews.NAMES[mode])
		var camera:=choice(front,controls,"Player %d camera"%(slot+1),names,maxi(0,options.find(local.camera_view)))
		camera.item_selected.connect(func(selected):
			game.local_players[index].camera_view=options[selected];game.local_players[index].camera_rig.reset();game.local_players[index].camera_transition=.16;game.save_settings())
		if not "cockpit" in options:front.label(controls,"Cockpit view is available when your selected vehicle has a reviewed detailed interior.",20,Color("b9c7d6"))
	var fov:=SpinBox.new();fov.min_value=55;fov.max_value=75;fov.step=1;fov.value=game.base_camera_fov
	row(front,controls,"Field of view",fov);fov.value_changed.connect(game.set_camera_fov)
	var access: VBoxContainer=pages.Accessibility
	front.label(access,"COMFORT",26,Color("67d6db"))
	front.add_toggle(access,"Reduced Motion",game.reduced_motion,func(value):game.set_reduced_motion(value);blur.disabled=value)
	front.label(access,"Keeps gentle steering lean and acceleration/braking pitch. Disables camera shake, roll, impact jolts and motion blur.",20,Color("b9c7d6"))
	front.add_toggle(access,"Controller rumble",game.haptics.enabled,func(value):game.haptics.enabled=value;game.haptics.stop_all();game.save_settings())
	front.add_slider(access,"Strength",game.haptics.intensity,func(value):game.haptics.intensity=value;game.save_settings())
	front.action(access,"Test Rumble",func():
		for slot in game.human_count:game.input_router.identify(slot))
	var logic: VBoxContainer=pages["Game Logic"]
	front.label(logic,"AI OPPONENTS",26,Color("67d6db"))
	var bigster:=CheckButton.new();bigster.name="AllowAIBigster";bigster.text="Allow Bigster as an AI opponent";bigster.button_pressed=game.allow_ai_bigster;bigster.custom_minimum_size.y=44;logic.add_child(bigster)
	bigster.toggled.connect(game.set_allow_ai_bigster)
	front.label(logic,"Off by default. Changes apply when you start or restart a race. Bigster remains available to human players.",20,Color("b9c7d6"))
	front.action(box,"Back",func():graphics.revert_display();leave.call()).grab_focus()
	# Leaving through Escape or another modal also restores unconfirmed changes.
	box.tree_exiting.connect(func():graphics.revert_display())

static func row(front: LeoFrontend,parent: Node,title: String,control: Control) -> void:
	var line:=HBoxContainer.new();parent.add_child(line)
	front.label(line,title,22).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	control.custom_minimum_size=Vector2(260,44);line.add_child(control)

static func choice(front: LeoFrontend,parent: Node,title: String,values: Array,index: int) -> OptionButton:
	var button:=OptionButton.new()
	for value in values:button.add_item(value)
	button.select(index);row(front,parent,title,button);return button
