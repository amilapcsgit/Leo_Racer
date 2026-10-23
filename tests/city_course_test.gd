extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var definitions:=LeoTrackDefinition.discover();var city: LeoTrackDefinition
	for track in definitions:
		if track.id=="colombo_city":city=track
	check(city!=null and not city.modified,"Expanded course has official revision/hash")
	var route:=LeoCircuit.new(city)
	check(absf(route.length-5500.)<1.,"Road Generator course is 5.5 km")
	check(city.metadata.authoring.version=="0.9.5" and int(city.metadata.authoring.road_points)==22,"Pinned editable Road Generator graph")
	var scene: Node3D=load(city.metadata.scene).instantiate();root.add_child(scene)
	var meshes:=scene.find_children("Asphalt_*","MeshInstance3D",true,false)
	check(meshes.size()>=27,"Road rendering has spatial culling sections")
	var normals_correct:=true
	for node in meshes:
		var mesh: Mesh=node.mesh
		var normals: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		if normals.is_empty() or normals[0].y<.99:normals_correct=false
	check(normals_correct,"Baked asphalt normals face upward for rendering and collision")
	check(scene.find_children("*","StaticBody3D",true,false).size()>=80,"Full road and both continuous barriers have resident collision")
	var script_free:=true
	for child in scene.find_children("*","Node",true,false):
		if child.get_script():script_free=false
	check(script_free,"Baked race geometry has no Road Generator runtime dependency")
	scene.queue_free();await process_frame
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	check(await game.select_track("colombo_city"),"Expanded track loads through shared selector")
	game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
	await game.start_race();game.state="race"
	for kart in game.karts:kart.active=true;kart.auto_drive=true
	for i in 180:await physics_frame
	check(game.karts.all(func(k):return k.progress>20. and k.next_gate>0 and k.position.is_finite()),"Six racers drive across start and road section boundaries")
	var before: int=game.karts[0].next_gate
	game.karts[0].recover();game.karts[1].recover();await physics_frame
	check(game.karts[0].next_gate==before and game.karts[0].position.distance_to(game.karts[1].position)>3.,"SUV recovery preserves checkpoint order and separates players")
	check(game.split_view.overlays[0].map_points.size()==route.points.size(),"Split-screen minimap follows selected course")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open("res://docs/qa-colombo-city/road-driving.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CITY_COURSE_TEST ",report)
	game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
