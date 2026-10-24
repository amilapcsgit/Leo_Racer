class_name LeoVehicleImporter
extends RefCounted
const REVISION := "loose-glb-2"
static var last_report: Dictionary={}

static func key(path: String) -> String:
	var fingerprint: String=FileAccess.get_sha256(path)+REVISION+Engine.get_version_info().string+RenderingServer.get_current_rendering_method()
	var metadata:=path.get_base_dir().path_join("optimized-textures.json")
	if FileAccess.file_exists(metadata):
		fingerprint+=FileAccess.get_sha256(metadata)
		for entry in optimization(path).get("textures",[]):
			if entry is Dictionary and LeoVehicleLibrary.safe_relative(String(entry.get("file",""))):fingerprint+=FileAccess.get_sha256(path.get_base_dir().path_join(String(entry.file)))
	return fingerprint.sha256_text()

static func optimization(path: String) -> Dictionary:
	var file:=path.get_base_dir().path_join("optimized-textures.json")
	if not FileAccess.file_exists(file):return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary or parsed.get("format")!=1 or not parsed.get("textures",[]) is Array or parsed.get("source_hash")!=FileAccess.get_sha256(path):return {}
	return parsed

static func apply_textures(materials: Array, data: Dictionary, folder: String) -> void:
	var textures: Dictionary={}
	for entry in data.get("textures",[]):
		if not entry is Dictionary:continue
		var index:=int(entry.get("material_index",-1));var relative:=String(entry.get("file",""));var slot:=String(entry.get("slot",""))
		if index<0 or index>=materials.size() or not materials[index] is StandardMaterial3D:continue
		if not LeoVehicleLibrary.safe_relative(relative) or relative.get_extension()!="dds" or slot not in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture","emission_texture"]:continue
		if not textures.has(relative):
			var image:=Image.new()
			if image.load_dds_from_buffer(FileAccess.get_file_as_bytes(folder.path_join(relative)))!=OK:continue
			textures[relative]=ImageTexture.create_from_image(image)
		materials[index].set(slot,textures[relative])

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
		var optimized:=optimization(path)
		if not optimized.is_empty():apply_textures(state.get_materials(),optimized,path.get_base_dir())
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
