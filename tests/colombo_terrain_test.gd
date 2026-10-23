extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var terrain=load("res://tools/city_terrain_author.gd").new()
	var definition:LeoTrackDefinition
	for track in LeoTrackDefinition.discover():
		if track.id=="colombo_city":definition=track
	var circuit:=LeoCircuit.new(definition)
	var checked:=0
	for i in circuit.points.size():
		var s:float=circuit.length*float(i)/circuit.points.size()
		for offset in [-circuit.width_at(s)*.79,0.,circuit.width_at(s)*.79]:
			var p:=circuit.sample(s,offset)
			assert(absf(terrain.height_at(p.x,p.z))<.001,"Decorative terrain deformed road/pavement")
			checked+=1
	assert(terrain.height_at(-900,0)<-.42 and terrain.height_at(300,25)<-.17)
	# Every tile samples common world coordinates, including edge normals.
	var a:ArrayMesh=terrain.tile(-940,-1400,200,200)
	var b:ArrayMesh=terrain.tile(-740,-1400,200,200)
	var av:PackedVector3Array=a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bv:PackedVector3Array=b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var an:PackedVector3Array=a.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var bn:PackedVector3Array=b.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=a.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	assert((av[indices[1]]-av[indices[0]]).cross(av[indices[2]]-av[indices[0]]).y<0.,"Terrain must face the driving cameras")
	for z in 41:
		assert(av[z*41+40].is_equal_approx(bv[z*41]))
		assert(an[z*41+40].is_equal_approx(bn[z*41]))
	print("COLOMBO_TERRAIN_PASS protected_samples=",checked," shared_tile_edges=41");quit()
