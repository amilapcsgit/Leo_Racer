extends SceneTree
var errors: Array[String]=[]
var assertions := 0
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	assertions+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	var catalog:=GarageCatalog.shared()
	check(catalog.problems().is_empty(),"Validated catalog")
	check(catalog.vehicles.size()==16 and catalog.drivers.size()==6,"16 vehicles × 6 racers")
	var circuit:=LeoCircuit.new()
	var holder:=Node3D.new();root.add_child(holder)
	for d in catalog.drivers:
		for v in catalog.vehicles:
			var kart:=LeoKart.new();holder.add_child(kart)
			kart.setup(circuit,0,false,d.id,v.id)
			kart.set_physics_process(false);kart.set_process(false)
			for child in kart.visual.get_children():child.set_process(false)
			check((kart.driver!=null)==(v.driver_policy==VehicleDefinition.DriverPolicy.SEATED),"Driver policy "+String(d.id)+" / "+String(v.id))
			check(kart.wheels.size()==v.wheels.size(),"Wheel count "+String(v.id))
			var expected:=0 if v.hovering else (3 if v.id==&"colombo_tuk" else 4)
			check(kart.wheels.size()==expected,"Wheel topology "+String(v.id))
			for i in v.wheels.size():
				for path in v.wheels[i].stationary_groups:
					check(is_instance_valid(VehicleAssembler.find_group(kart.chassis,path)),"Stationary caliper resolves "+String(v.id))
				check(is_instance_valid(kart.wheels[i]),"Binding resolves "+String(v.id))
				check(kart.wheel_steering_pivots[i].position.distance_to(v.wheels[i].pivot)<.00001,"Stable wheel pivot "+String(v.id))
				check(kart.wheel_spin_pivots[i].basis.is_equal_approx(Basis.IDENTITY),"Rest wheel bind basis")
			kart.wheel_motion_speed=12.;kart.wheel_visual_speed=12.
			kart.animate_wheels(.1)
			for i in v.wheels.size():
				check(absf(angle_difference(kart.wheel_angles[i],-1.2/v.wheels[i].radius))<.00001,"Individual travel / radius "+String(v.id))
				check(absf(kart.wheel_spin_pivots[i].basis.determinant()-1.)<.00001,"Wheel basis remains orthogonal")
			var before:=kart.wheel_angles.duplicate();kart.wheel_motion_speed=0.;kart.wheel_visual_speed=0.;kart.animate_wheels(.25)
			check(before==kart.wheel_angles,"Stationary tires "+String(v.id))
			kart.wheel_motion_speed=-12.;kart.wheel_visual_speed=-12.;kart.animate_wheels(.1)
			for angle in kart.wheel_angles:check(absf(angle)<.00001,"Reverse unwinds measured wheel travel")
			kart.boost(1.,"TEST");kart.next_gate=7;kart.recover()
			check(kart.boost_time==0 and not kart.drifting and kart.next_gate==7,"Recovery preserves gates and clears effects")
			if v.id==&"human":check(false,"Invalid vehicle identity")
			rows.append({"driver":String(d.id),"vehicle":String(v.id),"wheels":kart.wheels.size(),"visible_driver":kart.driver!=null})
			kart.free()
	check(catalog.driver(&"human").seated_model.resource_path.contains("modular/driver_human"),"Helmeted Shaven Leo replaces old model")
	check(catalog.driver(&"human").material_name=="Wolf3D_Headwear","Matching helmet PNG bound to headwear only")
	var cfg:=ConfigFile.new();cfg.set_value("game","driver",4);cfg.set_value("game","kart",8);cfg.set_value("audio","volume",.31);cfg.set_value("display","reduced_motion",true);cfg.set_value("game","best_time_astra",177.)
	check(catalog.migrate(cfg)==Vector2i(4,8),"Legacy numeric selection migration")
	check(cfg.get_value("audio","volume")==.31 and cfg.get_value("display","reduced_motion") and cfg.get_value("game","best_time_astra")==177.,"Migration retains preferences and records")
	cfg.set_value("game","driver_id","mario");cfg.set_value("game","vehicle_id","hover");check(catalog.migrate(cfg)==Vector2i(5,11),"Stable IDs override obsolete numeric fields")
	var extra:=catalog.vehicles[9].duplicate(true) as VehicleDefinition;extra.id=&"onboarding_probe";extra.display_name="A future imported car with a deliberately long name";catalog.vehicles.append(extra)
	# Import a separate test GLB through Godot's glTF document API, rather than
	# merely reusing the imported PackedScene. No shipping roster is modified.
	var copy_path:="res://build/onboarding_probe.glb"
	FileAccess.open(copy_path,FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes("res://assets/models/modular/duster.glb"))
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	check(document.append_from_file(copy_path,state)==OK,"Additional GLB input imports successfully")
	var imported:=document.generate_scene(state)
	var packed:=PackedScene.new();check(packed.pack(imported)==OK,"Additional GLB creates an independent PackedScene");imported.free();extra.model=packed
	check(catalog.vehicle(extra.id)==extra and catalog.problems().is_empty(),"Catalog expansion without gameplay/UI changes")
	var probe:=VehicleAssembler.assemble(extra,catalog.drivers[5]);holder.add_child(probe);check(probe.get_meta("vehicle_id")==extra.id,"Expanded entry uses shared assembler");probe.free()
	catalog.vehicles.pop_back()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"selections":rows.size(),"assertions":assertions,"combinations":rows}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa-modular-garage"))
	FileAccess.open("res://docs/qa-modular-garage/catalog.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MODULAR_CATALOG_REPORT | ",report.status," | selections=",rows.size()," | assertions=",assertions)
	holder.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
