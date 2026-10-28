extends SceneTree
var errors: Array[String]=[]
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func pose(node: Node3D) -> Transform3D:
	var result:=node.transform;var parent:=node.get_parent()
	while parent is Node3D:result=parent.transform*result;parent=parent.get_parent()
	return result
func collisions(node: Node, root_node: Node, output: Dictionary) -> void:
	if node is CollisionShape3D:
		var properties: Dictionary={}
		for field in node.shape.get_property_list():
			if field.usage & PROPERTY_USAGE_STORAGE and not String(field.name).begins_with("resource_"):properties[field.name]=node.shape.get(field.name)
		# Auto-generated @ node names are sanitized by PackedScene serialization.
		# Traversal order, world transforms, shape type and every stored field must match.
		output[str(output.size())]=[pose(node),node.disabled,node.shape.get_class(),properties]
	for child in node.get_children():collisions(child,root_node,output)
func inspect(node: Node, data: Dictionary) -> void:
	if node is GeometryInstance3D and node.get_meta("street_receiver",false):
		var box: AABB
		if node is MeshInstance3D:box=pose(node)*node.mesh.get_aabb()
		elif node is MultiMeshInstance3D:box=pose(node)*node.get_meta("instance_bounds",node.multimesh.get_aabb())
		data.receivers+=1
		data.largest_span=maxf(data.largest_span,maxf(box.size.x,box.size.z))
		if maxf(box.size.x,box.size.z)>32.1: data.oversize+=1
	for child in node.get_children():inspect(child,data)
func run() -> void:
	LeoAssets.configure(ProjectSettings.globalize_path("res://build/lighting-content/GameAssets"));LeoAssets.mount_packs()
	for definition in LeoTrackDefinition.discover():
		if definition.id=="astra_coast":continue
		definition.mount()
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/Preview-2.6.0/GameAssets/tracks/"+definition.id+"/manifest.json"))
		var before: Node=load(original.scene).instantiate();var after: Node=load(definition.metadata.scene).instantiate()
		var old_shapes: Dictionary={};var new_shapes: Dictionary={};collisions(before,before,old_shapes);collisions(after,after,new_shapes)
		var unchanged: bool=var_to_bytes(old_shapes)==var_to_bytes(new_shapes)
		if not unchanged:
			for key in old_shapes:
				if not new_shapes.has(key):print("COLLISION_MISSING ",key)
				elif var_to_bytes(old_shapes[key])!=var_to_bytes(new_shapes[key]):
					for field in 4:
						if var_to_bytes(old_shapes[key][field])!=var_to_bytes(new_shapes[key][field]):print("COLLISION_DIFF ",key," field=",field," before=",str(old_shapes[key][field]).left(400)," after=",str(new_shapes[key][field]).left(400))
		if not unchanged:errors.append(definition.id+": collision geometry changed")
		var data: Dictionary={"track":definition.id,"collision_shapes":old_shapes.size(),"collision_identical":unchanged,"receivers":0,"largest_span":0.,"oversize":0}
		inspect(after,data);rows.append(data);before.free();after.free()
	var report: Dictionary={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"tracks":rows}
	var output:=ProjectSettings.globalize_path("res://build/qa-lighting/preservation")
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LIGHTING_PRESERVATION ",JSON.stringify(report));quit(0 if errors.is_empty() else 2)
