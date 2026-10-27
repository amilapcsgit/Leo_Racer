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
static var unavailable: Array[Dictionary]=[]

static func content_root() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tracks="):return ProjectSettings.globalize_path(arg.trim_prefix("--tracks="))
	if not LeoAssets.directory.is_empty():return LeoAssets.directory.path_join("tracks")
	var staged:=ProjectSettings.globalize_path("res://build/Modularity/GameAssets/tracks")
	return staged if DirAccess.dir_exists_absolute(staged) else "res://assets/tracks"

static func discover() -> Array[LeoTrackDefinition]:
	var result: Array[LeoTrackDefinition]=[]
	unavailable.clear()
	var root:=content_root();var counts: Dictionary={}
	for child in DirAccess.get_directories_at(root):
		var path:=root.path_join(child).path_join("manifest.json")
		if not FileAccess.file_exists(path):continue
		var definition:=LeoTrackDefinition.new()
		definition.folder=root.path_join(child);definition.read_manifest(path)
		if definition.error.is_empty():result.append(definition);counts[definition.id]=int(counts.get(definition.id,0))+1
		else:unavailable.append({"folder":child,"reason":definition.error});push_warning("Track unavailable: "+child+" / "+definition.error)
	for definition in result.duplicate():
		if counts[definition.id]>1:unavailable.append({"folder":definition.folder.get_file(),"reason":"Duplicate track ID: "+definition.id});result.erase(definition)
	result.sort_custom(func(a,b):return a.display_name<b.display_name)
	return result

