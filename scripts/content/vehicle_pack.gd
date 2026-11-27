class_name LeoVehiclePack
extends RefCounted
## Vehicle API 2 packs are namespaced, self-contained compiled resources.
static var mounted: Dictionary = {}
static var official: Dictionary={}
static var code_patterns: PackedStringArray=[]
static func trusted(id: String, digest: String) -> bool:
	if official.is_empty():official=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/official-vehicles.json"))
	return official.get(id,{}).get("model","")==digest
static func code_problem(file: FileAccess, offset: int, size: int, extension: String) -> String:
	if code_patterns.is_empty():
		code_patterns.append("GDExtension".to_utf8_buffer().hex_encode())
		for type in ClassDB.get_class_list():
			if type==&"Script" or ClassDB.is_parent_class(type,&"Script"):code_patterns.append(String(type).to_utf8_buffer().hex_encode())
	file.seek(offset)
	if extension in ["scn","res"]:
		if file.get_32()!=0x43525352:return "Use uncompressed binary scene/resources from the Vehicle SDK"
		file.seek(offset)
	var remaining:=size;var tail:=PackedByteArray()
	while remaining>0:
		var bytes:=file.get_buffer(mini(remaining,262144))
		if bytes.is_empty():return "Truncated vehicle resource"
		var encoded:=(tail+bytes).hex_encode()
		for pattern in code_patterns:
			if encoded.contains(pattern):return "Content packs cannot contain embedded scripts or extensions"
		tail=bytes.slice(maxi(0,bytes.size()-128));remaining-=bytes.size()
	return ""
static func scene_problem(scene: PackedScene, active: Dictionary={}, depth: int=0) -> String:
	if depth>32 or active.has(scene.get_instance_id()):return "Recursive compiled scene"
	active[scene.get_instance_id()]=true
	var state:=scene.get_state()
	if state.get_connection_count()>0:return "Compiled model scenes cannot contain signal connections"
	var allowed: Array[StringName]=[&"Node",&"Node3D",&"MeshInstance3D",&"MultiMeshInstance3D",&"Skeleton3D",&"BoneAttachment3D",&"AnimationPlayer",&"Marker3D",&"GPUParticles3D",&"CPUParticles3D"]
	for index in state.get_node_count():
		var type:=state.get_node_type(index)
		if index==0 and not type.is_empty() and type!=&"Node3D" and not ClassDB.is_parent_class(type,&"Node3D"):return "Compiled model root must be spatial"
		if not type.is_empty() and type not in allowed:return "Unsupported node in compiled vehicle: "+String(type)
		for property in state.get_node_property_count(index):
			var name:=state.get_node_property_name(index,property)
			var value: Variant=state.get_node_property_value(index,property)
			if name==&"script" and value!=null:return "Vehicle nodes cannot have scripts"
			if name==&"libraries" and value is Dictionary:
				for library in value.values():
					if not library is AnimationLibrary:continue
					for animation_name in library.get_animation_list():
						var animation: Animation=library.get_animation(animation_name)
						for track in animation.get_track_count():
							if animation.track_get_type(track) in [Animation.TYPE_METHOD,Animation.TYPE_AUDIO] or animation.track_get_path(track).is_absolute():return "Vehicle animations must contain local property tracks only"
		var nested:=state.get_node_instance(index)
		if nested:
			var problem:=scene_problem(nested,active,depth+1)
			if not problem.is_empty():return problem
	active.erase(scene.get_instance_id())
	return ""
static func references_problem(data: Dictionary, names: Array) -> String:
	if not String(data.model_scene) in names:return "Missing compiled vehicle scene"
	if not String(data.get("preview_scene",data.model_scene)) in names:return "Missing compiled preview scene"
	if data.has("shader_warmup_scene") and (not data.shader_warmup_scene is String or not data.shader_warmup_scene in names):return "Invalid shader warm-up scene"
	if not data.get("warmup_resources",[]) is Array:return "Invalid warm-up resource list"
	for resource in data.get("warmup_resources",[]):
		if not resource is String or not resource in names or resource.get_extension()!="res":return "Invalid warm-up resource"
	return ""
