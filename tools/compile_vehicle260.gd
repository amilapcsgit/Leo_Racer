extends SceneTree
## Offline only: turn a validated loose vehicle into one bundled, GPU-ready scene.
func _initialize() -> void:run.call_deferred()
var texture_cache: Dictionary={}
var destination_folder:=""
var vehicle_prefix:=""
var warmup_resources: Array[String]=[]
var texture_bytes:=0
var merged_meshes:=0
func relative_pose(node: Node3D, anchor: Node3D) -> Transform3D:
	var pose:=node.transform;var parent:=node.get_parent()
	while parent is Node3D and parent!=anchor:pose=parent.transform*pose;parent=parent.get_parent()
	return pose
func own_children(node: Node, scene: Node) -> void:
	for child in node.get_children():child.owner=scene;own_children(child,scene)
func batch_static(root: Node3D, data: Dictionary) -> void:
	# Keep every interaction path and all transparent surfaces independent.
	if not root.find_children("*","AnimationPlayer",true,false).is_empty():return
	var anchors: Array[Node]=[root];var protected: Array[Node]=[]
	if data.get("ultra_cockpit",false):
		for node in root.find_children("*","MeshInstance3D",true,false):
			var label := String(node.name).to_lower()
			if "steering_wheel" in label or "mirror" in label or "gauges" in label or "dash" in label or "_steer" in label or "needle_" in label or "stalk" in label or "ceiling" in label:protected.append(node)
	if data.get("ultra_trunk",false):
		for node in root.find_children("*","MeshInstance3D",true,false):
			if "tailgate" in String(node.name).to_lower() or ("rear_plate" in String(node.name).to_lower() or String(node.name)=="Bigster_Rear_EU_Band"):protected.append(node)
	for wheel in data.get("wheels",[]):
		for path in wheel.get("rotating",[])+wheel.get("stationary",[]):
			# Published bindings may name a group below an imported GLB root.
			# Protect the same resolved group used by the runtime assembler.
			var node:=VehicleAssembler.find_group(root,NodePath(path))
			if node:anchors.append(node);protected.append(node)
	for action in data.get("actions",[]):
		for target in action.get("targets",[]):
			var node:=root.get_node_or_null(NodePath(target.node))
			if node:anchors.append(node);protected.append(node)
	for lamp in data.get("lighting",[]):
		for target in lamp.get("targets",[]):
			var node:=root.get_node_or_null(NodePath(target.node))
			if node:protected.append(node)
	var groups: Dictionary={}
	for node in root.find_children("*","MeshInstance3D",true,false):
		if node in protected or not node.mesh or node.skin or node.material_overlay or not node.visible:continue
		if node.mesh.get_blend_shape_count()>0:continue
		var opaque:=true
		for i in node.mesh.get_surface_count():
			var material:=node.get_active_material(i) as StandardMaterial3D
			if not material or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:opaque=false
		if not opaque:continue
		var anchor: Node=node.get_parent()
		while anchor not in anchors and anchor!=root:anchor=anchor.get_parent()
		var key:=str(anchor.get_instance_id())+":"+str(node.cast_shadow)+":"+str(node.layers)
		if not groups.has(key):groups[key]={"anchor":anchor,"nodes":[],"shadow":node.cast_shadow,"layers":node.layers}
		groups[key].nodes.append(node)
	for group in groups.values():
		if group.nodes.size()<2:continue
		var importers: Array[ImporterMesh]=[];var transforms: Array[Transform3D]=[]
		for node in group.nodes:
			var mesh:=ImporterMesh.from_mesh(node.mesh)
			for i in node.mesh.get_surface_count():
				var material: Material=node.get_active_material(i)
				mesh.set_surface_material(i,material);mesh.set_surface_name(i,str(material.get_instance_id()))
			importers.append(mesh);transforms.append(relative_pose(node,group.anchor))
		var combined:=ImporterMesh.merge_importer_meshes(importers,transforms,true)
		var batch:=MeshInstance3D.new();batch.name=String(data.get("display_name",data.id)).replace(" ","_")+"_Static_Batch"
		batch.mesh=combined.get_mesh();batch.cast_shadow=group.shadow;batch.layers=group.layers
		group.anchor.add_child(batch);batch.owner=root
		for node in group.nodes:
			var placeholder:=Node3D.new();placeholder.transform=node.transform
			var parent: Node=node.get_parent();var label: String=node.name
			parent.add_child(placeholder)
			for child in node.get_children():child.reparent(placeholder,false)
			parent.remove_child(node);node.free();placeholder.name=label;placeholder.owner=root;own_children(placeholder,root)
		merged_meshes+=group.nodes.size()-1
