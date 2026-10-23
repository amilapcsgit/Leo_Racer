class_name VehicleAssembler
extends RefCounted
## The only assembly path for previews, thumbnails, local racers and AI.
static func assemble(vehicle: VehicleDefinition, racer: DriverDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "VehicleAssembly"
	root.set_meta("vehicle_id",vehicle.id)
	root.set_meta("driver_id",racer.id)
	var body := vehicle.model.instantiate() as Node3D
	body.name = "Chassis"
	body.transform = vehicle.normalization * body.transform
	root.add_child(body)
	if not vehicle.preserve_materials: LeoRaceVisuals.polish_chassis(body)
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
	LeoAssets.apply_overrides(root)
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