func read_manifest(path: String) -> void:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("format",0)!=1 or (not parsed.get("asset_api") is int and not parsed.get("asset_api") is float) or float(parsed.get("asset_api",0)) not in [1.,2.,3.]:
		error="Unsupported track format";return
	if not parsed.get("id","") is String or not parsed.get("name","") is String or not (parsed.get("course_revision",1) is float or parsed.get("course_revision",1) is int):error="Invalid track identity";return
	metadata=parsed;id=String(metadata.get("id",""));display_name=String(metadata.get("name",id));revision=int(metadata.get("course_revision",1))
	if int(metadata.asset_api)>=2:
		if not metadata.get("core",{}) is Dictionary:error="Invalid core compatibility";return
		var core: Dictionary=metadata.core
		var version_pattern:=RegEx.new();version_pattern.compile("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$")
		if not core.get("min") is String or not version_pattern.search(core.min) or (not core.get("max_major") is int and not core.get("max_major") is float):error="Invalid core compatibility";return
		var minimum:=String(core.min).split(".")
		if minimum.size()!=3 or int(minimum[0])*1000000+int(minimum[1])*1000+int(minimum[2])>2004000 or int(metadata.get("core",{}).get("max_major",0))<2:error="Incompatible track core version";return
		if metadata.get("world_kind")!="external":error="Track API 2 requires external world data";return
		if not metadata.get("lighting",{}) is Dictionary:error="Invalid lighting parameters";return
		var lighting: Dictionary=metadata.get("lighting",{})
		var sky_prefix:="res://mods/tracks/"+id+"/"
		for key in ["sky_visual_path","sky_lighting_path"]:
			if lighting.has(key) and (not lighting[key] is String or not String(lighting[key]).begins_with(sky_prefix) or String(lighting[key]).contains("..")):error="Sky resources must use the track namespace";return
		if lighting.has("sky_visual_path")!=lighting.has("sky_lighting_path"):error="Supply both sky panoramas";return
		if lighting.has("sky_horizon_offset") and (not (lighting.sky_horizon_offset is float or lighting.sky_horizon_offset is int) or not is_finite(float(lighting.sky_horizon_offset)) or absf(float(lighting.sky_horizon_offset))>.25):error="Invalid sky horizon";return
		if metadata.has("authored_signage") and not metadata.authored_signage is bool:error="Invalid authored signage flag";return
		if lighting.has("sun_angles") and not LeoVehicleLibrary.finite_vector(lighting.sun_angles):error="Invalid sun angles";return
		for key in ["sun_color","sky_top","sky_horizon"]:
			if lighting.has(key) and not lighting[key] is String:error="Invalid lighting color";return
		for key in ["sun_energy","ambient_energy"]:
			if lighting.has(key) and ((not lighting[key] is float and not lighting[key] is int) or not is_finite(float(lighting[key])) or float(lighting[key])<0 or float(lighting[key])>8.):error="Invalid lighting energy";return
		var id_pattern:=RegEx.new();id_pattern.compile("^[a-z0-9][a-z0-9_.-]{0,63}$")
		if not id_pattern.search(id):error="Invalid track identity";return
		var namespace_path:="res://mods/tracks/"+id+"/"
		for key in ["scene","backdrop"]:
			if metadata.has(key) and (not metadata[key] is String or not String(metadata[key]).begins_with(namespace_path) or String(metadata[key]).contains("..")):error="Track resources must use their own namespace";return
	if metadata.get("world_kind","astra") not in ["astra","city","external"]:error="Unknown track world type";return
	if id.is_empty() or revision<1:error="Invalid track identity";return
	if not metadata.get("packs",[]) is Array or not metadata.get("dependencies",[]) is Array:error="Invalid track dependencies";return
	for pack in metadata.get("packs",[]):
		if not pack is Dictionary or not pack.get("file") is String or not pack.get("sha256","") is String:error="Invalid track pack entry";return
	var relative:=String(metadata.get("route","route.json"))
	if relative.is_absolute_path() or relative.contains("..") or relative.contains(":"):error="Invalid route location";return
	var route_path:=folder.path_join(relative)
	if not FileAccess.file_exists(route_path):error="Missing route file";return
	var data=JSON.parse_string(FileAccess.get_file_as_string(route_path))
	if not data is Dictionary:error="Invalid route JSON";return
	route=data
	if not (route.get("length") is float or route.get("length") is int) or not is_finite(float(route.length)):error="Invalid route length";return
	if not (route.get("width",18.) is float or route.get("width",18.) is int) or not is_finite(float(route.get("width",18.))) or float(route.get("width",18.))<6.:error="Invalid route width";return
	if not route.get("features",{}) is Dictionary:error="Invalid route features";return
	var grid: Variant=route.get("features",{}).get("grid",{})
	if not grid is Dictionary or not grid.get("lanes",[-3.2,3.2]) is Array or grid.get("lanes",[-3.2,3.2]).size()!=2:error="Invalid starting grid";return
	for lane in grid.get("lanes",[-3.2,3.2]):
		if (not lane is int and not lane is float) or not is_finite(float(lane)):error="Invalid grid lane";return
	if not route.get("points",[]) is Array:error="Invalid route points";return
	var points: Array=route.get("points",[])
	if points.size()<16 or float(route.get("length",0))<100:error="Incomplete race route";return
	for p in points:
		if not p is Array or p.size()!=3:error="Invalid route point";return
		for value in p:
			if not value is float and not value is int:error="Invalid point coordinate";return
			if not is_finite(float(value)):error="Non-finite point coordinate";return
	if int(metadata.asset_api)>=2:
		var measured:=0.
		for i in points.size():
			var a:=LeoVehicleCodec.vector(points[i]);var b:=LeoVehicleCodec.vector(points[(i+1)%points.size()]);var distance:=a.distance_to(b)
			if distance<.01 or (int(metadata.asset_api)==2 and absf(a.y)>.05):error="External circuit must have distinct, flat route samples at road level";return
			measured+=distance
		if absf(measured-float(route.length))>maxf(1.,measured*.005):error="Route length does not match its samples";return
		if not route.get("features",{}) is Dictionary:error="Invalid track features";return
		var recoveries: Variant=route.get("features",{}).get("recoveries",[])
		if not recoveries is Array or recoveries.size()!=8:error="Supply eight recovery locations";return
		for i in 8:
			if not recoveries[i] is Dictionary or not (recoveries[i].get("distance") is int or recoveries[i].get("distance") is float):error="Invalid recovery location";return
			var distance:=float(recoveries[i].distance)
			if not is_finite(distance) or distance<measured*i/8. or distance>measured*(i+.25)/8.:error="Recovery must follow its ordered checkpoint";return
	if int(metadata.asset_api)==3:
		if metadata.get("surface_profile")!="arcade_elevation_v1":error="Unsupported elevated surface profile";return
		var issue:=elevation_problem(route)
		if not issue.is_empty():error=issue;return
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
			if dependency=="vehicles/roster" and LeoAssets.manifest.get("vehicle_api",0)==1 and "drivers/shared" in available:continue
			if not String(dependency) in available:error="Missing track dependency: "+String(dependency);return false
	for pack in metadata.get("packs",[]):
		var relative:=String(pack.get("file",""))
		if relative.is_empty() or relative.contains("..") or relative.is_absolute_path() or relative.contains(":"):error="Invalid track pack path";return false
		var path:=folder.path_join(relative)
		if not FileAccess.file_exists(path):error="Missing track scenery: "+relative;return false
		if not String(pack.get("sha256","")).is_empty() and FileAccess.get_sha256(path)!=pack.sha256:error="Damaged track scenery: "+relative;return false
		if not ProjectSettings.load_resource_pack(path,false):error="Could not mount track scenery";return false
	if world_kind() in ["city","external"]:
		for key in ["scene","backdrop"]:
			if key=="backdrop" and world_kind()=="external" and not metadata.has(key):continue
			if not ResourceLoader.exists(String(metadata.get(key,""))):error="Missing track resource: "+key;return false
		var index:=folder.path_join("cells.json")
		if not FileAccess.file_exists(index):error="Missing scenery index";return false
		var data=JSON.parse_string(FileAccess.get_file_as_string(index))
		if not data is Dictionary or not data.get("cells",[]) is Array:error="Invalid scenery index";return false
		for cell in data.get("cells",[]):
			if not cell is Dictionary or not cell.get("scene") is String or not ResourceLoader.exists(String(cell.scene)):error="Missing scenery cell";return false
			if not cell.get("id") is String or not cell.get("center") is Array or cell.center.size()!=2:error="Invalid scenery cell location";return false
			for coordinate in cell.center:
				if (not coordinate is int and not coordinate is float) or not is_finite(float(coordinate)):error="Invalid scenery cell coordinate";return false
	var registry_path:="res://assets/config/official-track-content.json"
	if not LeoAssets.directory.is_empty() and FileAccess.file_exists(registry_path):
		var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(registry_path))
		var actual: Array=[]
		for pack in metadata.get("packs",[]):actual.append(FileAccess.get_sha256(folder.path_join(String(pack.file))))
		modified=modified or actual!=registry.get(id+":"+str(revision),[])
	return true

