extends SceneTree
var roof:=-INF
func scan(node: Node3D, target: String, pose: Transform3D=Transform3D.IDENTITY) -> void:
	var transform:=pose*node.transform
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if not material or material.resource_name!=target:continue
			for vertex in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:roof=maxf(roof,(transform*vertex).y)
	for child in node.get_children():
		if child is Node3D:scan(child,target,transform)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	LeoAssets.configure(ProjectSettings.globalize_path("res://build/preview260/GameAssets"));LeoAssets.mount_packs()
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path("res://build/runtime260/GameAssets/vehicles"))
	var catalog:=GarageCatalog.shared();var rows: Array=[]
	for id in [&"duster",&"duster_2024"]:
		var car:=LeoVehiclePresentation.resolve(catalog.vehicle(id))
		for racer in catalog.drivers:
			var assembly:=VehicleAssembler.assemble(car,racer);root.add_child(assembly)
			roof=-INF;scan(assembly.get_node("Chassis"),"CarPaint_Body_Terracotta" if id==&"duster_2024" else "CarPaint_Duster_My_2014_Bianco_Ghiaccio")
			var driver:=assembly.get_node("Driver") as Node3D
			var box:=LeoVehiclePresentation.bounds(driver)
			var top:=box.position.y+box.size.y
			var ratio:=minf(1.,(roof-.035-driver.position.y)/maxf(.001,top-driver.position.y))
			rows.append({"vehicle":String(id),"driver":String(racer.id),"roof_y":roof,"head_y":top,"origin_y":driver.position.y,"scale_ratio":ratio})
			assembly.free()
	FileAccess.open("res://build/qa260/driver-fits.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("DRIVER_FITS260 ",JSON.stringify(rows));quit()

