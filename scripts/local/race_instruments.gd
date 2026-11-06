class_name LeoRaceInstruments
extends Control
## Shared glass instruments. The same vector dial and map serve every viewport.
var game: Node3D
var slot:=0
var heading_font: Font
var body_font: Font
static var instrument_heading: FontFile
static var instrument_body: FontFile
var labels: Dictionary={}
var binding_hints: Array[Label]=[]
const ACTIONS=["drift","boost","recover","horn","pause_race"]
var speed_overlay: ColorRect
var recovery_overlay: ColorRect
var nitro_liquid: ColorRect
var display_rpm := 900.0
var display_speed:=0.
var display_nitro:=1.
var time:=0.
var ready_flash:=0.
var last_ready:=true
var last_drift_charged:=false
var announcement:=""
var announcement_time:=0.
var accent:=Color("00f2fe")
var gold:=Color("ffb94f")
var muted:=Color("b9d0d5")
var layout_extent:=Vector2.ZERO
var view_layout:=""
var countdown_container: SubViewportContainer
var countdown_letters: Node3D
var countdown_view: SubViewport
var camera_fade: ColorRect
var diagnostic_clock := 0.0
var diagnostic_extent := Vector2i.ZERO
var speed: Label
var static_view: SubViewport
var static_canvas: Control
var static_image: TextureRect
var static_key: String=""
var map_projection:=Transform2D.IDENTITY
var profile_usec:=0
var profile_frames:=0
var background_updates:=0
func text_at(parent: Node,p: Vector2,extent: Vector2,words: String,fs: int=24,color: Color=Color.WHITE,heading: bool=false) -> Label:
	var label:=Label.new();label.position=p;label.size=extent;label.text=words
	label.add_theme_font_override("font",heading_font if heading else body_font);label.add_theme_font_size_override("font_size",fs);label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color(.015,.025,.04,.9));label.add_theme_constant_override("outline_size",2);label.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(label)
	label.set_meta("design_size",extent);label.set_meta("design_position",p);label.set_meta("font_size",fs);return label
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	if not instrument_heading:
		instrument_heading=load("res://assets/fonts/heading.ttf").duplicate();instrument_heading.multichannel_signed_distance_field=true
		instrument_body=load("res://assets/fonts/body.ttf").duplicate();instrument_body.multichannel_signed_distance_field=true
	heading_font=instrument_heading;body_font=instrument_body
	speed_overlay=ColorRect.new();speed_overlay.mouse_filter=MOUSE_FILTER_IGNORE
	var effect:=ShaderMaterial.new();effect.shader=load("res://shaders/speed_edges.gdshader");speed_overlay.material=effect;add_child(speed_overlay)
	recovery_overlay=ColorRect.new();recovery_overlay.mouse_filter=MOUSE_FILTER_IGNORE;var recovery:=ShaderMaterial.new();recovery.shader=preload("res://shaders/recovery_edges.gdshader");recovery_overlay.material=recovery;add_child(recovery_overlay)
	build()
	speed=labels.speed
	LeoSpeedDigits.configure(speed)
	get_tree().root.focus_entered.connect(log_digits.bind("focus"))
	get_tree().root.size_changed.connect(log_digits.bind("resize"))
	log_digits("ready")
	for child in get_children():
		if child is Control and not child.has_meta("design_position"):child.set_meta("design_position",child.position)
	layout()
	static_view=SubViewport.new();static_view.transparent_bg=true;static_view.disable_3d=true;static_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(static_view)
	static_canvas=load("res://scripts/local/telemetry_background.gd").new();static_canvas.instruments=self;static_view.add_child(static_canvas)
	static_image=TextureRect.new();static_image.texture=static_view.get_texture();static_image.show_behind_parent=true;static_image.mouse_filter=MOUSE_FILTER_IGNORE;add_child(static_image);move_child(static_image,0)
