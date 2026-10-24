extends SceneTree
## One-time migration, reading original definitions without loading their models.
func _initialize() -> void:
	var catalog:=load("res://assets/catalog/runtime/catalog.tres") as GarageCatalog
	var sources: Dictionary={}
	for vehicle in catalog.vehicles:
		var folder:="res://content/vehicles/"+String(vehicle.id)
		DirAccess.make_dir_recursive_absolute(folder)
		var data:=LeoVehicleCodec.serialize(vehicle)
		FileAccess.open(folder.path_join("vehicle.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
		sources[String(vehicle.id)]={"model":vehicle.model_path,"thumbnail":vehicle.thumbnail.resource_path if vehicle.thumbnail else "","fixed_driver_model":vehicle.fixed_driver_model_path}
	DirAccess.make_dir_recursive_absolute("res://content")
	FileAccess.open("res://content/vehicle-sources.json",FileAccess.WRITE).store_string(JSON.stringify(sources,"  ")+"\n")
	print("VEHICLE_METADATA_MIGRATED ",sources.size());quit()
