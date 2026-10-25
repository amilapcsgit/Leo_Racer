extends SceneTree
## Offline batch adapter around the existing Workshop; no driver resources load.
const Converter=preload("res://scripts/content/workshop_converter.gd")
var job: Dictionary
func _initialize() -> void:run.call_deferred()
func emit_report(value: Dictionary) -> void:
	var file:=FileAccess.open(String(job.report),FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"  ")+"\n");file.close()
	print("BATCH_VEHICLE ok=",value.get("ok",false)," error=",value.get("error",""));quit(0 if value.get("ok",false) else 2)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--job="):job=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--job=")))
	if job.is_empty():quit(2);return
	if job.get("mode")=="validate":await validate();return
	if job.get("mode")=="render":await render_model();return
	var input: String=job.get("source_model",job.source)
	var raw:=Converter.inspect(input)
	if not raw.ok:emit_report(raw);return
	prune(raw)
	var bounds: AABB=raw.bounds
	var angles:=Vector3.ZERO
	if bounds.size.x>bounds.size.z:angles.y=90.
	var length:=maxf(bounds.size.x,bounds.size.z)
	var scale:=1. if length>=3. and length<=7. else 4.6/maxf(length,.000001)
	if job.has("rotation"):angles=LeoVehicleCodec.vector(job.rotation)
	if job.has("scale"):scale=float(job.scale)
	raw.scene.free();raw.clear()
	var inspection:=Converter.inspect(input,angles,scale)
	if not inspection.ok:emit_report(inspection);return
	prune(inspection)
	var inventory: Array=[]
	for island in inspection.islands:
		inventory.append({"id":island.id,"name":island.name,"kind":island.kind,"center":LeoVehicleCodec.encode(island.center),"size":LeoVehicleCodec.encode(island.bounds.size),"triangles":island.triangles})
	var report:={"ok":true,"source_hash":inspection.source_hash,"rotation":LeoVehicleCodec.encode(angles),"scale":scale,"size":LeoVehicleCodec.encode(inspection.bounds.size),"triangles":inspection.triangles,"suggestions":inspection.suggestions,"calipers":inspection.calipers,"inventory":inventory}
	var groups: Array=job.get("wheel_groups",inspection.suggestions)
	var calipers: Array=job.get("caliper_groups",inspection.calipers)
	if job.has("regions"):
		groups=[[],[],[],[]];calipers=[[],[],[],[]]
		# Guided correction uses triangle centroids in explicit wheel boxes. It
		# splits supplied geometry, never invents wheels or duplicates body faces.
		for slot in 4:
			var region: Dictionary=job.regions[slot]
			var box:=AABB(LeoVehicleCodec.vector(region.center)-LeoVehicleCodec.vector(region.size)*.5,LeoVehicleCodec.vector(region.size))
			for island in inspection.islands.duplicate():
				if not box.intersects(island.bounds):continue
				var selected:=PackedInt32Array();var vertices: PackedVector3Array=island.arrays[Mesh.ARRAY_VERTEX]
				for triangle in int(island.triangles):
					var a: int=island.indices[triangle*3];var b: int=island.indices[triangle*3+1];var c: int=island.indices[triangle*3+2]
					if box.has_point((vertices[a]+vertices[b]+vertices[c])/3.):selected.append(triangle)
				if selected.is_empty():continue
				var key: String=island.id
				if selected.size()!=int(island.triangles):
					var split:=Converter.split_island(inspection,key,selected)
					if not split.ok:continue
					key=split.id
				if island.kind=="caliper":calipers[slot].append(key)
				else:groups[slot].append(key)
	if groups.any(func(group):return group.is_empty()):
		report.ok=false;report.error="Four complete wheel groups need guided correction."
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		if doc.append_from_scene(inspection.scene,state)==OK:doc.write_to_filesystem(state,String(job.preview))
	else:
		var converted:=Converter.convert(job.source,{"inspection":inspection,"id":job.id,"display_name":job.display_name,"wheel_groups":groups,"caliper_groups":calipers,"attribution":job.get("attribution","User-supplied local model. Original source retained; redistribution rights were not provided.")})
		if converted.ok:
			var result:=Converter.export_folder(converted,job.output)
			report.ok=result.ok;report.error=result.get("error","");report.folder=result.get("folder","")
			converted.scene.free()
		else:report.ok=false;report.error=converted.error
	inspection.scene.free();emit_report(report)

func prune(inspection: Dictionary) -> void:
	var excluded: Array=job.get("exclude_names",[])
	if excluded.is_empty():return
	inspection.islands=inspection.islands.filter(func(part):return not part.name in excluded)
	var box:=AABB();var first:=true;var count:=0
	for island in inspection.islands:
		box=island.bounds if first else box.merge(island.bounds);first=false;count+=int(island.triangles)
	# Ground surviving car geometry after removing explicit display geometry.
	var shift:=-box.position.y;var processed: Dictionary={}
	for island in inspection.islands:
		if not processed.has(island.surface_key):
			var arrays: Array=island.arrays.duplicate();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
			for index in vertices.size():vertices[index].y+=shift
			arrays[Mesh.ARRAY_VERTEX]=vertices;processed[island.surface_key]=arrays
		island.arrays=processed[island.surface_key]
		island.bounds.position.y+=shift;island.center=island.bounds.get_center()
	box.position.y=0.;inspection.bounds=box;inspection.triangles=count
	var suggestions:=Converter.suggest(inspection);inspection.suggestions=suggestions.wheels;inspection.calipers=suggestions.calipers

