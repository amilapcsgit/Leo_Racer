class_name LeoContentValidator
extends RefCounted
## Available in installed builds for contributor checks; no editor is required.
static func vehicles(tree: SceneTree) -> Dictionary:
	LeoVehicleLibrary.discover();var errors: Array=[];var rows: Array=[]
	for problem in LeoVehicleLibrary.unavailable:errors.append(problem.folder+": "+problem.reason)
	for vehicle in LeoVehicleLibrary.entries:
		var scene:=await LeoAssets.scene_async(vehicle.model_path,tree)
		if not scene:errors.append(String(vehicle.id)+": "+LeoAssets.failure);continue
		var node:=scene.instantiate() as Node3D;var compressed:=0
		for wheel in vehicle.wheels:
			for path in wheel.rotating_groups+wheel.stationary_groups:
				if not VehicleAssembler.find_group(node,path):errors.append(String(vehicle.id)+": missing wheel group "+String(path))
		for child in node.find_children("*","MeshInstance3D",true,false):
			for i in child.mesh.get_surface_count():
				var material: Material=child.get_active_material(i)
				if material is StandardMaterial3D and material.albedo_texture and material.albedo_texture.get_image().is_compressed():compressed+=1
		node.free()
		rows.append({"id":String(vehicle.id),"official":vehicle.official,"fingerprint":LeoVehicleLibrary.fingerprint_details.get(String(vehicle.id),{}),"wheels":vehicle.wheels.size(),"compressed_materials":compressed,"cache_hit":LeoVehicleImporter.last_report.get("cache_hit",false),"import_seconds":LeoVehicleImporter.last_report.get("seconds",0.)})
		await tree.process_frame
	if rows.is_empty():errors.append("No compatible vehicles are installed")
	return {"status":"PASS" if errors.is_empty() else "FAIL","vehicles":rows,"needs_setup":LeoVehicleLibrary.pending.map(func(path):return path.get_file()),"errors":errors,"vehicle_api":1,"core_version":"2.2.0"}