func build() -> void:
	labels.position = text_at(self, Vector2(65, 46), Vector2(170, 80), "1", 76, accent, true)
	labels.position.add_theme_constant_override("outline_size",1)
	labels.position.add_theme_color_override("font_outline_color",Color("d4af37"))
	text_at(self, Vector2(142, 88), Vector2(140, 35), "/ 6", 27, Color.WHITE, true)
	text_at(self, Vector2(68, 133), Vector2(180, 25), "POSITION", 16, muted, true)
	labels.lap = text_at(self,Vector2(325,48),Vector2(200,52),"1 / 3",42,accent,true)
	labels.timer = text_at(self,Vector2(325,106),Vector2(215,30),"00:00.000",21,Color.WHITE)
	text_at(self,Vector2(326,140),Vector2(180,25),"LAP // RACE TIME",14,muted,true)
	labels.track=text_at(self,Vector2(590,36),Vector2(575,35),game.track_definition.display_name.to_upper(),21,Color("bce7e7"),true)
	labels.sector = text_at(self,Vector2(755,77),Vector2(400,28),"COASTAL PROMENADE",16,gold,true)
	labels.progress = text_at(self,Vector2(595,106),Vector2(270,25),"LAP PROGRESS  0%",14,muted,true)
	labels.corner = text_at(self,Vector2(858,106),Vector2(300,25),"",14,accent,true)
	labels.corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	labels.brand=text_at(self,Vector2(1282,51),Vector2(280,55),"LEO RACER",37,Color("e7f5f7"),true)
	labels.brand.clip_text=true;labels.brand.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var lion := TextureRect.new()
	lion.texture = load("res://assets/art/neon_lion.svg")
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lion.position = Vector2(1207,44)
	lion.size = Vector2(64,64)
	lion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.add_child(lion)
	labels.speed = text_at(self,Vector2(1293,663),Vector2(220,110),"000",91,Color("c3fcff"),true)
	labels.speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.speed.add_theme_constant_override("shadow_outline_size",4)
	labels.speed.add_theme_color_override("font_shadow_color",Color(0,.8,.9,.24))
	labels.speed_unit=text_at(self,Vector2(1370,773),Vector2(110,27),"KM/H",18,muted,true)
	labels.rpm_unit=text_at(self,Vector2(1340,639),Vector2(150,24),"RPM × 1000",16,muted,true)
	labels.nitro = text_at(self,Vector2(1198,854),Vector2(160,25),"NITRO READY",17,Color("69e9b2"),true)
	labels.drift = text_at(self, Vector2(575, 758), Vector2(500, 35), "", 23, accent, true)
	labels.drift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var carbon:=ColorRect.new()
	carbon.position=Vector2(47,840)
	carbon.size=Vector2(836,36)
	carbon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var carbon_material:=ShaderMaterial.new()
	carbon_material.shader=load("res://shaders/control_carbon.gdshader")
	carbon.material=carbon_material
	self.add_child(carbon)
	for i in ACTIONS.size():
		binding_hints.append(text_at(self,Vector2(59+i*165,842),Vector2(72,28),"",15,accent,true))
		text_at(self,Vector2(129+i*165,842),Vector2(95,28),["DRIFT","NITRO","RECOVER","HORN","PAUSE"][i],15,Color("dfebf2"),true)
	nitro_liquid=ColorRect.new()
	nitro_liquid.position=Vector2(1200,520)
	nitro_liquid.size=Vector2(400,400)
	nitro_liquid.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var liquid:=ShaderMaterial.new()
	liquid.shader=load("res://shaders/nitro_liquid.gdshader")
	nitro_liquid.material=liquid
	self.add_child(nitro_liquid)
	labels.countdown = text_at(self, Vector2(250, 310), Vector2(1100, 180), "3", 126, gold, true)
	labels.countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.countdown.visible=false
	labels.callout = text_at(self, Vector2(400, 225), Vector2(800, 65), "", 37, gold, true)
	labels.callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.launch = text_at(self,Vector2(380,517),Vector2(840,35),"TAP ACCELERATE ON THE FINAL BEAT FOR A LAUNCH BOOST",20,accent,true)
	labels.launch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_fade=ColorRect.new();camera_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;camera_fade.color=Color(0,0,0,0);camera_fade.z_index=20;add_child(camera_fade)
	countdown_container=SubViewportContainer.new();countdown_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	countdown_container.hide();countdown_container.position=Vector2(400,300);countdown_container.size=Vector2(800,240);add_child(countdown_container)
	countdown_view=SubViewport.new();countdown_view.size=Vector2i(800,240);countdown_view.transparent_bg=true;countdown_view.own_world_3d=true
	countdown_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;countdown_container.add_child(countdown_view)
	countdown_letters=load("res://scripts/CountdownLetters.cs").new();countdown_view.add_child(countdown_letters)
	queue_redraw()

func log_digits(reason: String) -> void:
	if is_instance_valid(speed):LeoSpeedDigits.diagnostic(speed,reason,slot)