static func problem(data: Dictionary, folder: String) -> String:
	for field in ["id","pack","pack_sha256","model_scene"]:
		if not data.get(field) is String:return "Invalid compiled pack metadata"
	if data.has("preview_scene") and not data.preview_scene is String:return "Invalid preview scene"
	var id := String(data.get("id",""))
	var relative := String(data.get("pack",""))
	if not LeoVehicleLibrary.safe_relative(relative) or relative.get_extension()!="pck":return "Invalid vehicle pack path"
	var path := folder.path_join(relative)
	if not FileAccess.file_exists(path):return "Missing vehicle pack"
	var digest := FileAccess.get_sha256(path)
	if digest!=String(data.get("pack_sha256","")):return "Damaged vehicle pack"
	var known:=trusted(id,digest)
	var prefix := "res://leo_vehicles/"+id+"/"
	for key in ["model_scene","preview_scene"]:
		var scene := String(data.get(key,data.get("model_scene","")))
		if not scene.begins_with(prefix) or scene.contains("..") or scene.get_extension()!="scn":return "Scene is outside vehicle namespace"
	if mounted.has(path) and mounted[path].digest==digest:return references_problem(data,mounted[path].names)
	# Inspect the actual directory, not a caller-supplied inventory.
	var f := FileAccess.open(path,FileAccess.READ)
	if not f or f.get_length()<100 or f.get_32()!=0x43504447:return "Invalid PCK header"
	var version := f.get_32()
	if version not in [2,3,4]:return "Unsupported PCK version"
	f.seek(20)
	if f.get_32()&1:return "Encrypted vehicle packs are unsupported"
	var file_base:=f.get_64()
	if file_base<0 or file_base>f.get_length():return "Invalid PCK payload offset"
	var directory_offset := f.get_64() if version>=3 else 96
	if directory_offset<40 or directory_offset>f.get_length()-4:return "Invalid PCK directory"
	f.seek(directory_offset)
	var count := f.get_32()
	if count<1 or count>4096:return "Invalid PCK entry count"
	var names: Array[String] = []
	for i in count:
		var length := f.get_32()
		if length<1 or length>1024 or f.get_position()+length+36>f.get_length():return "Invalid PCK entry"
		var encoded:=f.get_buffer(length)
		var end:=encoded.find(0)
		var name := (encoded.slice(0,end) if end>=0 else encoded).get_string_from_utf8()
		if not name.begins_with("res://"):name="res://"+name
		if not name.begins_with(prefix) or name.contains("..") or name in names:return "Conflicting vehicle resource path"
		if name.get_extension() not in ["scn","res","tres","ctex","png","dds","webp","jpg","gdshader"]:return "Vehicle packs must contain data resources only"
		if ResourceLoader.exists(name):return "Vehicle namespace already mounted"
		names.append(name)
		var offset:=f.get_64();var size:=f.get_64();f.get_buffer(16)
		if f.get_32()!=0:return "Unsupported PCK entry flags"
		if offset<0 or size<4 or file_base+offset+size>f.get_length():return "Truncated PCK payload"
		if name.get_extension() in ["scn","res"]:
			var cursor:=f.get_position();f.seek(file_base+offset)
			var magic:=f.get_32();f.seek(cursor)
			if magic not in [0x43525352,0x43435352]:return "Invalid compiled resource header"
		if not known and name.get_extension() in ["scn","res","tres"]:
			var cursor:=f.get_position()
			var unsafe:=code_problem(f,file_base+offset,size,name.get_extension())
			f.seek(cursor)
			if not unsafe.is_empty():return unsafe
	var reference_error:=references_problem(data,names)
	if not reference_error.is_empty():return reference_error
	if not ProjectSettings.load_resource_pack(path,false):return "Cannot mount vehicle pack"
	for name in names:
		if name.get_extension() not in ["scn","res","tres","gdshader"]:continue
		for dependency in ResourceLoader.get_dependencies(name):
			var target: String=String(dependency).split("::")[-1]
			if not target.begins_with(prefix):return "Vehicle resource references content outside its namespace"
	if not known:
		for name in names:
			if name.get_extension()!="scn":continue
			var scene:=ResourceLoader.load(name,"PackedScene") as PackedScene
			if not scene:return "Invalid compiled model scene"
			var unsafe:=scene_problem(scene)
			if not unsafe.is_empty():return unsafe
	mounted[path]={"digest":digest,"names":names}
	return ""
