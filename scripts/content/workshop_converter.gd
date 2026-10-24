extends RefCounted
## Offline visual-only GLB conversion. No supplied scripts or physics are executed.
const VERSION := 1

static func failure(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func node_transform(node: Node3D, root: Node3D) -> Transform3D:
	var value:=node.transform
	var parent:=node.get_parent()
	while parent is Node3D and parent!=root:
		value=parent.transform*value;parent=parent.get_parent()
	return root.transform*value if node!=root else root.transform

static func root_of(parent: PackedInt32Array, index: int) -> int:
	while parent[index]!=index:
		parent[index]=parent[parent[index]];index=parent[index]
	return index

static func inspect(path: String, rotation_degrees: Vector3=Vector3.ZERO, scale: float=1.) -> Dictionary:
	if not FileAccess.file_exists(path):return failure("Source GLB does not exist.")
	if not is_finite(scale) or scale<=0:return failure("Scale must be finite and greater than zero.")
	if not rotation_degrees.is_finite():return failure("Orientation angles must be finite.")
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	if doc.append_from_file(path,state)!=OK:return failure("Cannot decode this GLB. Supply a self-contained glTF 2 GLB.")
	var scene:=doc.generate_scene(state) as Node3D
	if not scene:return failure("GLB contains no 3D scene.")
	var rotation:=Basis.from_euler(rotation_degrees*PI/180.)
	var transform:=Transform3D(rotation.scaled(Vector3.ONE*scale),Vector3.ZERO)
	var islands: Array=[];var first:=true;var total_bounds:=AABB();var triangles:=0
	var nodes: Array=scene.find_children("*","MeshInstance3D",true,false)
	if scene is MeshInstance3D:nodes.push_front(scene)
	for node in nodes:
		if node.skin or not node.skeleton.is_empty() and node.get_node_or_null(node.skeleton) is Skeleton3D:
			scene.free();return failure("Live skinned geometry requires pose baking before conversion. Export a static/rest-pose GLB.")
		if not node.mesh:continue
		var baked: Transform3D=transform*node_transform(node,scene)
		if absf(baked.basis.determinant())<1e-18:scene.free();return failure("A mesh has a zero/singular scale. Repair its transform before import.")
		for surface in node.mesh.get_surface_count():
			if node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:
				scene.free();return failure("Only triangle surfaces are supported; triangulate this model before import.")
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_BONES]!=null and not arrays[Mesh.ARRAY_BONES].is_empty():
				scene.free();return failure("Skinned vertex weights need pose baking before conversion.")
			var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			for index in positions.size():
				positions[index]=baked*positions[index]
				if not positions[index].is_finite():scene.free();return failure("Model contains non-finite vertex positions.")
			arrays[Mesh.ARRAY_VERTEX]=positions
			var normal_basis:=baked.basis.inverse().transposed()
			if arrays[Mesh.ARRAY_NORMAL]!=null:
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
				for index in normals.size():normals[index]=(normal_basis*normals[index]).normalized()
				arrays[Mesh.ARRAY_NORMAL]=normals
			if arrays[Mesh.ARRAY_TANGENT]!=null:
				var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT].duplicate()
				for index in range(0,tangents.size(),4):
					var direction: Vector3=(baked.basis*Vector3(tangents[index],tangents[index+1],tangents[index+2])).normalized()
					tangents[index]=direction.x;tangents[index+1]=direction.y;tangents[index+2]=direction.z
					if baked.basis.determinant()<0:tangents[index+3]*=-1.
				arrays[Mesh.ARRAY_TANGENT]=tangents
			var indices:=PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX].duplicate()
			if indices.is_empty():
				for index in positions.size():indices.append(index)
			if indices.size()%3!=0:
				scene.free();return failure("Invalid triangle index count.")
			for index in indices:
				if index<0 or index>=positions.size():scene.free();return failure("Triangle indices refer outside their vertex array.")
			if baked.basis.determinant()<0:
				for index in range(0,indices.size(),3):
					var swap:=indices[index];indices[index]=indices[index+2];indices[index+2]=swap
			arrays[Mesh.ARRAY_INDEX]=indices
			var parents:=PackedInt32Array();parents.resize(positions.size())
			var weld: Dictionary={}
			for index in positions.size():
				parents[index]=index
				var point:=positions[index];var key:=Vector3i(roundi(point.x*100000.),roundi(point.y*100000.),roundi(point.z*100000.))
				if weld.has(key):parents[index]=root_of(parents,int(weld[key]))
				else:weld[key]=index
			for index in range(0,indices.size(),3):
				var a:=root_of(parents,indices[index]);var b:=root_of(parents,indices[index+1]);var c:=root_of(parents,indices[index+2]);parents[b]=a;parents[c]=a
			var groups: Dictionary={}
			for index in range(0,indices.size(),3):
				var group:=root_of(parents,indices[index]);if not groups.has(group):groups[group]=PackedInt32Array()
				groups[group].append_array(indices.slice(index,index+3))
			for group in groups:
				var subset: PackedInt32Array=groups[group]
				var box:=AABB(positions[subset[0]],Vector3.ZERO)
				for index in subset:box=box.expand(positions[index])
				if first:total_bounds=box;first=false
				else:total_bounds=total_bounds.merge(box)
				var name:=String(node.name);var low:=name.to_lower();var kind:="body"
				if "caliper" in low or "brake" in low:kind="caliper"
				elif "wheel" in low or "tyre" in low or "tire" in low or "hub" in low or "disk" in low or "rim" in low:kind="wheel"
				islands.append({"id":"island_%d"%islands.size(),"name":name,"node_path":String(scene.get_path_to(node)),"surface_key":str(node.get_instance_id())+":"+str(surface),"format":node.mesh.surface_get_format(surface),"bounds":box,"center":box.get_center(),"triangles":subset.size()/3,"kind":kind,"arrays":arrays,"indices":subset,"material":node.get_active_material(surface)})
				triangles+=subset.size()/3
	if first:scene.free();return failure("GLB has no visible triangle geometry.")
	# Ground both the preview and authoritative baked geometry once.
	var ground:=-total_bounds.position.y
	var grounded: Dictionary={}
	for island in islands:
		if not grounded.has(island.surface_key):
			var arrays: Array=island.arrays.duplicate();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			for index in vertices.size():vertices[index].y+=ground
			arrays[Mesh.ARRAY_VERTEX]=vertices;grounded[island.surface_key]=arrays
		island.arrays=grounded[island.surface_key]
		var box: AABB=island.bounds;box.position.y+=ground;island.bounds=box;island.center=box.get_center()
	total_bounds.position.y=0.;scene.transform=transform*scene.transform;scene.position.y+=ground
	var result:={"ok":true,"error":"","source_path":path,"source_hash":FileAccess.get_sha256(path),"scene":scene,"bounds":total_bounds,"islands":islands,"triangles":triangles,"rotation_degrees":rotation_degrees,"scale":scale,"warnings":["Confirm all four wheels and orientation before exporting. Connected geometry may require triangle-region correction."]}
	var suggested:=suggest(result);result.suggestions=suggested.wheels;result.calipers=suggested.calipers
	return result

