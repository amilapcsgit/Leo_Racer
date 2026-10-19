extends SceneTree
func _initialize() -> void:
	var catalog:=GarageCatalog.shared()
	var errors:=catalog.problems()
	for v in catalog.vehicles:
		var model:=v.model.instantiate() as Node3D
		for w in v.wheels:
			for path in w.rotating_groups+w.stationary_groups:
				if not VehicleAssembler.find_group(model,path):errors.append(String(v.id)+": unresolved "+String(path))
		model.free()
	for error in errors:push_error(error)
	print("PLAYABLE_CATALOG_VALIDATION ","PASS" if errors.is_empty() else "FAIL")
	quit(0 if errors.is_empty() else 1)
