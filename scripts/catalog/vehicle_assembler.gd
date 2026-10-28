class_name VehicleAssembler
extends RefCounted
## The only assembly path for previews, thumbnails, local racers and AI.
static func assemble(vehicle: VehicleDefinition, racer: DriverDefinition) -> Node3D:
	vehicle=LeoVehiclePresentation.resolve(vehicle)
	var root := Node3D.new()
	root.name = "VehicleAssembly"
	root.set_meta("vehicle_id",vehicle.id)
	root.set_meta("driver_id",racer.id)
	var body := vehicle.model.instantiate() as Node3D
	body.name = "Chassis"
	body.transform = vehicle.normalization * body.transform
	root.add_child(body)
	attach_driver(root,vehicle,racer)
	finish_body(root,vehicle)
	return root

static func attach_driver(root: Node3D,vehicle: VehicleDefinition,racer: DriverDefinition) -> void:
	if vehicle.driver_policy!=VehicleDefinition.DriverPolicy.IDENTITY_ONLY:
		if vehicle.driver_policy==VehicleDefinition.DriverPolicy.FIXED:
			racer=GarageCatalog.shared().driver(vehicle.fixed_driver_id)
		var cabin:=vehicle.driver_policy==VehicleDefinition.DriverPolicy.CABIN
		var model: PackedScene=racer.cabin_model if cabin else (vehicle.fixed_driver_model if vehicle.driver_policy==VehicleDefinition.DriverPolicy.FIXED and vehicle.fixed_driver_model else racer.seated_model)
		var driver := model.instantiate() as Node3D
		driver.name = "Driver"
		driver.set_meta("visible_driver_id",racer.id)
		var fit: Transform3D=vehicle.driver_fits.get(String(racer.id),vehicle.seat)
		driver.transform = fit * (Transform3D.IDENTITY if cabin else racer.orientation) * driver.transform
		root.add_child(driver)
		if racer.material_albedo: bind_albedo(driver,racer.material_name,racer.material_albedo)
		for key in racer.material_bindings:
			if racer.material_bindings[key] is Texture2D: bind_albedo(driver,String(key),racer.material_bindings[key])

static func finish_body(root: Node3D,vehicle: VehicleDefinition) -> void:
	var body:=root.get_node("Chassis") as Node3D
	LeoAssets.apply_overrides(root)
	if not body.get_meta("finish_prepared",false):preload("res://scripts/catalog/vehicle_finish.gd").install(body,vehicle.visual_profile)
	if not body.get_meta("surface_prepared",false):preload("res://scripts/catalog/vehicle_surface_profile.gd").install(body,String(vehicle.id))
	LeoVehicleFeatures.install(body,vehicle)

static func assemble_async(vehicle: VehicleDefinition,racer: DriverDefinition,tree: SceneTree,current: Callable,preview_scene: PackedScene=null) -> Node3D:
	if not current.is_valid() or not current.call():return null
	vehicle=LeoVehiclePresentation.resolve(vehicle)
	var started:=Time.get_ticks_usec()
	var root:=Node3D.new();root.name="VehicleAssembly"
	root.set_meta("vehicle_id",vehicle.id);root.set_meta("driver_id",racer.id)
	var body: Node3D=(preview_scene if preview_scene else vehicle.model).instantiate();body.name="Chassis"
	body.transform=vehicle.normalization*body.transform;root.add_child(body)
	LeoPreviewStream.timings.append({"vehicle":String(vehicle.id),"stage":"instantiate","ms":(Time.get_ticks_usec()-started)/1000.})
	await tree.process_frame
	if not current.is_valid() or not current.call():root.free();return null
	started=Time.get_ticks_usec();attach_driver(root,vehicle,racer)
	LeoPreviewStream.timings.append({"vehicle":String(vehicle.id),"stage":"driver","ms":(Time.get_ticks_usec()-started)/1000.})
	await tree.process_frame
	if not current.is_valid() or not current.call():root.free();return null
	started=Time.get_ticks_usec();finish_body(root,vehicle)
	LeoPreviewStream.timings.append({"vehicle":String(vehicle.id),"stage":"materials","ms":(Time.get_ticks_usec()-started)/1000.})
	return root


static func bind_albedo(node: Node, material_name: String, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var old: Material = node.mesh.surface_get_material(i)
			if old is StandardMaterial3D and old.resource_name==material_name:
				var mat := old.duplicate() as StandardMaterial3D
				mat.albedo_texture=texture
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): bind_albedo(child,material_name,texture)

static func find_group(body: Node3D, path: NodePath) -> Node3D:
	var exact := body.get_node_or_null(path) as Node3D
	return exact if exact else body.find_child(String(path),true,false) as Node3D