func profile() -> LeoArtProfile:
	if world_kind()=="external":
		var result:=LeoArtProfile.new();result.world_model="";result.landmark_model="";result.sun_angles=Vector3(-55,-145,0);result.sky_top=Color("3a8ec7");result.sky_horizon=Color("c9e4ed");result.haze_density=.0004
		var settings: Dictionary=metadata.get("lighting",{})
		if settings.has("sun_angles"):result.sun_angles=LeoVehicleCodec.vector(settings.sun_angles)
		for key in ["sun_color","sky_top","sky_horizon"]:
			if settings.has(key):result.set(key,Color.from_string(String(settings[key]),result.get(key)))
		for key in ["sun_energy","ambient_energy"]:
			if settings.has(key):result.set(key,float(settings[key]))
		for key in ["sky_visual_path","sky_lighting_path"]:
			if settings.has(key):result.set(key,String(settings[key]))
		if settings.has("sky_horizon_offset"):result.sky_horizon_offset=float(settings.sky_horizon_offset)
		if not result.sky_visual_path.is_empty():result.haze_color=Color("b5c8ca");result.haze_density=.00018;result.exposure=.95
		return result
	return load(String(metadata.get("lighting","res://assets/config/astra.tres"))) as LeoArtProfile

func world_kind() -> String:return String(metadata.get("world_kind","astra"))

func elevated() -> bool:return int(metadata.get("asset_api",1))==3
func ruleset_id() -> String:return LeoRaceRules.ID+("+arcade_elevation_v1" if elevated() else "")

static func elevation_problem(data: Dictionary) -> String:
	var samples: Array=data.get("points",[])
	var widths: Variant=data.get("widths",[])
	if not widths is Array:return "Invalid elevated road widths"
	for width in widths:
		if (not width is int and not width is float) or not is_finite(float(width)):return "Invalid elevated road width"
	if float(data.get("width",18.))<14.:return "Elevated road width must be at least 14 m"
	var grades: Array[float]=[];var spans: Array[float]=[]
	for i in samples.size():
		var delta:=LeoVehicleCodec.vector(samples[(i+1)%samples.size()])-LeoVehicleCodec.vector(samples[i])
		var horizontal:=Vector2(delta.x,delta.z).length()
		if horizontal<.01:return "Elevated samples must have horizontal separation"
		var grade:=delta.y/horizontal
		if absf(grade)>.06005:return "Road grade exceeds 6 percent"
		if not widths.is_empty() and (i>=widths.size() or float(widths[i])<14.):return "Elevated road width must be at least 14 m"
		grades.append(grade);spans.append(horizontal)
	for i in grades.size():
		var previous:=posmod(i-1,grades.size())
		if absf(grades[i]-grades[previous])/((spans[i]+spans[previous])*.5)>.001005:return "Vertical curvature radius must be at least 1000 m"
	return ""
