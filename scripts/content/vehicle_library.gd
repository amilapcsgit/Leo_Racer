class_name LeoVehicleLibrary
extends RefCounted
## Metadata-only discovery. A bad optional car never prevents boot.
const CORE_VERSION := Vector3i(2,3,0)
static var generation := 0
static var entries: Array[VehicleDefinition]=[]
static var unavailable: Array[Dictionary]=[]
static var pending: Array[String]=[]
static var root := ""
static var fingerprint_details: Dictionary={}
static var discovering := false

static func discover_async(tree: SceneTree) -> void:
	if discovering:
		while discovering:await tree.process_frame
		return
	discovering=true;var worker:=Thread.new();worker.start(discover)
	while worker.is_alive():await tree.process_frame
	worker.wait_to_finish();discovering=false

static func default_root() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicles="):return ProjectSettings.globalize_path(arg.trim_prefix("--vehicles="))
	if not LeoAssets.directory.is_empty():return LeoAssets.directory.path_join("vehicles")
	return ProjectSettings.globalize_path("res://build/Modularity/GameAssets/vehicles")

static func legacy() -> bool:return "--legacy-content" in OS.get_cmdline_user_args()

static func safe_relative(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains(":") and not ".." in path.replace("\\","/").split("/")

static func finite_vector(value: Variant) -> bool:
	if not value is Array or value.size()!=3:return false
	for n in value:
		if (not n is int and not n is float) or not is_finite(float(n)):return false
	return true

static func valid_transform(value: Variant) -> bool:
	if not value is Dictionary or not finite_vector(value.get("origin")):return false
	var axes: Variant=value.get("basis")
	if not axes is Array or axes.size()!=3:return false
	for axis in axes:
		if not finite_vector(axis):return false
	return absf(LeoVehicleCodec.transform(value).basis.determinant())>.000000000000001

static func glb_problem(path: String) -> String:
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file:return "Model is not readable"
	if file.get_length()<20:return "Damaged GLB header"
	if file.get_32()!=0x46546c67 or file.get_32()!=2 or file.get_32()!=file.get_length():return "Damaged or unsupported GLB container"
	var size:=file.get_32()
	if file.get_32()!=0x4e4f534a or size>file.get_length()-20 or size>64000000:return "Damaged GLB metadata chunk"
	var metadata: Variant=JSON.parse_string(file.get_buffer(size).get_string_from_utf8())
	if not metadata is Dictionary:return "Invalid GLB metadata"
	if not metadata.get("images",[]) is Array or not metadata.get("buffers",[]) is Array:return "Invalid GLB image/buffer list"
	for image in metadata.get("images",[]):
		if not image is Dictionary:return "Invalid GLB images"
		if image.has("uri") and not String(image.uri).begins_with("data:"):return "Embed image files in the GLB before importing"
	for buffer in metadata.get("buffers",[]):
		if not buffer is Dictionary or buffer.has("uri"):return "Embed geometry buffers in the GLB"
	return ""

static func problems(data: Variant, folder: String, files: bool=true) -> PackedStringArray:
	var errors:=PackedStringArray()
	if not data is Dictionary:return ["vehicle.json must contain an object"]
	if data.get("format")!=1 or data.get("vehicle_api")!=1:errors.append("Unsupported Vehicle API; expected 1")
	for field in ["display_name","version","fixed_driver_id","attribution","visual_profile"]:
		if data.has(field) and not data[field] is String:errors.append("Invalid "+field)
	for field in ["electric_boost","hovering","preserve_materials","setup_complete"]:
		if data.has(field) and not data[field] is bool:errors.append("Invalid "+field)
	if not bool(data.get("setup_complete",false)):errors.append("Vehicle setup is incomplete")
	var pattern:=RegEx.new();pattern.compile("^[a-z0-9][a-z0-9_.-]{0,63}$")
	if not data.get("id") is String or not pattern.search(data.id):errors.append("Invalid stable vehicle ID")
	var version_pattern:=RegEx.new();version_pattern.compile("^[0-9]+\\.[0-9]+\\.[0-9]+$")
	if not data.get("version") is String or not version_pattern.search(String(data.get("version",""))):errors.append("Invalid content version")
	var core: Variant=data.get("core",{})
	if not core is Dictionary or int(core.get("max_major",0))<CORE_VERSION.x:errors.append("Incompatible core version")
	else:
		var minimum:=String(core.get("min","999.0.0")).split(".")
		if minimum.size()!=3:errors.append("Invalid minimum core version")
		else:
			var number:=int(minimum[0])*1000000+int(minimum[1])*1000+int(minimum[2])
			if number>CORE_VERSION.x*1000000+CORE_VERSION.y*1000+CORE_VERSION.z:errors.append("Requires a newer Leo Racer core")
	for key in ["model","thumbnail"]:
		var relative: Variant=data.get(key,"model.glb" if key=="model" else "thumbnail.png")
		if not relative is String or not safe_relative(relative):errors.append("Unsafe "+key+" path")
		elif files and key=="model":
			if not FileAccess.file_exists(folder.path_join(relative)):errors.append("Missing model: "+relative)
			else:
				var problem:=glb_problem(folder.path_join(relative))
				if not problem.is_empty():errors.append(problem)
	if String(data.get("model","")).get_extension().to_lower()!="glb":errors.append("Model must be GLB")
	for key in ["collision_size","collision_position","preview_target"]:
		if data.has(key) and not finite_vector(data[key]):errors.append("Invalid "+key)
	if finite_vector(data.get("collision_size")):
		for n in data.collision_size:
			if float(n)<=0 or float(n)>30:errors.append("Collision dimensions must be positive and at most 30 m")
	for key in ["seat","normalization"]:
		if data.has(key) and not valid_transform(data[key]):errors.append("Invalid "+key+" transform")
	var fits: Variant=data.get("driver_fits",{})
	if not fits is Dictionary:errors.append("Invalid driver fits")
	else:
		for fit in fits.values():
			if not valid_transform(fit):errors.append("Invalid driver fit")
	for key in ["max_speed","boosted_speed","acceleration","handling","braking_regeneration","camera_height","preview_distance","ai_lateral_acceleration"]:
		if data.has(key) and ((not data[key] is int and not data[key] is float) or not is_finite(float(data[key])) or absf(float(data[key]))>1000):errors.append("Invalid "+key)
	for key in ["max_speed","acceleration","handling","preview_distance"]:
		if (data.get(key,1) is float or data.get(key,1) is int) and float(data.get(key,1))<=0:errors.append(key+" must be positive")
	var wheels: Variant=data.get("wheels",[])
	if not wheels is Array:return ["Invalid wheel list"]
	if wheels.is_empty() and not bool(data.get("hovering",false)):errors.append("Bind wheels or enable hovering")
	for wheel in wheels:
		if not wheel is Dictionary:errors.append("Invalid wheel");continue
		if not finite_vector(wheel.get("pivot")) or not finite_vector(wheel.get("axle")):errors.append("Invalid wheel pivot/axle")
		elif not is_equal_approx(LeoVehicleCodec.vector(wheel.axle).length(),1.):errors.append("Wheel axle must be normalized")
		if not wheel.get("radius") is float and not wheel.get("radius") is int:errors.append("Invalid wheel radius")
		elif float(wheel.radius)<=.01 or float(wheel.radius)>3.:errors.append("Wheel radius outside 0.01â€“3 m")
		for key in ["rotating","stationary"]:
			var paths: Variant=wheel.get(key,[])
			if not paths is Array:errors.append("Invalid wheel groups");continue
			if key=="rotating" and paths.is_empty():errors.append("Each wheel needs a rotating group")
			for path in paths:
				if not path is String or not safe_relative(path):errors.append("Invalid wheel node path")
	if not data.get("exhausts",[]) is Array:errors.append("Invalid exhaust positions")
	else:
		for point in data.get("exhausts",[]):
			if not finite_vector(point):errors.append("Invalid exhaust position")
	if not data.get("dependencies",[]) is Array:errors.append("Invalid dependencies")
	elif not data.get("dependencies",[]).is_empty():errors.append("Vehicle API 1 requires a self-contained model; unsupported dependency")
	if not (data.get("driver_policy",0) is int or data.get("driver_policy",0) is float):errors.append("Unsupported driver policy")
	elif float(data.get("driver_policy",0))!=int(data.get("driver_policy",0)) or int(data.get("driver_policy",0)) not in [0,1,2,3]:errors.append("Unsupported driver policy")
	elif int(data.get("driver_policy",0))==2 and String(data.get("fixed_driver_id","")) not in ["human","mario","hedgehog","lion","elephant","parrot"]:errors.append("Choose a valid fixed driver")
	return errors

static func discover(directory: String="") -> void:
	root=default_root() if directory.is_empty() else directory
	entries.clear();unavailable.clear();pending.clear();fingerprint_details.clear();generation+=1
	if not DirAccess.dir_exists_absolute(root):return
	var candidates: Array[Dictionary]=[];var counts: Dictionary={}
	for child in DirAccess.get_directories_at(root):
		var folder:=root.path_join(child);var file:=folder.path_join("vehicle.json")
		if not FileAccess.file_exists(file):continue
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(file));var errors:=problems(data,folder)
		if not errors.is_empty():unavailable.append({"folder":child,"reason":"; ".join(errors)});continue
		counts[data.id]=int(counts.get(data.id,0))+1;candidates.append({"data":data,"folder":folder})
	for candidate in candidates:
		var data: Dictionary=candidate.data
		if counts[data.id]>1:unavailable.append({"folder":candidate.folder.get_file(),"reason":"Duplicate ID: "+data.id});continue
		var vehicle:=LeoVehicleCodec.deserialize(data,candidate.folder)
		vehicle.thumbnail_path=candidate.folder.path_join(String(data.get("thumbnail","thumbnail.png")))
		vehicle.content_folder=candidate.folder;vehicle.content_data=data
		vehicle.official=official(data,candidate.folder)
		entries.append(vehicle)
	for file in DirAccess.get_files_at(root):
		if file.get_extension().to_lower()=="glb":pending.append(root.path_join(file))
	entries.sort_custom(func(a,b):return String(a.id)<String(b.id))

static func official(data: Dictionary, folder: String) -> bool:
	var path:="res://assets/config/official-vehicles.json"
	if not FileAccess.file_exists(path):fingerprint_details[String(data.id)]={"registry_found":false};return false
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var expected: Dictionary=registry.get(String(data.id),{})
	var definition_hash:=FileAccess.get_file_as_string(folder.path_join("vehicle.json")).replace("\r\n","\n").sha256_text()
	var model_hash:=FileAccess.get_sha256(folder.path_join(String(data.model)))
	fingerprint_details[String(data.id)]={"registry_found":true,"trusted_id":not expected.is_empty(),"definition_match":expected.get("definition")==definition_hash,"model_match":expected.get("model")==model_hash,"definition_sha256":definition_hash,"model_sha256":model_hash}
	return not expected.is_empty() and expected.get("definition")==definition_hash and expected.get("model")==model_hash
