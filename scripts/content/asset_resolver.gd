class_name LeoAssets
extends RefCounted
## Stable resource IDs resolve identically in editor and installed builds.
static var directory := ""
static var manifest: Dictionary = {}
static var failure := ""
static var modified_rules := false
static var cache: Dictionary = {}
static var _recent: Array[String] = []
static var _patched_meshes: Dictionary = {}
static var _loading: Dictionary = {}

static func configure(root: String) -> Error:
	directory=root;failure="";manifest={};cache.clear();_recent.clear();_patched_meshes.clear();modified_rules=false
	var path:=root.path_join("catalog.json")
	if not FileAccess.file_exists(path):failure="Missing GameAssets/catalog.json";return ERR_FILE_NOT_FOUND
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("format",0))!=1:
		failure="Unsupported asset catalog";return ERR_FILE_CORRUPT
	manifest=parsed
	if not manifest.get("packs",[]) is Array or not manifest.get("assets",{}) is Dictionary or not manifest.get("overrides",[]) is Array:
		failure="Invalid asset catalog entries";return ERR_FILE_CORRUPT
	for pack in manifest.get("packs",[]):
		if not pack is Dictionary:failure="Invalid asset pack entry";return ERR_FILE_CORRUPT
		var file:=safe_file(String(pack.get("file","")))
		if file.is_empty() or not FileAccess.file_exists(file):failure="Missing asset pack: "+String(pack.get("file",""));return ERR_FILE_NOT_FOUND
		if not String(pack.get("sha256","")).is_empty() and FileAccess.get_sha256(file)!=pack.sha256:
			failure="Damaged asset pack: "+String(pack.file);return ERR_FILE_CORRUPT
	for entry in manifest.get("overrides",[]):
		if not entry is Dictionary or String(entry.get("id","")).is_empty():failure="Invalid override identity";return ERR_INVALID_DATA
		if safe_file(String(entry.get("file",""))).is_empty():failure="Invalid override path";return ERR_INVALID_DATA
		if not FileAccess.file_exists(safe_file(entry.file)):failure="Missing override: "+String(entry.file);return ERR_FILE_NOT_FOUND
		modified_rules=modified_rules or bool(entry.get("affects_rules",false))
	return OK

