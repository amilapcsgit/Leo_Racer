class_name LeoTrackDefinition
extends RefCounted
var id := "astra_coast"
var display_name := "Astra Lotus Coast"
var revision := 1
var folder := ""
var metadata: Dictionary = {}
var route: Dictionary = {}
var error := ""
var modified := false

static func discover() -> Array[LeoTrackDefinition]:
	var result: Array[LeoTrackDefinition]=[]
	var root:="res://assets/tracks" if LeoAssets.directory.is_empty() else LeoAssets.directory.path_join("tracks")
	for child in DirAccess.get_directories_at(root):
		var path:=root.path_join(child).path_join("manifest.json")
		if not FileAccess.file_exists(path):continue
		var definition:=LeoTrackDefinition.new()
		definition.folder=root.path_join(child);definition.read_manifest(path)
		if definition.error.is_empty():result.append(definition)
		else:push_warning("Track unavailable: "+child+" / "+definition.error)
	result.sort_custom(func(a,b):return a.display_name<b.display_name)
	return result

func read_manifest(path: String) -> void:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("format",0))!=1 or int(parsed.get("asset_api",0))!=1:
		error="Unsupported track format";return
	metadata=parsed;id=String(metadata.get("id",""));display_name=String(metadata.get("name",id));revision=int(metadata.get("course_revision",1))
	if id.is_empty() or revision<1:error="Invalid track identity";return
	if not metadata.get("packs",[]) is Array or not metadata.get("dependencies",[]) is Array:error="Invalid track dependencies";return
	for pack in metadata.get("packs",[]):
		if not pack is Dictionary:error="Invalid track pack entry";return
	var relative:=String(metadata.get("route","route.json"))
	if relative.is_absolute_path() or relative.contains("..") or relative.contains(":"):error="Invalid route location";return
	var route_path:=folder.path_join(relative)
	if not FileAccess.file_exists(route_path):error="Missing route file";return
	var data=JSON.parse_string(FileAccess.get_file_as_string(route_path))
	if not data is Dictionary:error="Invalid route JSON";return
	route=data
	if not route.get("points",[]) is Array:error="Invalid route points";return
	var points: Array=route.get("points",[])
	if points.size()<16 or float(route.get("length",0))<100:error="Incomplete race route";return
	for p in points:
		if not p is Array or p.size()!=3:error="Invalid route point";return
		for value in p:
			if not value is float and not value is int:error="Invalid point coordinate";return
			if not is_finite(float(value)):error="Non-finite point coordinate";return
	var widths=route.get("widths",[])
	if not widths is Array or (not widths.is_empty() and widths.size()!=points.size()):error="Invalid route widths";return
	for width in widths:
		if (not width is float and not width is int) or not is_finite(float(width)) or float(width)<6.:error="Unsafe route width";return
	var official: Dictionary={}
	var registry:="res://assets/config/official-tracks.json"
	if FileAccess.file_exists(registry):official=JSON.parse_string(FileAccess.get_file_as_string(registry))
	modified=String(official.get(id+":"+str(revision),""))!=FileAccess.get_sha256(route_path)

func mount() -> bool:
	error=""
	if not LeoAssets.directory.is_empty():
		var available: Array=LeoAssets.manifest.get("packs",[]).map(func(pack):return String(pack.get("id","")))
		for dependency in metadata.get("dependencies",[]):
			if not String(dependency) in available:error="Missing track dependency: "+String(dependency);return false
	for pack in metadata.get("packs",[]):
		var relative:=String(pack.get("file",""))
		if relative.is_empty() or relative.contains("..") or relative.is_absolute_path() or relative.contains(":"):error="Invalid track pack path";return false
		var path:=folder.path_join(relative)
		if not FileAccess.file_exists(path):error="Missing track scenery: "+relative;return false
		if not String(pack.get("sha256","")).is_empty() and FileAccess.get_sha256(path)!=pack.sha256:error="Damaged track scenery: "+relative;return false
		if not ProjectSettings.load_resource_pack(path,false):error="Could not mount track scenery";return false
	if world_kind()=="city":
		for key in ["scene","backdrop"]:
			if not ResourceLoader.exists(String(metadata.get(key,""))):error="Missing track resource: "+key;return false
		var index:=folder.path_join("cells.json")
		if not FileAccess.file_exists(index):error="Missing scenery index";return false
		var data=JSON.parse_string(FileAccess.get_file_as_string(index))
		if not data is Dictionary or not data.get("cells",[]) is Array:error="Invalid scenery index";return false
		for cell in data.get("cells",[]):
			if not cell is Dictionary or not ResourceLoader.exists(String(cell.get("scene",""))):error="Missing scenery cell";return false
	return true

func profile() -> LeoArtProfile:
	return load(String(metadata.get("lighting","res://assets/config/astra.tres"))) as LeoArtProfile

func world_kind() -> String:return String(metadata.get("world_kind","astra"))
