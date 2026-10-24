extends SceneTree
const Converter=preload("res://scripts/content/workshop_converter.gd")
var checks:=0
var failures:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var source:="";var angle:=Vector3.ZERO;var scale:=1.
	var requested_output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):source=argument.trim_prefix("--source=")
		if argument.begins_with("--scale="):scale=float(argument.trim_prefix("--scale="))
		if argument.begins_with("--yaw="):angle.y=float(argument.trim_prefix("--yaw="))
		if argument.begins_with("--output="):requested_output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute("res://build/workshop-tests")
	if source.is_empty():
		var root:=Node3D.new();root.name="Fixture"
		var body:=MeshInstance3D.new();body.name="Body";var box:=BoxMesh.new();box.size=Vector3(1.6,.8,3.8);body.mesh=box;body.position.y=.9;root.add_child(body);body.owner=root
		for index in 4:
			var wheel:=MeshInstance3D.new();wheel.name="Wheel%d"%index;var cylinder:=CylinderMesh.new();cylinder.top_radius=.45;cylinder.bottom_radius=.45;cylinder.height=.22;cylinder.radial_segments=16;wheel.mesh=cylinder;wheel.rotation.z=PI/2;wheel.position=Vector3(-.9 if index%2==0 else .9,.45,-1.2 if index<2 else 1.2);root.add_child(wheel);wheel.owner=root
		if "--combined" in OS.get_cmdline_user_args():
			var combined:=ArrayMesh.new()
			for node in root.get_children():
				var tool:=SurfaceTool.new();tool.append_from(node.mesh,0,node.transform);tool.commit(combined);root.remove_child(node);node.free()
			var merged:=MeshInstance3D.new();merged.name="CombinedGeometry";merged.mesh=combined;root.add_child(merged);merged.owner=root
		var doc:=GLTFDocument.new();var state:=GLTFState.new();check(doc.append_from_scene(root,state)==OK,"fixture import");source="res://build/workshop-tests/source.glb";check(doc.write_to_filesystem(state,source)==OK,"fixture export");root.free()
	var hash_before:=FileAccess.get_sha256(source)
	var inspection:=Converter.inspect(source,angle,scale)
	check(inspection.ok,"inspection: "+str(inspection.get("error")));if not inspection.ok:quit(1);return
	print("WORKSHOP_INVENTORY islands=",inspection.islands.size()," triangles=",inspection.triangles," groups=",inspection.suggestions)
	print("WORKSHOP_BOUNDS ",inspection.bounds)
	if inspection.suggestions[0].is_empty():
		for island in inspection.islands:
			if island.kind=="wheel":print("CANDIDATE ",island.name," ",island.bounds)
	check(inspection.suggestions.size()==4,"four suggested groups")
	for group in inspection.suggestions:check(not group.is_empty(),"wheel detected")
	var result:=Converter.convert(source,{"inspection":inspection,"id":"workshop_fixture","wheel_groups":inspection.suggestions,"caliper_groups":inspection.calipers})
	check(result.ok,"conversion: "+str(result.get("error")));if not result.ok:quit(1);return
	check(result.definition.wheels.size()==4,"four bindings");check(result.definition.driver_policy==1,"no driver");check(result.definition.exhausts.size()==2,"blue boost positions")
	check(result.definition.electric_boost,"blue electric boost visual default")
	var overlap: Array=inspection.suggestions.duplicate(true);overlap[1]=overlap[0].duplicate()
	check(not Converter.convert(source,{"inspection":inspection,"wheel_groups":overlap}).ok,"overlapping wheel selections rejected")
	check(not Converter.inspect(source,Vector3(NAN,0,0),1.).ok,"invalid orientation rejected")
	check(not Converter.inspect(source,Vector3.ZERO,0.).ok,"zero scale rejected")
	var triangle_count:=0
	for node in result.scene.get_children():
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface);triangle_count+=arrays[Mesh.ARRAY_INDEX].size()/3
	check(triangle_count==inspection.triangles,"all original triangles preserved exactly once")
	for wheel in result.definition.wheels:check(wheel.radius>0 and wheel.pivot[1]>0,"grounded pivots and radii")
	var folder:="res://build/workshop-tests/converted-"+str(Time.get_ticks_usec())
	if not requested_output.is_empty():folder=requested_output
	var damaged: Dictionary=result.duplicate();damaged.definition=result.definition.duplicate(true);damaged.definition.wheels[0].radius=-1.
	var rejected:=Converter.export_folder(damaged,folder+"-invalid")
	check(not rejected.ok and not DirAccess.dir_exists_absolute(folder+"-invalid"),"damaged metadata rejected before publishing folder")
	var missing_binding: Dictionary=result.duplicate();missing_binding.definition=result.definition.duplicate(true);missing_binding.definition.wheels[0].rotating=["missing_wheel"]
	check(not Converter.export_folder(missing_binding,folder+"-missing").ok,"unresolved wheel binding rejected before export")
	var scan_base:="res://build/workshop-tests/scan-"+str(Time.get_ticks_usec());var scan_root:=scan_base.path_join("vehicles")
	DirAccess.make_dir_recursive_absolute(scan_root)
	var staging_root:=Converter.staging_root_for(scan_root.path_join("incomplete_car"))
	check(not staging_root.begins_with(scan_root+"/"),"staging is outside scanned vehicle root")
	var partial:=staging_root.path_join("incomplete");DirAccess.make_dir_recursive_absolute(partial)
	FileAccess.open(partial.path_join("vehicle.json"),FileAccess.WRITE).store_string('{"id":"partial"}')
	LeoVehicleLibrary.discover(scan_root)
	check(LeoVehicleLibrary.entries.is_empty() and LeoVehicleLibrary.unavailable.is_empty(),"metadata-first refresh cannot see incomplete staging folders")
	var output:=Converter.export_folder(result,folder);check(output.ok,"export: "+str(output.get("error")))
	check(FileAccess.get_sha256(source)==hash_before,"original preserved")
	check(not Converter.export_folder(result,folder).ok,"existing output protected")
	var first_island: Dictionary=inspection.islands[0]
	var region:=Converter.split_island(inspection,first_island.id,PackedInt32Array([0]))
	check(region.ok,"triangle region separation")
	check(not Converter.split_island(inspection,first_island.id,PackedInt32Array([-1])).ok,"invalid triangle selection rejected")
	var packed:=LeoVehicleImporter.import_scene(folder.path_join("model.glb"));check(packed.scene!=null,"runtime reimport")
	var reimported: Node3D=packed.scene.instantiate();var output_bounds:=AABB();var found:=false
	var original_materials: Dictionary={};var returned_materials: Dictionary={}
	for island in inspection.islands:
		if island.material:original_materials[material_signature(island.material)]=true
	for node in reimported.find_children("*","MeshInstance3D",true,false):
		var box: AABB=Converter.node_transform(node,reimported)*node.mesh.get_aabb();output_bounds=output_bounds.merge(box) if found else box;found=true
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if material:returned_materials[material_signature(material)]=true
	check(output_bounds.position.distance_to(inspection.bounds.position)<.001 and output_bounds.size.distance_to(inspection.bounds.size)<.001,"normalization and ground survive export exactly once")
	for signature in original_materials:
		if not returned_materials.has(signature):print("MATERIAL_EXPECTED ",signature)
		check(returned_materials.has(signature),"material properties and texture pixels preserved")
	if failures>0:
		for signature in returned_materials:print("MATERIAL_RETURNED ",signature)
	reimported.free()
	var definition:=LeoVehicleCodec.deserialize(result.definition,folder)
	definition.model=packed.scene
	check(definition.problems().is_empty(),"definition accepted")
	var actor:=LeoKart.new();actor.set_physics_process(false);root.add_child(actor)
	actor.visual=VehicleAssembler.assemble(definition,DriverDefinition.new());actor.add_child(actor.visual);actor.chassis=actor.visual.get_node("Chassis")
	check(actor.visual.get_node_or_null("Driver")==null,"no visible driver assembled")
	for binding in definition.wheels:actor.attach_binding(binding)
	var centers: Array=[]
	for wheel in actor.wheels:centers.append(wheel.to_global(wheel.mesh.get_aabb().get_center()))
	actor.wheel_motion_speed=12.;actor.steer=.7;actor.animate_wheels(.1)
	for index in 4:
		check(actor.wheel_spin_pivots[index].basis!=Basis.IDENTITY,"wheel spins")
		check(actor.wheels[index].to_global(actor.wheels[index].mesh.get_aabb().get_center()).distance_to(centers[index])<.001,"rotation center remains fixed")
		check((actor.wheel_steering_pivots[index].basis!=Basis.IDENTITY)==(index<2),"only front wheels steer")
		for path in definition.wheels[index].stationary_groups:
			var caliper:=VehicleAssembler.find_group(actor.chassis,path)
			check(caliper.get_parent()==actor.wheel_steering_pivots[index] and caliper.basis.is_equal_approx(Basis.IDENTITY),"caliper follows steering without rolling")
	actor.free()
	check_skin_rejection()
	result.scene.free();inspection.scene.free()
	print("WORKSHOP_CONVERTER ","PASS" if failures==0 else "FAIL"," checks=",checks," folder=",folder);quit(0 if failures==0 else 1)