static func suggest(inspection: Dictionary) -> Dictionary:
	var groups: Array=[[],[],[],[]];var calipers: Array=[[],[],[],[]];var seeds: Array=[]
	var whole: AABB=inspection.bounds
	for island in inspection.islands:
		var size: Vector3=island.bounds.size;var center: Vector3=island.center
		if island.kind=="caliper" or "spare" in String(island.name).to_lower():continue
		if island.kind=="body" and absf(center.x-whole.get_center().x)<whole.size.x*.28:continue
		# Wheel plane is Y/Z after the user's orientation step. Ignore horizontal spare tyres.
		if size.y<whole.size.y*.1 or size.z<whole.size.y*.1 or size.x>maxf(size.y,size.z)*.8 or center.y>whole.size.y*.62:continue
		if maxf(size.y,size.z)/maxf(minf(size.y,size.z),.0001)>1.8:continue
		seeds.append(island)
	var named_seeds: Array=seeds.filter(func(item):return item.kind=="wheel")
	var named:=named_seeds.size()>=4
	if named:seeds=named_seeds
	seeds.sort_custom(func(a,b):return a.bounds.size.y>b.bounds.size.y)
	var centers: Array=[]
	for seed in seeds:
		var duplicate:=false
		for center in centers:
			if seed.center.distance_to(center)<maxf(seed.bounds.size.y*.6,.05):duplicate=true;break
		if not duplicate:centers.append(seed.center)
		if centers.size()==4:break
	if centers.size()!=4:return {"wheels":groups,"calipers":calipers}
	centers.sort_custom(func(a,b):return a.z<b.z)
	if centers[0].x>centers[1].x:var v: Vector3=centers[0];centers[0]=centers[1];centers[1]=v
	if centers[2].x>centers[3].x:var v: Vector3=centers[2];centers[2]=centers[3];centers[3]=v
	for island in inspection.islands:
		if named and island.kind=="body":continue
		if "spare" in String(island.name).to_lower():continue
		var closest:=0;var distance:=INF
		for index in 4:
			var candidate: float=island.center.distance_to(centers[index])
			if candidate<distance:closest=index;distance=candidate
		var size: Vector3=island.bounds.size
		if island.kind=="body" and not island in seeds and (size.length()>whole.size.y*.8 or distance>whole.size.y*.24):continue
		if distance<whole.size.y*.45:
			if island.kind=="caliper":calipers[closest].append(island.id)
			else:groups[closest].append(island.id)
	return {"wheels":groups,"calipers":calipers}

