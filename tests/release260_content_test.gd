extends SceneTree
var errors: Array[String]=[]
var checks:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	LeoAssets.configure(ProjectSettings.globalize_path("res://build/preview260/GameAssets"));LeoAssets.mount_packs()
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path("res://build/runtime260/GameAssets/vehicles"))
	check(LeoVehicleLibrary.unavailable.is_empty(),"No unavailable official packs: "+str(LeoVehicleLibrary.unavailable))
	var catalog:=GarageCatalog.shared()
	check(catalog.vehicles.size()==21,"Exactly 21 default cars")
	if catalog.vehicles.is_empty():quit(1);return
	check(catalog.vehicles[-1].id==&"duster_2024","2024 Duster is car 21")
	check(LeoDefaultRoster.fallback(catalog)==&"bigster","Bigster fallback")
	var saved:=ConfigFile.new();saved.set_value("game","vehicle_id","duster")
	check(catalog.vehicles[catalog.migrate(saved).y].id==&"duster","Saved Duster selection retained")
	for vehicle in catalog.vehicles:
		check(vehicle.official,"Official fingerprint "+String(vehicle.id))
		check(vehicle.content_data.vehicle_api==2,"Compiled API2 "+String(vehicle.id))
		check(not vehicle.compiled_bounds.is_empty(),"Precomputed bounds "+String(vehicle.id))
		var compiled:=vehicle.model.instantiate() as Node3D
		for binding in vehicle.wheels:
			for path in binding.rotating_groups+binding.stationary_groups:check(VehicleAssembler.find_group(compiled,path)!=null,"Compiled wheel path / "+String(vehicle.id)+" / "+String(path))
		compiled.free()
	for key in [&"duster",&"duster_2024"]:
		var vehicle:=catalog.vehicle(key)
		if not vehicle:continue
		await LeoAssets.scene_async(vehicle.model_path,self)
		for driver in catalog.drivers:
			var assembly:=VehicleAssembler.assemble(vehicle,driver);root.add_child(assembly)
			check(assembly.get_node_or_null("Driver")!=null,"Driver "+String(driver.id)+" / "+String(key))
			var body:=assembly.get_node("Chassis")
			var feature: LeoVehicleFeatures=body.get_node_or_null("VehicleLighting")
			check(feature!=null and feature.diagnostics.is_empty(),"All lamps/hinges resolve "+String(key))
			if feature:
				feature.set_process(false)
				for slot in [1,2]:
					check(feature.trigger(slot),"Action "+str(slot))
					feature._process(.2);feature.trigger(slot);feature._process(2.)
					for repeated in 3:feature.trigger(slot);feature._process(2.);feature.trigger(slot);feature._process(2.)
					for state in feature.actions:
						for target in state.targets:check(target.node.transform.is_equal_approx(target.base),"Repeated/partial reversal closes exactly")
				feature.update_state(true,true)
				check(feature.braking and feature.reversing,"Brake/reverse state")
				var second:=VehicleAssembler.assemble(vehicle,driver);root.add_child(second)
				var other: LeoVehicleFeatures=second.get_node("Chassis/VehicleLighting")
				check(not other.braking and not other.reversing,"Independent lamp instances")
				second.free()
			for binding in vehicle.wheels:
				for path in binding.rotating_groups:check(VehicleAssembler.find_group(body,path)!=null,"Wheel path "+String(key))
			assembly.free()
			await process_frame
		var kart:=LeoKart.new();root.add_child(kart);kart.setup(LeoCircuit.new(),0,false,"human",String(key))
		kart.set_process(false);kart.set_physics_process(false)
		check(kart.wheel_spin_pivots.size()==4 and kart.wheels.all(func(wheel):return is_instance_valid(wheel)),"Four supplied wheels bind")
		kart.wheel_motion_speed=12.;kart.steer=.5;kart.animate_wheels(.1)
		check(kart.wheel_spin_pivots.all(func(wheel):return not wheel.basis.is_equal_approx(Basis.IDENTITY)),"All four wheels roll")
		check(absf(kart.wheel_steering_pivots[0].rotation.y)>.01 and absf(kart.wheel_steering_pivots[2].rotation.y)<.001,"Front steering and rear axle separation")
		check(kart.definition.collision_size.is_equal_approx(LeoVehiclePresentation.resolve(vehicle).collision_size),"Presentation collision dimensions retained")
		kart.free()
	var fake: Dictionary=catalog.vehicle(&"duster").content_data.duplicate(true)
	fake.estimated_bytes=-1
	check(not LeoVehicleLibrary.problems(fake,catalog.vehicle(&"duster").content_folder,false).is_empty(),"Invalid cache estimate rejected")
	fake.estimated_bytes=catalog.vehicle(&"duster").estimated_bytes
	fake.pack_sha256="invalid"
	check(not LeoVehiclePack.problem(fake,catalog.vehicle(&"duster").content_folder).is_empty(),"Damaged pack rejected")
	fake.pack_sha256=catalog.vehicle(&"duster").content_data.pack_sha256
	fake.model_scene="res://scripts/main.gd"
	check(not LeoVehiclePack.problem(fake,catalog.vehicle(&"duster").content_folder).is_empty(),"Core resource path rejected")
	var duplicate_root:=ProjectSettings.globalize_path("res://build/duplicate260")
	for folder in ["one","two"]:
		DirAccess.make_dir_recursive_absolute(duplicate_root.path_join(folder))
		FileAccess.open(duplicate_root.path_join(folder).path_join("vehicle.json"),FileAccess.WRITE).store_string(JSON.stringify(catalog.vehicle(&"duster").content_data))
	LeoVehicleLibrary.discover(duplicate_root)
	check(LeoVehicleLibrary.entries.is_empty() and LeoVehicleLibrary.unavailable.size()==2,"Duplicate compiled IDs rejected before mounting")
	var report:={"checks":checks,"errors":errors,"status":"PASS" if errors.is_empty() else "FAIL"}
	FileAccess.open("res://build/content260-result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CONTENT260 ",JSON.stringify(report));LeoPreviewStream.clear();LeoAssets.cache.clear();quit(0 if errors.is_empty() else 1)
