class_name LeoVehicleImporter
extends RefCounted
const REVISION := "loose-glb-1"
static var last_report: Dictionary={}

static func key(path: String) -> String:
	return (FileAccess.get_sha256(path)+REVISION+Engine.get_version_info().string+RenderingServer.get_current_rendering_method()).sha256_text()

static func import_scene(path: String) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var result: Dictionary={"scene":null,"error":"","cache_hit":false,"seconds":0.}
	if not FileAccess.file_exists(path):result.error="Missing vehicle model: "+path.get_file();return result
	var cache_root:="user://content-cache/vehicles"
	DirAccess.make_dir_recursive_absolute(cache_root)
	var target:=cache_root.path_join(key(path)+".scn")
	if FileAccess.file_exists(target):
		var cached:=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if cached:result.scene=cached;result.cache_hit=true
	if not result.scene:
		var document:=GLTFDocument.new();var state:=GLTFState.new()
		# Generated model hierarchy only; no imported cameras/lights participate in gameplay.
		if document.append_from_file(path,state)!=OK:result.error="Cannot read GLB: "+path.get_file();return result
		var node:=document.generate_scene(state)
		if not node:result.error="Cannot assemble GLB: "+path.get_file();return result
		strip_nonvisual(node)
		var scene:=PackedScene.new()
		if scene.pack(node)!=OK:node.free();result.error="Cannot cache vehicle scene";return result
		node.free();result.scene=scene
		# A cache is optional: read-only/full user storage must still allow racing.
		var temporary:=target.get_basename()+".tmp.scn"
		if ResourceSaver.save(scene,temporary,ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK:
			if DirAccess.rename_absolute(temporary,target)!=OK:DirAccess.remove_absolute(temporary)
	result.seconds=(Time.get_ticks_usec()-started)/1000000.
	return result

static func strip_nonvisual(node: Node) -> void:
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is CollisionObject3D:
			node.remove_child(child);child.free()
		else:strip_nonvisual(child)
