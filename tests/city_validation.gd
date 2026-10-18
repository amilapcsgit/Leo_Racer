extends SceneTree

func _initialize() -> void:
	var track := LeoCircuit.new()
	var city := LeoCity.new()
	root.add_child(city)
	city.setup(track)
	assert(city.stats.buildings >= 45, "Expected a substantial layered city")
	assert(city.stats.skyline >= 15, "Expected distant skyline towers")
	assert(city.stats.minimum_road_clearance > 13.0, "A building intersects the road envelope")
	assert(city.stats.batches < 140, "City batching regressed")
	var signs := 0
	for child in city.get_children():
		if child is MeshInstance3D and child.mesh is TextMesh:
			assert(child.transform.basis.determinant() > .9, "Mirrored shop sign transform")
			signs += 1
		if child is MultiMeshInstance3D:
			var mesh: MultiMesh = child.multimesh
			for i in range(mesh.instance_count):
				assert(mesh.get_instance_transform(i).basis.determinant() > 0.0, "Reflected city mesh transform")
	assert(signs >= 30, "Expected visible shopfront signs")
	print("CITY_VALIDATION_PASS | ", JSON.stringify(city.stats))
	quit()