func validate() -> void:
	var folder: String=job.folder
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("vehicle.json")))
	var errors:=LeoVehicleLibrary.problems(data,folder)
	if not errors.is_empty():emit_report({"ok":false,"errors":Array(errors)});return
	var imported:=LeoVehicleImporter.import_scene(folder.path_join("model.glb"))
	if not imported.scene:emit_report({"ok":false,"error":imported.error});return
	var definition:=LeoVehicleCodec.deserialize(data,folder);definition.model=imported.scene;definition.official=false
	var model:=imported.scene.instantiate() as Node3D
	var binding_error:=Converter.bindings_problem(data,model)
	var triangles:=0;var surfaces:=0
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface);var index: Variant=arrays[Mesh.ARRAY_INDEX]
			triangles+=(index.size() if index!=null and not index.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3;surfaces+=1
	model.free()
	if not binding_error.is_empty():errors.append(binding_error)
	var actor:=LeoKart.new();root.add_child(actor);actor.set_physics_process(false);actor.set_process(false)
	actor.visual=VehicleAssembler.assemble(definition,DriverDefinition.new());actor.add_child(actor.visual);actor.chassis=actor.visual.get_node("Chassis");actor.definition=definition
	for binding in definition.wheels:actor.attach_binding(binding)
	var before: Array=[]
	for wheel in actor.wheels:before.append(wheel.to_global(wheel.mesh.get_aabb().get_center()))
	actor.wheel_motion_speed=12.;actor.steer=.65;actor.animate_wheels(.12)
	for index in 4:
		if actor.wheel_spin_pivots[index].basis.is_equal_approx(Basis.IDENTITY):errors.append("Wheel does not spin: "+str(index))
		if actor.wheels[index].to_global(actor.wheels[index].mesh.get_aabb().get_center()).distance_to(before[index])>.025:errors.append("Wheel rotation center moved: "+str(index))
		if (not actor.wheel_steering_pivots[index].basis.is_equal_approx(Basis.IDENTITY))!=(index<2):errors.append("Front steering assignment: "+str(index))
		for path in definition.wheels[index].stationary_groups:
			var caliper:=VehicleAssembler.find_group(actor.chassis,path)
			if caliper.get_parent()!=actor.wheel_steering_pivots[index]:errors.append("Caliper rolls with tyre")
	# Start reverse from rest, avoiding the intentional speed smoothing interval.
	actor.wheel_visual_speed=0.;actor.wheel_motion_speed=-12.
	for index in 4:actor.wheel_angles[index]=0.
	actor.animate_wheels(.01)
	for index in 4:
		if actor.wheel_angles[index]<=0.:errors.append("Reverse rotation direction: "+str(index))
		if actor.wheels[index].to_global(actor.wheels[index].mesh.get_aabb().get_center()).distance_to(before[index])>.025:errors.append("Reverse wheel center moved: "+str(index))
	if data.driver_policy!=1:errors.append("No-driver policy required")
	if data.exhausts.size()!=2 or not data.electric_boost:errors.append("Two blue boost emitters required")
	actor.free();emit_report({"ok":errors.is_empty(),"errors":Array(errors),"triangles":triangles,"surfaces":surfaces,"wheels":4,"reverse_checked":true,"driver_tests":0,"boost_emitters":2,"import_seconds":imported.seconds,"cache_hit":imported.cache_hit})

func render_model() -> void:
	root.size=Vector2i(720,500);root.content_scale_size=Vector2i.ZERO
	var world:=Node3D.new();root.add_child(world)
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	if document.append_from_file(job.model,state)!=OK:emit_report({"ok":false,"error":"Preview import failed"});return
	var model:=document.generate_scene(state) as Node3D;LeoVehicleImporter.strip_nonvisual(model);world.add_child(model)
	if job.has("vehicle_folder"):
		var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(String(job.vehicle_folder).path_join("vehicle.json")))
		model.transform=LeoVehicleCodec.transform(metadata.normalization)*model.transform
	var box:=AABB();var found:=false
	for node in model.find_children("*","MeshInstance3D",true,false):
		var b: AABB=Converter.node_transform(node,model)*node.mesh.get_aabb();box=box.merge(b) if found else b;found=true
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("192a3d");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("d4e4ef");env.environment.ambient_light_energy=.85;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.8;world.add_child(light)
	var camera:=Camera3D.new();camera.fov=42.;world.add_child(camera);camera.make_current()
	var target:=box.get_center();var distance:=maxf(box.size.length()*.9,3.)
	for side in ["front","rear"]:
		camera.position=target+Vector3(distance*.65,distance*.37,(-1. if side=="front" else 1.)*distance*.85);camera.look_at(target)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(String(job.prefix)+"-"+side+".png")
	world.free();emit_report({"ok":true})