func material_signature(material: Material) -> String:
	if not material is StandardMaterial3D:return material.resource_name
	var signature:=str(material.albedo_color)+":"+str(snappedf(material.roughness,.0001))+":"+str(snappedf(material.metallic,.0001))+":"+str(material.transparency)+":"+str(material.cull_mode)
	for slot in ["albedo_texture","normal_texture","emission_texture"]:
		var texture: Texture2D=material.get(slot)
		if texture:
			var image: Image=texture.get_image();image=image.duplicate()
			# Godot stores tangent normals as RG and reconstructs B on glTF export.
			# Their two authoritative tangent components must remain byte-identical.
			image.convert(Image.FORMAT_RG8 if slot=="normal_texture" else Image.FORMAT_RGBA8)
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data());signature+=slot+hash.finish().hex_encode()
	return signature

func check_skin_rejection() -> void:
	var fixture:=Node3D.new();fixture.name="SkinFixture"
	var skeleton:=Skeleton3D.new();skeleton.name="Rig";skeleton.add_bone("RootBone");fixture.add_child(skeleton);skeleton.owner=fixture
	var node:=MeshInstance3D.new();node.name="SkinnedMesh"
	var primitive:=BoxMesh.new();var arrays: Array=primitive.surface_get_arrays(0);var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
	for vertex in arrays[Mesh.ARRAY_VERTEX].size():bones.append_array(PackedInt32Array([0,0,0,0]));weights.append_array(PackedFloat32Array([1,0,0,0]))
	arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=mesh;fixture.add_child(node);node.owner=fixture
	var skin:=Skin.new();skin.add_bind(0,Transform3D.IDENTITY);node.skin=skin;node.skeleton=NodePath("../Rig")
	var document:=GLTFDocument.new();var state:=GLTFState.new();var path:="res://build/workshop-tests/live-skin.glb"
	check(document.append_from_scene(fixture,state)==OK and document.write_to_filesystem(state,path)==OK,"live skin fixture created")
	fixture.free();var result:=Converter.inspect(path)
	check(not result.ok and "skin" in String(result.get("error","")).to_lower(),"live skin rejected explicitly")
	if result.get("scene"):result.scene.free()