func layout() -> void:
	var available: Vector2=get_parent().size if get_parent() is Control else get_viewport_rect().size
	layout_extent=available
	view_layout=LeoCameraViews.effective(game.local_players[slot])
	var design_width:=800. if game.human_count==2 else 1600.
	var factor:=minf(available.x/design_width,available.y/900.)
	scale=Vector2.ONE*factor;size=Vector2(design_width,available.y/maxf(.01,factor));position=Vector2((available.x-design_width*factor)*.5,0)
	var extra:=size.y-900.
	for child in get_children():
		if not child is Control or not child.has_meta("design_position"):continue
		child.visible=game.human_count==1
		if child.has_meta("design_size"):child.size=child.get_meta("design_size")
		var design: Vector2=child.get_meta("design_position");child.position=design+Vector2(0,extra if design.y>=450 else 0.)
		if design.y>=836 and design.x<1100:child.visible=game.human_count==1
		if child is Label:
			var fs: int=child.get_meta("font_size",20);child.add_theme_font_size_override("font_size",fs)
	speed_overlay.position=Vector2.ZERO;speed_overlay.size=size
	recovery_overlay.position=Vector2.ZERO;recovery_overlay.size=size
	camera_fade.size=size
	if game.human_count==2:
		compact_label(labels.position,Vector2(34,20),Vector2(92,48),40)
		compact_label(labels.lap,Vector2(140,22),Vector2(150,36),30)
		compact_label(labels.timer,Vector2(140,61),Vector2(172,28),22)
		compact_label(labels.brand,Vector2(330,22),Vector2(440,34),26)
		compact_label(labels.track,Vector2(330,65),Vector2(440,28),20)
		compact_label(labels.callout,Vector2(24,126),Vector2(752,40),24)
		compact_label(labels.launch,Vector2(24,size.y-260),Vector2(752,32),18)
		compact_label(labels.drift,Vector2(24,size.y-300),Vector2(752,32),20)
		compact_label(labels.speed,Vector2(580,size.y-172),Vector2(180,65),62)
		compact_label(labels.speed_unit,Vector2(627,size.y-97),Vector2(90,24),16)
		compact_label(labels.rpm_unit,Vector2(604,size.y-196),Vector2(140,22),16)
		compact_label(labels.nitro,Vector2(540,size.y-29),Vector2(235,25),18)
		nitro_liquid.visible=true;nitro_liquid.position=Vector2(540,size.y-267);nitro_liquid.size=Vector2(260,260)
		countdown_container.position=Vector2(0,245);countdown_container.size=Vector2(800,240)
	else:
		countdown_container.position=Vector2(400,300)
	if view_layout=="cockpit":
		for item in [labels.rpm_unit,nitro_liquid]:item.hide()
		if game.human_count==2:
			compact_label(labels.speed,Vector2(620,size.y-93),Vector2(150,56),46)
			compact_label(labels.speed_unit,Vector2(650,size.y-35),Vector2(95,25),16)
			compact_label(labels.nitro,Vector2(400,size.y-27),Vector2(215,25),18)
		else:
			for child in get_children():
				if child is Control and child.has_meta("design_position") and child.get_meta("design_position").y>=450:child.hide()
			compact_label(labels.speed,Vector2(1450,size.y-80),Vector2(110,50),40)
			compact_label(labels.speed_unit,Vector2(1464,size.y-30),Vector2(100,24),16)
			compact_label(labels.nitro,Vector2(1210,size.y-38),Vector2(220,28),18)
			compact_label(labels.launch,Vector2(380,517),Vector2(840,35),20)
			compact_label(labels.drift,Vector2(575,size.y-142),Vector2(500,35),23)
	labels.countdown.visible=false
	speed_overlay.visible=true;recovery_overlay.visible=true;camera_fade.visible=true

func compact_label(label: Label,at: Vector2,extent: Vector2,font_size: int) -> void:
	label.visible=true;label.position=at;label.size=extent;label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size",font_size)

func rebuild_map() -> void:static_key="";queue_redraw()
func instrument_kart() -> LeoKart:
	return game.local_players[slot].kart if is_instance_valid(game.local_players[slot].kart) else null
func announce(words: String,duration: float=1.8) -> void:announcement=words;announcement_time=duration
func play_arcade_cue(key: String) -> void:
	if game.hud:game.hud.play_arcade_cue(key)