static func safe_file(relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path() or relative.contains("..") or relative.contains(":"):return ""
	return directory.path_join(relative)

static func mount_packs() -> Error:
	for pack in manifest.get("packs",[]):
		if not ProjectSettings.load_resource_pack(safe_file(pack.file),false):
			failure="Cannot open asset pack: "+String(pack.file);return ERR_FILE_CORRUPT
	return OK

static func override_for(id: String) -> Dictionary:
	for entry in manifest.get("overrides",[]):
		if String(entry.get("id",""))==id:return entry
	return {}

static func resource(id: String) -> Resource:
	if cache.has(id):_touch(id);return cache[id]
	var entry:=override_for(id)
	var result: Resource
	if not entry.is_empty():
		var file:=safe_file(String(entry.file))
		if file.get_extension().to_lower()=="glb":
			var document:=GLTFDocument.new();var state:=GLTFState.new()
			if document.append_from_file(file,state)==OK:
				var node:=document.generate_scene(state)
				if node:
					var scene:=PackedScene.new();scene.pack(node);node.free();result=scene
		elif file.get_extension().to_lower() in ["png","svg","jpg","webp"]:
			var image:=Image.load_from_file(file)
			if image and not image.is_empty():image.generate_mipmaps();result=ImageTexture.create_from_image(image)
		if not result:failure="Cannot load override: "+String(entry.file);return null
	else:
		var path:=String(manifest.get("assets",{}).get(id,id))
		if ResourceLoader.exists(path):result=ResourceLoader.load(path)
	if result:
		cache[id]=result;_touch(id)
		while _recent.size()>12:cache.erase(_recent.pop_front())
	return result

static func _touch(id: String) -> void:
	_recent.erase(id);_recent.append(id)

static func texture(id: String) -> Texture2D:return resource(id) as Texture2D
static func scene(id: String) -> PackedScene:return resource(id) as PackedScene

static func scene_async(id: String, tree: SceneTree) -> PackedScene:
	if cache.has(id) or not override_for(id).is_empty():return scene(id)
	var path:=String(manifest.get("assets",{}).get(id,id))
	if not _loading.has(path):
		if ResourceLoader.load_threaded_request(path,"PackedScene")!=OK:failure="Cannot load scene: "+id;return null
		_loading[path]=true
	while _loading.has(path):
		var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await tree.process_frame;continue
		_loading.erase(path)
		if status!=ResourceLoader.THREAD_LOAD_LOADED:failure="Cannot load scene: "+id;return null
		var loaded:=ResourceLoader.load_threaded_get(path) as PackedScene
		if loaded:
			cache[id]=loaded;_touch(id)
			while _recent.size()>12:cache.erase(_recent.pop_front())
		return loaded
	return scene(id)

static func _parts(node: Node3D, parent: Transform3D, result: Array) -> void:
	var pose:=parent*node.transform
	if node is MeshInstance3D and node.mesh:result.append({"mesh":node.mesh,"transform":pose})
	for child in node.get_children():
		if child is Node3D:_parts(child,pose,result)

static func _patch_material(original: Material) -> Material:
	if not original:return original
	var result: Material=original
	if original is StandardMaterial3D:
		for property in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture","emission_texture"]:
			var texture: Texture2D=original.get(property)
			if texture and not override_for(texture.resource_path).is_empty():
				if result==original:result=original.duplicate()
				result.set(property,LeoAssets.texture(texture.resource_path))
	elif original is ShaderMaterial and original.shader:
		for uniform in original.shader.get_shader_uniform_list():
			var value=original.get_shader_parameter(uniform.name)
			if value is Texture2D and not override_for(value.resource_path).is_empty():
				if result==original:result=original.duplicate()
				result.set_shader_parameter(uniform.name,texture(value.resource_path))
	return result

static func apply_overrides(node: Node) -> void:
	if manifest.get("overrides",[]).is_empty() or node.get_meta("_content_override",false):return
	node.set_meta("_content_override",true)
	if node is MultiMeshInstance3D and node.multimesh:
		var id:=String(node.get_meta("asset_id",""))
		if not id.is_empty() and not override_for(id).is_empty():
			var replacement:=scene(id)
			if replacement:
				var instance:=replacement.instantiate() as Node3D;var items: Array=[];_parts(instance,Transform3D.IDENTITY,items);instance.free()
				var part:=int(node.get_meta("part_index",0));node.multimesh=node.multimesh.duplicate()
				if part>=items.size():node.multimesh.instance_count=0
				else:
					var original: Transform3D=node.get_meta("part_transform",Transform3D.IDENTITY)
					for i in node.multimesh.instance_count:
						node.multimesh.set_instance_transform(i,node.multimesh.get_instance_transform(i)*original.affine_inverse()*items[part].transform)
					node.multimesh.mesh=items[part].mesh
		var mesh: Mesh=node.multimesh.mesh
		var key:=mesh.resource_path if not mesh.resource_path.is_empty() else str(mesh.get_instance_id())
		if not _patched_meshes.has(key):
			var patched:=mesh.duplicate() as Mesh
			for i in patched.get_surface_count():patched.surface_set_material(i,_patch_material(mesh.surface_get_material(i)))
			_patched_meshes[key]=patched
		node.multimesh=node.multimesh.duplicate();node.multimesh.mesh=_patched_meshes[key]
	elif node is MeshInstance3D and node.mesh:
		if node.material_override:node.material_override=_patch_material(node.material_override)
		else:
			for i in node.mesh.get_surface_count():node.set_surface_override_material(i,_patch_material(node.get_active_material(i)))
	for child in node.get_children():apply_overrides(child)