func store_texture(value: Texture2D) -> Texture2D:
	var relative:="textures/texture_%03d.res"%warmup_resources.size()
	var disk:=destination_folder.path_join(relative)
	if ResourceSaver.save(value,disk)!=OK:push_error("Cannot save compiled texture");return null
	var target:=vehicle_prefix+relative
	value.take_over_path(target);warmup_resources.append(target)
	texture_bytes+=FileAccess.get_file_as_bytes(disk).size()
	return value
func bounds(node: Node3D, pose: Transform3D=Transform3D.IDENTITY) -> AABB:
	var transform:=pose*node.transform
	var box: AABB=transform*node.mesh.get_aabb() if node is MeshInstance3D and node.mesh else AABB()
	for child in node.get_children():
		if child is Node3D:
			var other:=bounds(child,transform)
			if other.size.length_squared()>0.:box=other if box.size.length_squared()==0. else box.merge(other)
	return box
func vector(value: Vector3) -> Array:return [value.x,value.y,value.z]
func texture(source: Texture2D, data: bool) -> Texture2D:
	if not source:return null
	var key:=str(source.get_instance_id())+str(data)
	if texture_cache.has(key):return texture_cache[key]
	var image:=source.get_image()
	if not image:return source
	if image.is_compressed():
		texture_cache[key]=store_texture(source);return texture_cache[key]
	if maxi(image.get_width(),image.get_height())>2048:
		var factor:=2048./maxi(image.get_width(),image.get_height());image.resize(maxi(4,int(image.get_width()*factor)),maxi(4,int(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	image.resize(nearest_po2(image.get_width()),nearest_po2(image.get_height()),Image.INTERPOLATE_LANCZOS)
	if not image.has_mipmaps():image.generate_mipmaps()
	var compressed:=PortableCompressedTexture2D.new()
	compressed.keep_compressed_buffer=true
	compressed.create_from_image(image,PortableCompressedTexture2D.COMPRESSION_MODE_S3TC)
	texture_cache[key]=store_texture(compressed)
	return texture_cache[key]
func prepare(node: Node) -> void:
	if node.get_script():node.set_script(null)
	if node is MeshInstance3D and node.mesh:
		var mesh: ArrayMesh=node.mesh
		var importer:=ImporterMesh.from_mesh(mesh)
		for i in mesh.get_surface_count():importer.set_surface_material(i,node.get_active_material(i))
		importer.generate_lods(25.,60.,[])
		node.mesh=importer.get_mesh()
		for i in node.mesh.get_surface_count():
			var material:=node.get_active_material(i) as StandardMaterial3D
			if not material:continue
			for field in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture","emission_texture","clearcoat_texture"]:
				material.set(field,texture(material.get(field),field not in ["albedo_texture","emission_texture"]))
	for child in node.get_children():prepare(child)
func warmup_scene(root: Node3D, disk: String) -> String:
	# Tiny representatives retain shader feature combinations, not source textures.
	var proxies:=Node3D.new();var seen: Dictionary={}
	var pixel:=Image.create(1,1,false,Image.FORMAT_RGBA8);pixel.fill(Color.WHITE)
	var neutral_texture:=ImageTexture.create_from_image(pixel)
	for node in root.find_children("*","MeshInstance3D",true,false):
		for index in node.mesh.get_surface_count():
			var original:=node.get_active_material(index) as StandardMaterial3D
			if not original or seen.has(original.get_instance_id()):continue
			seen[original.get_instance_id()]=true
			var material:=original.duplicate() as StandardMaterial3D
			for property in material.get_property_list():
				if material.get(property.name) is Texture2D:material.set(property.name,neutral_texture)
			var sphere:=SphereMesh.new();sphere.radius=.35;sphere.height=.7;sphere.radial_segments=8;sphere.rings=4;sphere.material=material
			var proxy:=MeshInstance3D.new();proxy.mesh=sphere;proxy.position=Vector3(0,1.1,0);proxy.visible=false
			proxies.add_child(proxy);proxy.owner=proxies
	var packed:=PackedScene.new();packed.pack(proxies)
	var result:=ResourceSaver.save(packed,disk);proxies.free()
	return vehicle_prefix+"shader_warmup.scn" if result==OK else ""
func remove_cockpit_stalks(root: Node3D) -> int:
	var removed:=0
	for node in root.find_children("*","MeshInstance3D",true,false):
		if String(node.name)!="dust25_dash":continue
		var mesh:=ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var kept:=PackedInt32Array()
			for i in range(0,indices.size(),3):
				var stalk:=true
				for j in 3:
					var p: Vector3=vertices[indices[i+j]]
					var right:=p.x>=.140 and p.x<=.277 and p.y>=.833 and p.y<=.945 and p.z>=.437 and p.z<=.558
					if not right:stalk=false;break
				if stalk:removed+=1
				else:
					for j in 3:kept.append(indices[i+j])
			if kept.is_empty():continue
			arrays[Mesh.ARRAY_INDEX]=kept;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(mesh.get_surface_count()-1,node.get_active_material(surface))
		node.mesh=mesh
	return removed
func recess_cockpit_column(root: Node3D) -> int:
	# Reviewed interior-only shroud: the supplied reversed wheel left its fixed
	# column cover protruding in front of the now-correct driver-facing rim.
	var changed:=0
	for node in root.find_children("*","MeshInstance3D",true,false):
		if String(node.name) not in ["dust25_dash","dust25_dash_003"]:continue
		var pose:=relative_pose(node,root);var inverse:=pose.affine_inverse();var mesh:=ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for n in points.size():
				var p:=pose*points[n]
				if p.x<-.49 or p.x>-.20 or p.y<.80 or p.y>1.13 or p.z<-.62 or p.z>-.30:continue
				var weight:=smoothstep(-.62,-.58,p.z)
				p.z-=.22*weight;points[n]=inverse*p;changed+=1
			arrays[Mesh.ARRAY_VERTEX]=points;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(surface,node.get_active_material(surface))
		node.mesh=mesh
	return changed
func run() -> void:
	var folder:="";var destination:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):folder=arg.trim_prefix("--source=")
		if arg.begins_with("--destination="):destination=arg.trim_prefix("--destination=")
	if folder.is_empty() or destination.is_empty():quit(2);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("vehicle.json")))
	destination_folder=destination;vehicle_prefix="res://leo_vehicles/"+String(data.id)+"/"
	if data.get("ultra_trunk",false):vehicle_prefix="res://ultra_vehicles/bigster/"
	if data.get("ultra_cockpit",false):vehicle_prefix="res://cockpit278/"+String(data.id)+"/"
	if int(data.get("cockpit_revision",0))==279:vehicle_prefix="res://cockpit279/"+String(data.id)+"/"
	DirAccess.make_dir_recursive_absolute(destination.path_join("textures"))
	var loaded:=LeoVehicleImporter.import_scene(folder.path_join(data.model))
	if not loaded.scene:push_error(loaded.error);quit(2);return
	var scene: PackedScene=loaded.scene
	var root:=scene.instantiate() as Node3D
	if data.get("ultra_cockpit",false) and data.id=="duster_2024":
		var donor_scene:=LeoVehicleImporter.import_scene(ProjectSettings.globalize_path("res://assets/models/bigster/bigster_232.glb"))
		if not donor_scene.scene:push_error(donor_scene.error);quit(2);return
		var donor: Node3D=donor_scene.scene.instantiate()
		var shared:=Node3D.new();shared.name="SharedCockpit";root.add_child(shared);shared.owner=root
		var parts:=["dust25_carpet","dust25_dash","dust25_dash_001","dust25_dash_002","dust25_dash_003","dust25_gauges","dust25_seat_FL","dust25_seat_FR","dust25_seats_R","dust25_steering_wheel","dust25_steering_wheel_001"]
		for node in root.find_children("*","MeshInstance3D",true,false):
			if String(node.name).replace(".","_") in parts:node.get_parent().remove_child(node);node.free()
		for node in donor.find_children("*","MeshInstance3D",true,false):
			if String(node.name).replace(".","_") not in parts:continue
			var part:=node.duplicate() as Node3D;part.transform=relative_pose(node,donor)
			shared.add_child(part);part.owner=root;own_children(part,root)
		donor.free()
	if data.get("ultra_cockpit",false):
		data.removed_stalk_triangles=remove_cockpit_stalks(root)
		data.column_repair_vertices=recess_cockpit_column(root)
	preload("res://scripts/catalog/vehicle_finish.gd").install(root,String(data.get("visual_profile","")))
	preload("res://scripts/catalog/vehicle_surface_profile.gd").install(root,String(data.id))
	batch_static(root,data)
	prepare(root)
	root.set_meta("finish_prepared",true);root.set_meta("surface_prepared",true)
	var box:=bounds(root)
	data.compiled_bounds={"position":vector(box.position),"size":vector(box.size)}
	var packed:=PackedScene.new()
	if packed.pack(root)!=OK:quit(2);return
	DirAccess.make_dir_recursive_absolute(destination)
	var scene_file:=destination.path_join("model.scn")
	if ResourceSaver.save(packed,scene_file)!=OK:quit(2);return
	var warmup_file:=destination.path_join("shader_warmup.scn")
	data.shader_warmup_scene=warmup_scene(root,warmup_file)
	if data.shader_warmup_scene.is_empty():quit(2);return
	var target:=vehicle_prefix+"model.scn"
	var pck:=PCKPacker.new();var pack_file:=destination.path_join("vehicle.pck")
	if pck.pck_start(pack_file)!=OK or pck.add_file(target,scene_file)!=OK:quit(2);return
	if pck.add_file(data.shader_warmup_scene,warmup_file)!=OK:quit(2);return
	for resource in warmup_resources:
		if pck.add_file(resource,destination.path_join(resource.trim_prefix(vehicle_prefix)))!=OK:quit(2);return
	if pck.flush()!=OK:quit(2);return
	data.vehicle_api=2;data.core={"min":"2.6.0","max_major":2};data.pack="vehicle.pck";data.pack_sha256=FileAccess.get_sha256(pack_file)
	data.model_scene=target;data.preview_scene=target;data.source_model_sha256=FileAccess.get_sha256(folder.path_join(data.model))
	data.warmup_resources=warmup_resources
	data.estimated_bytes=(FileAccess.get_file_as_bytes(scene_file).size()+texture_bytes)*3
	FileAccess.open(destination.path_join("vehicle.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
	FileAccess.open(destination.path_join("compile-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS","id":data.id,"textures":texture_cache.size(),"scene_bytes":FileAccess.get_file_as_bytes(scene_file).size(),"bounds":data.compiled_bounds,"lods_generated":true,"merged_static_meshes":merged_meshes,"pack_sha256":data.pack_sha256},"  "))
	root.free();print("VEHICLE_PACK_COMPILED ",data.id);quit()