func _process(dt: float) -> void:
	if not game or not is_instance_valid(instrument_kart()):return
	var began:=Time.get_ticks_usec()
	var available: Vector2=get_parent().size if get_parent() is Control else get_viewport_rect().size
	if available!=layout_extent or view_layout!=LeoCameraViews.effective(game.local_players[slot]):layout()
	var key:=str(size)+String(game.chosen_track_id)+str(game.human_count)+view_layout
	if key!=static_key:
		background_updates+=1
		map_projection=LeoTelemetry.map_transform(game.circuit.points,Rect2(34,size.y-195,132,155) if game.human_count==2 else Rect2(62,521+size.y-900.,203,269))
		static_key=key;static_view.size=Vector2i(size);static_canvas.size=size;static_image.size=size;static_canvas.queue_redraw();static_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	visible=not game.local_players[slot].photo
	var visual_dt:=0. if game.paused else dt
	time+=visual_dt;ready_flash=maxf(0.,ready_flash-visual_dt)
	var local: LeoLocalPlayer=game.local_players[slot]
	var p: LeoKart=local.kart
	local.camera_transition=maxf(0.,local.camera_transition-dt)
	camera_fade.color.a=0. if game.reduced_motion else local.camera_transition/.16*.45
	diagnostic_clock+=dt
	if "--hud-diagnostics" in OS.get_cmdline_user_args() and diagnostic_clock>10.:
		diagnostic_clock=0.;log_digits("sample")
	var actual_speed := absf(p.wheel_motion_speed)
	var intensity := LeoHUD.speed_line_strength(actual_speed,p.boost_time>0,p.active,game.reduced_motion)
	speed_overlay.visible=not local.photo and intensity>.001
	var glitch: float=local.feedback.get_recover_glitch() if local.feedback and not game.reduced_motion else 0.
	recovery_overlay.visible=not local.photo and glitch>.001
	(recovery_overlay.material as ShaderMaterial).set_shader_parameter("glitch",glitch)
	(recovery_overlay.material as ShaderMaterial).set_shader_parameter("animation_time",time)
	(speed_overlay.material as ShaderMaterial).set_shader_parameter("strength",intensity)
	(speed_overlay.material as ShaderMaterial).set_shader_parameter("animation_time",time)
	var bindings: LeoPlayerInput=game.input_router.players[slot]
	for i in binding_hints.size():binding_hints[i].text=bindings.describe(ACTIONS[i])
	labels.position.text = str(game.player_place(slot))
	labels.lap.text = "%d / %d" % [p.lap,game.active_laps]
	labels.timer.text = game.format_time(p.finish_time if p.finished else game.race_time)
	display_rpm=lerpf(display_rpm,p.motor_audio.rpm if p.motor_audio else 900.,1.-exp(-visual_dt*12.))
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
	labels.track.text=game.track_definition.display_name.to_upper()
	labels.brand.text="P%d / %s"%[slot+1,p.racer_name] if game.human_count==2 else "LEO RACER"
	labels.progress.text = "LAP PROGRESS  %02d%%" % int(fposmod(maxf(0.,p.progress)/game.circuit.length,1.0)*100.0)
	var approach: Vector3 = game.circuit.direction(p.last_s+4.0)
	var bend: Vector3 = game.circuit.direction(p.last_s+28.0+actual_speed*.35)
	var bend_angle := atan2(approach.cross(bend).y,approach.dot(bend))
	labels.corner.text = (("HARD " if absf(bend_angle)>.85 else "")+("RIGHT AHEAD" if bend_angle>0 else "LEFT AHEAD")) if p.active and actual_speed>4.0 and absf(bend_angle)>.3 else "FIND YOUR FLOW"
	labels.launch.visible = game.state=="countdown"
	labels.launch.text="REV NOW · TAP ON 1 FOR LAUNCH BOOST" if game.human_count==2 else "REV NOW · TAP ACCELERATE ON THE FINAL BEAT FOR A LAUNCH BOOST"
	if game.state == "countdown": labels.countdown.text = str(clampi(int(ceil(game.countdown)),1,3))
	else: labels.countdown.text = "GO!" if game.race_time < .85 else ""
	var words:=str(clampi(int(ceil(game.countdown)),1,3)) if game.state=="countdown" and game.countdown<=3. else "GO!" if game.state=="race" and game.race_time<.9 else ""
	countdown_container.visible=words!=""
	countdown_letters.show_beat(words,game.reduced_motion,game.graphics.glow)
	countdown_letters.process_mode=Node.PROCESS_MODE_DISABLED if game.paused else Node.PROCESS_MODE_INHERIT
	countdown_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if words!="" else SubViewport.UPDATE_DISABLED
	if not game.paused: announcement_time = maxf(0, announcement_time - dt)
	labels.callout.text = local.announcement if local.announcement_time > 0 else announcement if announcement_time > 0 else ""
	if local.wrong_way > 1.0: labels.callout.text = "WRONG WAY  /  TURN AROUND"
	if p.checkpoint_missed:labels.callout.text="CHECKPOINT MISSED / "+bindings.describe("recover")+" RECOVER"
	queue_redraw()
	profile_usec+=Time.get_ticks_usec()-began;profile_frames+=1
func _draw() -> void:
	if game and is_instance_valid(instrument_kart()):LeoTelemetry.draw(self)
