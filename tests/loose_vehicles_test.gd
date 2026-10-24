extends SceneTree
var errors: Array[String]=[]
var checks:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func write(path: String,value: Dictionary) -> void:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(value))
func run() -> void:
	LeoVehicleLibrary.discover()
	print("DISCOVERY ",LeoVehicleLibrary.root," unavailable=",LeoVehicleLibrary.unavailable)
	if LeoVehicleLibrary.entries.is_empty():quit(1);return
	check(LeoVehicleLibrary.entries.size()==2,"Development discovery has exactly two cars")
	check(LeoAssets.cache.is_empty(),"Metadata scan loads no model or thumbnail")
	var catalog:=GarageCatalog.shared()
	check(catalog.drivers.size()==6 and catalog.vehicles.size()==2,"Shared catalog retains six drivers")
	for vehicle in catalog.vehicles:
		check(vehicle.official,"Migrated vehicle fingerprint: "+String(vehicle.id))
		var key:=LeoVehicleImporter.key(vehicle.model_path)
		var cached:="user://content-cache/vehicles/"+key+".scn"
		if FileAccess.file_exists(cached):DirAccess.remove_absolute(cached)
		var frames:=Engine.get_process_frames()
		var scene:=await LeoAssets.scene_async(vehicle.model_path,self)
		check(scene!=null,"Import loose "+String(vehicle.id))
		check(Engine.get_process_frames()>frames,"Import yields responsive frames")
		check(not LeoVehicleImporter.last_report.cache_hit,"First import is cold")
		check(FileAccess.file_exists(cached),"Disposable scene cache created")
		var model:=scene.instantiate() as Node3D;root.add_child(model)
		for wheel in vehicle.wheels:
			for path in wheel.rotating_groups:check(VehicleAssembler.find_group(model,path)!=null,"Wheel binding resolves: "+String(path))
		model.free();LeoAssets.cache.clear()
		check(await LeoAssets.scene_async(vehicle.model_path,self)!=null and LeoVehicleImporter.last_report.cache_hit,"Warm import uses persistent cache")
		var original: VehicleDefinition=load("res://assets/catalog/runtime/vehicle_"+String(vehicle.id)+".tres")
		check(vehicle.normalization.is_equal_approx(original.normalization),"Normalization preserved")
		check(vehicle.collision_size.is_equal_approx(original.collision_size),"Collision preserved")
		check(LeoRaceRules.resolve(vehicle)==LeoRaceRules.resolve(original),"Official performance preserved")
	var base:=catalog.vehicles[0]
	var fixture:="user://modularity-fixture";DirAccess.make_dir_recursive_absolute(fixture)
	var changed_file:=ProjectSettings.globalize_path(fixture.path_join("change.glb"));var bytes:=FileAccess.get_file_as_bytes(base.model_path)
	FileAccess.open(changed_file,FileAccess.WRITE).store_buffer(bytes)
	var before:=LeoVehicleImporter.key(changed_file)
	await LeoAssets.scene_async(changed_file,self)
	var unaffected: PackedScene=await LeoAssets.scene_async(catalog.vehicles[1].model_path,self)
	var size:=int(bytes.decode_u32(12));var text:=bytes.slice(20,20+size).get_string_from_utf8();var changed_text:=text.replace('"name"','"nAme"').to_utf8_buffer()
	check(changed_text.size()==size and text.contains('"name"'),"Fixture changes only optional GLB names")
	for i in size:bytes[20+i]=changed_text[i]
	FileAccess.open(changed_file,FileAccess.WRITE).store_buffer(bytes)
	LeoAssets.refresh_loose_cache()
	check(not LeoAssets.cache.has(changed_file) and LeoVehicleImporter.key(changed_file)!=before,"Changed model invalidates its own cache entry")
	check(LeoAssets.cache.get(catalog.vehicles[1].model_path)==unaffected,"Unchanged model remains in memory")
	check(await LeoAssets.scene_async(changed_file,self)!=null,"Changed GLB can be loaded again")
	DirAccess.remove_absolute(changed_file)
	var folder:=fixture.path_join("invalid");DirAccess.make_dir_recursive_absolute(folder)
	var data:=LeoVehicleCodec.serialize(base);data.model="../../escape.glb";write(folder.path_join("vehicle.json"),data)
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path(fixture))
	check(LeoVehicleLibrary.entries.is_empty() and LeoVehicleLibrary.unavailable.size()==1,"Malformed optional vehicle disabled")
	DirAccess.remove_absolute(folder.path_join("vehicle.json"));DirAccess.remove_absolute(folder)
	data=LeoVehicleCodec.serialize(base)
	for label in ["a","b"]:
		var duplicate:=fixture.path_join(label);DirAccess.make_dir_recursive_absolute(duplicate)
		FileAccess.open(duplicate.path_join("model.glb"),FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(base.model_path))
		write(duplicate.path_join("vehicle.json"),data)
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path(fixture))
	check(LeoVehicleLibrary.entries.is_empty() and LeoVehicleLibrary.unavailable.size()==2,"Duplicate identities disable both candidates")
	for label in ["a","b"]:
		var duplicate:=fixture.path_join(label)
		DirAccess.remove_absolute(duplicate.path_join("vehicle.json"));DirAccess.remove_absolute(duplicate.path_join("model.glb"));DirAccess.remove_absolute(duplicate)
	FileAccess.open(fixture.path_join("new.glb"),FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(base.model_path))
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path(fixture))
	check(LeoVehicleLibrary.pending.size()==1 and LeoVehicleLibrary.entries.is_empty(),"Standalone GLB is Needs Setup")
	DirAccess.remove_absolute(fixture.path_join("new.glb"))
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path(fixture))
	check(LeoVehicleLibrary.entries.is_empty(),"Empty roster is valid discovery state")
	LeoVehicleLibrary.discover();catalog=GarageCatalog.shared()
	var local:=LeoLocalPlayer.new(0);local.restore({"vehicle":"removed_mod"},catalog)
	check(local.vehicle_id==catalog.vehicles[0].id and local.selection().vehicle=="removed_mod","Missing selection falls back without erasing preference")
	data=LeoVehicleCodec.serialize(base);data.core.min="99.0.0"
	check(not LeoVehicleLibrary.problems(data,"",false).is_empty(),"Newer core rejected")
	data.core.min="2.2.0";data.wheels[0].axle=[0,0,0]
	check(not LeoVehicleLibrary.problems(data,"",false).is_empty(),"Invalid axle rejected")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"vehicles":2,"cache":true}
	DirAccess.make_dir_recursive_absolute("res://build/modularity")
	FileAccess.open("res://build/modularity/loose-vehicles.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LOOSE_VEHICLES_TEST ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
