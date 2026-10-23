class_name LeoAssets
extends RefCounted
## Stable resource IDs resolve identically in editor and installed builds.
static var directory := ""
static var manifest: Dictionary = {}
static var failure := ""
static var modified_rules := false
static var cache: Dictionary = {}
static var _recent: Array[String] = []

static func configure(root: String) -> Error:
	directory=root;failure="";manifest={};cache.clear();_recent.clear();modified_rules=false
	var path:=root.path_join("catalog.json")
	if not FileAccess.file_exists(path):failure="Missing GameAssets/catalog.json";return ERR_FILE_NOT_FOUND
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("format",0))!=1:
		failure="Unsupported asset catalog";return ERR_FILE_CORRUPT
	manifest=parsed
	for pack in manifest.get("packs",[]):
		var file:=safe_file(String(pack.get("file","")))
		if file.is_empty() or not FileAccess.file_exists(file):failure="Missing asset pack: "+String(pack.get("file",""));return ERR_FILE_NOT_FOUND
		if not String(pack.get("sha256","")).is_empty() and FileAccess.get_sha256(file)!=pack.sha256:
			failure="Damaged asset pack: "+String(pack.file);return ERR_FILE_CORRUPT
	for entry in manifest.get("overrides",[]):
		if safe_file(String(entry.get("file",""))).is_empty():failure="Invalid override path";return ERR_INVALID_DATA
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
	if ResourceLoader.load_threaded_request(path,"PackedScene")!=OK:return null
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await tree.process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return null
	var loaded:=ResourceLoader.load_threaded_get(path) as PackedScene
	if loaded:cache[id]=loaded;_touch(id)
	return loaded
