class_name LeoPreviewArt
extends RefCounted
## Camera and artwork identity shared by live garage, official bake and imports.
const SIZE := Vector2i(1600,900)
const FOV := 36.
const PITCH := .12
const ROOT := "res://assets/ui/art/ultra/cars"
static func frame(camera: Camera3D,car: VehicleDefinition) -> void:
	var presentation:=LeoVehiclePresentation.resolve(car)
	var target:=presentation.preview_target-Vector3.UP*.4
	camera.fov=FOV
	camera.position=target+Vector3(0,sin(PITCH),-cos(PITCH))*presentation.preview_distance*.95
	camera.look_at(target)
static func name_for(car: VehicleDefinition) -> String:
	return car.display_name.replace("_"," ")
static func texture(car: VehicleDefinition,hero: bool=false) -> Texture2D:
	var variant:="compatibility" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else "forward"
	var file:=ROOT.path_join(variant).path_join(String(car.id)+("-hero.png" if hero else ".png"))
	if ResourceLoader.exists(file):return load(file)
	if not car.official:
		var cached:=cache_path(car,hero)
		if FileAccess.file_exists(cached):return LeoAssets.texture(ProjectSettings.globalize_path(cached))
	return load("res://assets/ui/art/ultra/custom-car.png")
static func cache_path(car: VehicleDefinition,hero: bool) -> String:
	var identity:=car.model_path+String(car.content_data.get("pack_sha256",car.content_data.get("version","")))+RenderingServer.get_current_rendering_method()+":v1"
	if FileAccess.file_exists(car.model_path):identity+=str(FileAccess.get_modified_time(car.model_path))
	return "user://preview-art/"+identity.sha256_text()+ ("-hero.png" if hero else ".png")
static func save(image: Image,hero_path: String,card_path: String) -> Error:
	if not image or image.is_empty():return ERR_INVALID_DATA
	image.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(hero_path.get_base_dir())
	var error:=image.save_png(hero_path)
	if error!=OK:return error
	var bounds:=image.get_used_rect()
	if not bounds.has_area():return ERR_INVALID_DATA
	var padding:=ceili(maxi(bounds.size.x,bounds.size.y)*.05)
	bounds=bounds.grow(padding).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var card:=image.get_region(bounds)
	card.resize(752,maxi(1,roundi(752.*card.get_height()/card.get_width())),Image.INTERPOLATE_LANCZOS)
	return card.save_png(card_path)
static func capture_model(studio: Node3D,viewport: SubViewport,tree: SceneTree) -> Image:
	# Capture in a separate world: imported-car caching must never flash the live showroom.
	var capture:=SubViewport.new();capture.size=viewport.size;capture.own_world_3d=true;capture.transparent_bg=true;capture.msaa_3d=viewport.msaa_3d;capture.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var stage:=Node3D.new();capture.add_child(stage)
	for child in studio.get_children():
		if child is WorldEnvironment:
			var environment:=WorldEnvironment.new();environment.environment=child.environment.duplicate() as Environment;environment.environment.background_color=Color.TRANSPARENT;environment.environment.glow_enabled=false;stage.add_child(environment)
		elif child is Camera3D:
			var camera:=Camera3D.new();camera.fov=child.fov;camera.transform=child.transform;camera.current=true;stage.add_child(camera)
		elif child is Light3D:
			stage.add_child(child.duplicate())
		elif child is Node3D and not child is GeometryInstance3D and not child is StaticBody3D:
			var copy:=child.duplicate() as Node3D;copy.process_mode=Node.PROCESS_MODE_DISABLED;stage.add_child(copy)
			for audio in copy.find_children("*","Node",true,false):
				if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:audio.stop()
	tree.root.add_child(capture)
	for frame in 3:
		await tree.process_frame
		await RenderingServer.frame_post_draw
	var image:=capture.get_texture().get_image()
	capture.queue_free()
	return image
