extends SceneTree
var checks:=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var catalog:=GarageCatalog.shared();check(catalog.vehicles.size()==16,"Full roster discovers sixteen loose folders")
	var holder:=Node3D.new();root.add_child(holder);var circuit:=LeoCircuit.new();var combinations:=0
	for vehicle in catalog.vehicles:
		check(vehicle.official,"Official fingerprint "+String(vehicle.id))
		check(await LeoAssets.scene_async(vehicle.model_path,self)!=null,"Loose import "+String(vehicle.id))
		for driver in catalog.drivers:
			var kart:=LeoKart.new();holder.add_child(kart);kart.setup(circuit,0,false,String(driver.id),String(vehicle.id));kart.set_physics_process(false);kart.set_process(false)
			check(kart.wheels.size()==vehicle.wheels.size(),"Topology "+String(vehicle.id))
			for i in vehicle.wheels.size():
				check(is_instance_valid(kart.wheels[i]),"Rolling group "+String(vehicle.id))
				check(kart.wheel_steering_pivots[i].position.is_equal_approx(vehicle.wheels[i].pivot),"Pivot "+String(vehicle.id))
			kart.wheel_motion_speed=12.;kart.wheel_visual_speed=12.;kart.animate_wheels(.1)
			for i in vehicle.wheels.size():check(absf(angle_difference(kart.wheel_angles[i],-1.2/vehicle.wheels[i].radius))<.00001,"Measured wheel travel "+String(vehicle.id))
			if vehicle.driver_policy==VehicleDefinition.DriverPolicy.CABIN:check(kart.driver.get_meta("visible_driver_id")==driver.id,"Selected cabin driver "+String(driver.id))
			kart.stop_audio();kart.free();combinations+=1
		await process_frame
	var cfg:=ConfigFile.new();cfg.set_value("game","driver",4);cfg.set_value("game","kart",8)
	var migrated:=catalog.migrate(cfg)
	check(catalog.drivers[migrated.x].id==&"human" and catalog.vehicles[migrated.y].id==&"race_bus","Legacy numeric preferences migrate by identity")
	cfg.set_value("game","vehicle_id","hover");migrated=catalog.migrate(cfg);check(catalog.vehicles[migrated.y].id==&"hover","Stable IDs survive roster reordering")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"vehicles":catalog.vehicles.size(),"combinations":combinations}
	FileAccess.open("res://build/modularity/full-roster.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("MODULARITY_FULL_ROSTER ",JSON.stringify(report))
	holder.free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
