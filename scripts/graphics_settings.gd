class_name LeoGraphicsSettings
extends Node
## Optional settings preserve the existing configuration and all unknown keys.
var game: Node3D
var resolution := Vector2i(1920,1080)
var aa := true
var glow := true
var motion_blur := false
var upscale := 0
var custom := false
var pending := false
var previous := {}
var deadline := 0
signal display_finished

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(apply,CONNECT_DEFERRED)

func read(cfg: ConfigFile) -> void:
	var stored: Variant=cfg.get_value("graphics","resolution",Vector2i(1920,1080))
	if stored is Vector2i and stored.x>=640 and stored.y>=480:resolution=stored
	aa=bool(cfg.get_value("graphics","aa",true))
	glow=bool(cfg.get_value("graphics","glow",game.graphics_quality>0))
	motion_blur=bool(cfg.get_value("graphics","motion_blur",false))
	upscale=clampi(int(cfg.get_value("graphics","upscale",0)),0,2)
	custom=bool(cfg.get_value("graphics","custom",false))
	if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED:DisplayServer.window_set_size(resolution)

func write(cfg: ConfigFile) -> void:
	for key in ["resolution","aa","glow","motion_blur","upscale","custom"]:
		cfg.set_value("graphics",key,previous.resolution if key=="resolution" and pending else get(key))

func set_option(key: String,value: Variant) -> void:
	if key not in ["aa","glow","motion_blur","upscale"]:return
	set(key,value);custom=true;game.apply_graphics();game.save_settings()

func preset(tier: int) -> void:
	aa=true;glow=tier>0;motion_blur=false;upscale=0;custom=false

func supported_upscaling() -> bool:
	return RenderingServer.get_current_rendering_method()=="forward_plus"

func apply_view(viewport: Viewport) -> void:
	viewport.msaa_3d=Viewport.MSAA_2X if aa else Viewport.MSAA_DISABLED
	var dimensions:=Vector2(viewport.get_visible_rect().size)
	# Fullscreen stays at the monitor's native output; only 3D is scaled.
	# Split viewports each consume their share of the selected render resolution.
	var height:=maxf(1.,dimensions.y)
	var scale_3d:=minf(1.,float(resolution.y)/height)
	if supported_upscaling() and upscale>0:scale_3d*=.77 if upscale==1 else .67
	viewport.scaling_3d_scale=clampf(scale_3d,.25,1.)
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR2 if supported_upscaling() and upscale>0 else Viewport.SCALING_3D_MODE_BILINEAR

func apply() -> void:
	apply_view(get_tree().root)
	if game.split_view:
		for viewport in game.split_view.views:apply_view(viewport)
	if game.environment:game.environment.glow_enabled=glow

func preview_display(size: Vector2i,fullscreen: bool) -> void:
	if pending:revert_display()
	previous={"resolution":resolution,"size":DisplayServer.window_get_size(),"mode":DisplayServer.window_get_mode()}
	pending=true;deadline=Time.get_ticks_msec()+15000;resolution=size
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:DisplayServer.window_set_size(size)
	apply()

func confirm_display() -> void:
	if not pending:return
	pending=false;previous.clear();game.save_settings();display_finished.emit()

func revert_display() -> void:
	if not pending:return
	resolution=previous.resolution
	DisplayServer.window_set_mode(previous.mode);DisplayServer.window_set_size(previous.size)
	pending=false;previous.clear();apply();display_finished.emit()

func remaining() -> int:return maxi(0,ceili((deadline-Time.get_ticks_msec())/1000.))
func _process(_dt: float) -> void:
	if pending and Time.get_ticks_msec()>=deadline:revert_display()
