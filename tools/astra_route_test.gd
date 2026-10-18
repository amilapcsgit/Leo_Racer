extends SceneTree
## Focused Astra layout/presentation contract. Does not replace the full race test.
var checks := 0
var errors: Array[String] = []
var measurements: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func verify(ok: bool,message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
	print(("PASS " if ok else "FAIL ")+message)
func _cross(a: Vector3,b: Vector3,c: Vector3) -> float:
	return (b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
func _point_segment_distance(p: Vector3,a: Vector3,b: Vector3) -> float:
	var ab := b-a
	return p.distance_to(a+ab*clampf((p-a).dot(ab)/ab.length_squared(),0,1))
func _route_geometry(c: LeoCircuit) -> void:
	verify(c.length>=1600 and c.length<=2000,"Astra lap is 1.6–2.0km")
	verify(c.points.size()>=800,"Circuit has dense ~2m equal-distance samples")
	verify(c.sample(0).distance_to(Vector3(-90,0,78))<.001,"Original grid start is preserved")
	verify(c.direction(0).dot(Vector3.FORWARD)>.999,"Start and finish face north")
	verify(c.sample(c.length).distance_to(c.sample(0))<.001,"Closed circuit seam is continuous")
	verify(c.sample(-2).distance_to(c.sample(c.length-2))<.001,"Negative distance wraps across the start")
	verify(c.direction(c.length-.02).dot(c.direction(.02))>.999,"Seam tangent does not snap")
	var min_radius := INF
	var min_spacing := INF
	var max_spacing := 0.0
	var max_height := 0.0
	for i in range(c.points.size()):
		var a := c.points[posmod(i-1,c.points.size())]
		var b := c.points[i]
		var d := c.points[(i+1)%c.points.size()]
		var area2 := absf(_cross(a,b,d))
		if area2>.00001:min_radius=minf(min_radius,a.distance_to(b)*b.distance_to(d)*a.distance_to(d)/(2*area2))
		var spacing := b.distance_to(d)
		min_spacing=minf(min_spacing,spacing)
		max_spacing=maxf(max_spacing,spacing)
		max_height=maxf(max_height,absf(b.y))
	verify(min_radius>=15,"Every driving bend keeps at least 15m radius")
	verify(min_spacing>1.9 and max_spacing<2.1,"Sampling remains evenly spaced through corners and seam")
	verify(max_height<.0001,"Race surface remains flat; hills do not alter simulation")
	var min_clearance := INF
	var crossings := 0
	var skip := ceili(80.0/c.step)
	for i in range(c.points.size()):
		var a := c.points[i]
		var b := c.points[(i+1)%c.points.size()]
		for j in range(i+skip,c.points.size()):
			if mini(j-i,c.points.size()-(j-i))<skip:continue
			var d := c.points[j]
			var e := c.points[(j+1)%c.points.size()]
			if _cross(a,b,d)*_cross(a,b,e)<0 and _cross(d,e,a)*_cross(d,e,b)<0:crossings+=1
			min_clearance=minf(min_clearance,minf(minf(_point_segment_distance(a,d,e),_point_segment_distance(b,d,e)),minf(_point_segment_distance(d,a,b),_point_segment_distance(e,a,b))))
	verify(crossings==0,"Exhaustive nonlocal segment test finds no self-crossings")
	verify(min_clearance>=45,"Separate circuit arms keep at least 45m center clearance")
	var lane_error := 0.0
	var projection_distance_error := 0.0
	for i in range(0,c.points.size(),23):
		var s := float(i)*c.step
		for lane in [-8.0,0.0,8.0]:
			var p := c.sample(s,lane)
			var projection := c.project(p)
			lane_error=maxf(lane_error,absf(projection.offset-lane))
			projection_distance_error=maxf(projection_distance_error,absf(c.delta_distance(s,projection.distance)))
	verify(lane_error<.2,"Lane projection stays accurate on the entire new route")
	verify(projection_distance_error<2.1,"Projection does not jump between circuit arms")
	verify(c.boosts.size()==8,"Eight strategically spaced boost pads are installed")
	var valid_boosts := true
	for i in range(c.boosts.size()):
		valid_boosts=valid_boosts and float(c.boosts[i])>0 and float(c.boosts[i])<1
		if i>0:valid_boosts=valid_boosts and float(c.boosts[i])-float(c.boosts[i-1])>.06
	verify(valid_boosts,"Boost pads are unique, ordered and separated by more than 6% of lap")
	measurements.merge({"lap_m":c.length,"samples":c.points.size(),"min_radius_m":min_radius,"sample_min_m":min_spacing,"sample_max_m":max_spacing,"nonlocal_segment_clearance_m":min_clearance,"crossings":crossings,"max_lane_error_m":lane_error,"max_projection_distance_error_m":projection_distance_error})
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var c: LeoCircuit=game.circuit
	_route_geometry(c)
	var astra := game.world.find_child("AstraLotusCoast",true,false) as LeoAstraWorld
	verify(astra!=null,"New Astra presentation world is active")
	if astra:
		var road := astra.get_node("AstraContinuousAsphalt") as MeshInstance3D
		var ground := astra.get_node("SculptedAstraCoastAndGardenHills") as MeshInstance3D
		var ocean := astra.get_node("IndianOcean") as MeshInstance3D
		var lagoon := astra.get_node("LotusLagoon") as MeshInstance3D
		var arrays: Array=ground.mesh.surface_get_arrays(0)
		var min_y := INF
		var max_y := -INF
		var upright := true
		for p in arrays[Mesh.ARRAY_VERTEX]:
			min_y=minf(min_y,p.y)
			max_y=maxf(max_y,p.y)
		for normal in arrays[Mesh.ARRAY_NORMAL]:upright=upright and normal.y>0
		verify(min_y<-2.5 and max_y>8,"Terrain includes sunken coast/lagoon and visible raised hills")
		verify(upright,"Sculpted terrain normals face the sky")
		var road_upright := true
		var road_min := INF
		for normal in road.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:road_upright=road_upright and normal.y>.99
		for p in road.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:road_min=minf(road_min,p.y)
		verify(road_upright,"Continuous asphalt normals face upward around the full circuit")
		verify(ocean.position.y<road_min-.4,"Ocean surface is visibly below the raised road")
		var lagoon_y: float=lagoon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0].y
		verify(lagoon_y<road_min-.4,"Lagoon water stays below causeway deck")
		verify(ocean.mesh.get_aabb().size.x>1500,"Ocean extends beyond the skyline")
		verify(lagoon.mesh.get_aabb().size.x>=169 and lagoon.mesh.get_aabb().size.z>=249,"Lagoon has meaningful 170×250m visible water area")
		var bridge_decks := 0
		for batch in astra.static_batches.values():
			if batch.mesh.size.is_equal_approx(Vector3(23,.65,4.2)):bridge_decks+=batch.items.size()
		verify(bridge_decks>10 and astra.static_batches.size()<450,"Causeway decks exist and decoration stays within spatial batch budget")
		verify(astra.transport_count==0,"No legacy parked bus or tuk-tuk props remain hidden beside the track")
		verify(astra.national_flags>=30,"Sri Lanka flags remain visible around the longer circuit")
		verify(astra.advertising_faces>=100,"Populated advertisements cover the expanded circuit")
		var all_bright := true
		var art: Dictionary={}
		for face in get_nodes_in_group("sri_advertising"):
			var material: StandardMaterial3D=face.material_override
			all_bright=all_bright and material.emission_enabled and material.emission_energy_multiplier>=1.0 and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED
			art[material.albedo_texture.resource_path]=true
		verify(all_bright,"Billboards emit HDR light and cannot fade under sunset shadows")
		verify(art.size()==8,"All eight festival artwork designs remain in use")
		verify(astra._advert_border!=null and astra._advert_border.emission_energy_multiplier>2,"Advertising faces have luminous neon border material")
		measurements.merge({"terrain_min_y_m":min_y,"terrain_max_y_m":max_y,"road_y_m":road_min,"ocean_y_m":ocean.position.y,"lagoon_y_m":lagoon_y,"advert_faces":astra.advertising_faces,"national_flags":astra.national_flags,"foliage_instances_with_lods":astra.count,"static_spatial_batches":astra.static_batches.size()})
	verify(game.art_profile.landmark_position.z<-400,"Authentic Lotus Tower frames the new northern coast view")
	verify(game.world.find_child("AuthenticLotusTower",true,false)!=null,"Authentic supplied Lotus Tower remains active")
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"measurements":measurements}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa-astra"))
	FileAccess.open("res://docs/qa-astra/route-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ASTRA_ROUTE_REPORT ",JSON.stringify(report))
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