static func split_island(inspection: Dictionary, id: String, triangles: PackedInt32Array) -> Dictionary:
	# Explicit region correction: triangle numbers refer to the chosen island, not source-global IDs.
	for island in inspection.get("islands",[]):
		if island.id!=id:continue
		var selected: Dictionary={}
		for triangle in triangles:
			if triangle<0 or triangle>=int(island.triangles):return failure("Triangle selection is outside this island.")
			selected[triangle]=true
		if selected.is_empty() or selected.size()==int(island.triangles):return failure("Select a non-empty part of the island to separate.")
		var keep:=PackedInt32Array();var moved:=PackedInt32Array()
		for index in int(island.triangles):
			if selected.has(index):moved.append_array(island.indices.slice(index*3,index*3+3))
			else:keep.append_array(island.indices.slice(index*3,index*3+3))
		var derivative: Dictionary=island.duplicate();derivative.id="island_%d"%inspection.islands.size();derivative.indices=moved;derivative.triangles=moved.size()/3
		island.indices=keep;island.triangles=keep.size()/3
		for part in [island,derivative]:
			var vertices: PackedVector3Array=part.arrays[Mesh.ARRAY_VERTEX];var box:=AABB(vertices[part.indices[0]],Vector3.ZERO)
			for vertex in part.indices:box=box.expand(vertices[vertex])
			part.bounds=box;part.center=box.get_center()
		inspection.islands.append(derivative)
		return {"ok":true,"error":"","id":derivative.id}
	return failure("Unknown island.")

static func mesh_for(islands: Array) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	var surfaces: Dictionary={}
	for island in islands:
		if not surfaces.has(island.surface_key):
			surfaces[island.surface_key]=island.duplicate();surfaces[island.surface_key].indices=PackedInt32Array()
		surfaces[island.surface_key].indices.append_array(island.indices)
	for island in surfaces.values():
		var original: Array=island.arrays;var indices: PackedInt32Array=island.indices
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		var remap: Dictionary={};var used:=PackedInt32Array();var compact:=PackedInt32Array()
		for source in indices:
			if not remap.has(source):remap[source]=used.size();used.append(source)
			compact.append(remap[source])
		# Preserve per-vertex attributes while removing vertices belonging to other islands.
		for slot in Mesh.ARRAY_MAX:
			if slot in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX]:continue
			if original[slot]==null or original[slot].is_empty():continue
			var values: Variant=original[slot].duplicate();values.resize(0)
			var stride:=maxi(1,original[slot].size()/original[Mesh.ARRAY_VERTEX].size())
			for source in used:
				for element in stride:values.append(original[slot][source*stride+element])
			arrays[slot]=values
		arrays[Mesh.ARRAY_INDEX]=compact
		var custom_flags: int=int(island.get("format",0)) & ((7<<13)|(7<<16)|(7<<19)|(7<<22))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},custom_flags)
		mesh.surface_set_material(mesh.get_surface_count()-1,island.material)
	return mesh

static func convert(path: String, options: Dictionary={}) -> Dictionary:
	var inspection: Dictionary=options.get("inspection",{})
	if inspection.is_empty():inspection=inspect(path,options.get("rotation_degrees",Vector3.ZERO),float(options.get("scale",1.)))
	if not inspection.get("ok",false):return inspection
	var groups: Array=options.get("wheel_groups",inspection.suggestions)
	var calipers: Array=options.get("caliper_groups",inspection.calipers)
	if groups.size()!=4 or calipers.size()!=4:return failure("Choose exactly four wheel assemblies.")
	var registry: Dictionary={};var taken: Dictionary={}
	for island in inspection.islands:registry[island.id]=island
	var root:=Node3D.new();root.name="CustomCar";var bindings: Array=[]
	for index in 4:
		if groups[index].is_empty():root.free();return failure("Wheel %d has no selected triangles."%(index+1))
		var parts: Array=[];var stationary: Array=[]
		for key in groups[index]+calipers[index]:
			if not registry.has(key) or taken.has(key):root.free();return failure("Wheel selections are missing or overlap: "+str(key))
			taken[key]=true
			if key in groups[index]:parts.append(registry[key])
			else:stationary.append(registry[key])
		var box: AABB=parts[0].bounds
		for part in parts:box=box.merge(part.bounds)
		var wheel:=MeshInstance3D.new();wheel.name="wheel_%d"%index;wheel.mesh=mesh_for(parts);root.add_child(wheel);wheel.owner=root
		var fixed_paths: Array=[]
		if not stationary.is_empty():
			var fixed:=MeshInstance3D.new();fixed.name="caliper_%d"%index;fixed.mesh=mesh_for(stationary);root.add_child(fixed);fixed.owner=root;fixed_paths.append(String(fixed.name))
		bindings.append({"rotating":[String(wheel.name)],"stationary":fixed_paths,"pivot":LeoVehicleCodec.encode(box.get_center()),"axle":[1,0,0],"radius":maxf(box.size.y,box.size.z)*.5,"steering":index<2})
	var body_parts: Array=[]
	for island in inspection.islands:
		if not taken.has(island.id):body_parts.append(island)
	if body_parts.is_empty():root.free();return failure("No body geometry remains. Review wheel selections.")
	var body:=MeshInstance3D.new();body.name="Body";body.mesh=mesh_for(body_parts);root.add_child(body);body.owner=root
	var definition:=VehicleDefinition.new();definition.id=StringName(options.get("id","custom_car"));definition.display_name=options.get("display_name",path.get_file().get_basename())
	definition.driver_policy=VehicleDefinition.DriverPolicy.IDENTITY_ONLY;definition.max_speed=165./3.6;definition.boosted_speed=198./3.6;definition.electric_boost=true;definition.setup_complete=true;definition.preserve_materials=true
	var box: AABB=inspection.bounds;definition.collision_size=box.size;definition.collision_position=box.get_center();definition.preview_target=box.get_center();definition.preview_distance=maxf(box.size.length()*1.4,6.)
	definition.exhausts=PackedVector3Array([Vector3(-box.size.x*.28,box.size.y*.22,box.end.z+.08),Vector3(box.size.x*.28,box.size.y*.22,box.end.z+.08)])
	var data:=LeoVehicleCodec.serialize(definition);data.wheels=bindings;data.attribution=options.get("attribution","User supplied model. Retain the original creator and redistribution license.")
	var id_pattern:=RegEx.new();id_pattern.compile("^[a-z0-9][a-z0-9_.-]{0,63}$")
	if not id_pattern.search(String(data.id)):root.free();return failure("Use a lowercase portable vehicle ID (letters, numbers, underscores, dots, dashes).")
	return {"ok":true,"error":"","scene":root,"definition":data,"report":{"converter":VERSION,"source_sha256":inspection.source_hash,"triangles":inspection.triangles,"islands":inspection.islands.size(),"wheels":4,"driver":"none","boost_emitters":2}}

static func export_folder(converted: Dictionary, destination: String) -> Dictionary:
	if not converted.get("ok",false):return failure("Convert and validate the vehicle before saving.")
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):return failure("Destination already exists; choose a new folder to preserve existing content.")
	if not converted.get("definition") is Dictionary or not converted.get("scene") is Node3D or not is_instance_valid(converted.scene):return failure("Converted scene or metadata is missing.")
	var metadata_errors:=LeoVehicleLibrary.problems(converted.definition,"",false)
	if not metadata_errors.is_empty():return failure("Invalid vehicle metadata: "+"; ".join(metadata_errors))
	var binding_error:=bindings_problem(converted.definition,converted.scene)
	if not binding_error.is_empty():return failure(binding_error)
	var parent:=destination.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent)!=OK:return failure("Cannot create destination parent directory.")
	# Keep incomplete manifests outside the immediate vehicle discovery root. The
	# same-volume sibling permits an atomic rename when every file is verified.
	var staging_root:=staging_root_for(destination)
	if DirAccess.make_dir_recursive_absolute(staging_root)!=OK:return failure("Cannot create staging parent outside the vehicles folder.")
	var temporary:=staging_root.path_join(destination.get_file()+"-"+str(Time.get_ticks_usec()))
	if DirAccess.make_dir_absolute(temporary)!=OK:return failure("Cannot create staging folder.")
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	if doc.append_from_scene(converted.scene,state)!=OK or doc.write_to_filesystem(state,temporary.path_join("model.glb"))!=OK:return failure("Cannot export the converted GLB; staging folder retained for recovery.")
	for item in [["vehicle.json",JSON.stringify(converted.definition,"\t")+"\n"],["conversion-report.json",JSON.stringify(converted.get("report",{}),"\t")+"\n"],["LICENSE.txt",String(converted.definition.get("attribution","User supplied content; retain its original license."))+"\n"]]:
		var file:=FileAccess.open(temporary.path_join(item[0]),FileAccess.WRITE)
		if not file:return failure("Cannot write vehicle metadata; staging folder retained.")
		file.store_string(item[1]);var write_error:=file.get_error();file.close()
		if write_error!=OK:return failure("Vehicle metadata write failed; staging folder retained.")
	var image:=Image.create(256,144,false,Image.FORMAT_RGB8);image.fill(Color("102733"))
	if image.save_png(temporary.path_join("thumbnail.png"))!=OK:return failure("Cannot write vehicle thumbnail; staging folder retained.")
	var written_data: Variant=JSON.parse_string(FileAccess.get_file_as_string(temporary.path_join("vehicle.json")))
	var written_errors:=LeoVehicleLibrary.problems(written_data,temporary,true)
	if not written_errors.is_empty():return failure("Exported metadata validation failed: "+"; ".join(written_errors))
	var verify:=GLTFDocument.new();var verify_state:=GLTFState.new()
	if verify.append_from_file(temporary.path_join("model.glb"),verify_state)!=OK:return failure("Exported GLB validation failed; staging folder retained.")
	var verified_scene:=verify.generate_scene(verify_state) as Node3D
	if not verified_scene:return failure("Exported GLB has no scene; staging folder retained.")
	binding_error=bindings_problem(written_data,verified_scene);verified_scene.free()
	if not binding_error.is_empty():return failure("Exported "+binding_error)
	if DirAccess.rename_absolute(temporary,destination)!=OK:return failure("Cannot finalize output folder; original source and staging output are retained.")
	return {"ok":true,"error":"","folder":destination}

static func staging_root_for(destination: String) -> String:
	return destination.get_base_dir().get_base_dir().path_join(".workshop-staging")

static func bindings_problem(data: Dictionary, scene: Node3D) -> String:
	var wheels: Array=data.get("wheels",[])
	if wheels.size()!=4:return "Vehicle workshop output requires exactly four wheel bindings."
	var assigned: Array[String]=[]
	for wheel in wheels:
		for path in wheel.get("rotating",[])+wheel.get("stationary",[]):
			if not VehicleAssembler.find_group(scene,NodePath(path)) is MeshInstance3D:return "Wheel binding does not identify a mesh: "+String(path)
			for previous in assigned:
				if path==previous or String(path).begins_with(previous+"/") or previous.begins_with(String(path)+"/"):return "Wheel bindings overlap: "+String(path)
			assigned.append(String(path))
	return ""
