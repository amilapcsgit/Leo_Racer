extends SceneTree
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	var track:=LeoTrackDefinition.new();track.metadata={"asset_api":3,"surface_profile":"arcade_elevation_v1"}
	var points: Array=[];var measured:=0.
	for i in 1024:
		var angle:=TAU*i/1024.;points.append([500.*cos(angle),4.*sin(angle*2.)+5.,500.*sin(angle)])
	for i in points.size():measured+=LeoVehicleCodec.vector(points[i]).distance_to(LeoVehicleCodec.vector(points[(i+1)%points.size()]))
	track.route={"length":measured,"points":points,"width":18.}
	check(LeoTrackDefinition.elevation_problem(track.route).is_empty(),"Smooth grade accepted")
	var bad: Dictionary=track.route.duplicate(true);bad.points[20][1]=100.
	check(not LeoTrackDefinition.elevation_problem(bad).is_empty(),"Steep ramp rejected")
	bad=track.route.duplicate(true);bad.width=13.
	check(not LeoTrackDefinition.elevation_problem(bad).is_empty(),"Narrow elevated road rejected")
	var circuit:=LeoCircuit.new(track)
	for distance in [0.,300.,900.,1800.,2800.]:
		var p:=circuit.sample(distance,3.)
		check(absf(circuit.project(p).offset-3.)<.03,"Projection retains lane on slopes")
		check(absf(circuit.frame_at(distance).determinant()-1.)<.001,"Orthonormal road frame")
		check(absf(circuit.sample(distance,-9.).distance_to(circuit.sample(distance,9.))-18.)<.001,"Full race width")
	var root_world:=Node3D.new();root.add_child(root_world)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a:=circuit.sample(circuit.step*i,-9.);var b:=circuit.sample(circuit.step*i,9.)
		var c:=circuit.sample(circuit.step*(i+1),-9.);var d:=circuit.sample(circuit.step*(i+1),9.)
		for v in [a,c,b,b,c,d]:surface.add_vertex(v)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=surface.commit().create_trimesh_shape();body.add_child(shape);root_world.add_child(body)
	LeoAssets.configure(ProjectSettings.globalize_path("res://build/Kandy-dev/GameAssets"));LeoAssets.mount_packs()
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path("res://build/Kandy-dev/GameAssets/vehicles"))
	var kart:=LeoKart.new();root_world.add_child(kart);kart.setup(circuit,0,false,"human","bigster");kart.active=true;kart.auto_drive=true;kart.place(0,0)
	Engine.time_scale=4.;Engine.max_physics_steps_per_frame=32
	var max_gap:=0.;var travelled:=0.
	for tick in 1800:
		await physics_frame
		max_gap=maxf(max_gap,absf(kart.position.y-circuit.sample(kart.last_s).y))
		travelled=maxf(travelled,kart.progress)
	check(travelled>800.,"Arcade AI climbs and descends")
	check(max_gap<.75,"Road contact across crest and sag")
	kart.next_gate=4;kart.recover()
	check(absf(kart.position.y-circuit.sample(kart.last_s).y)<.3,"Recovery respects road height")
	check(kart.basis.y.dot(Vector3.UP)>.99,"Gentle alignment remains stable")
	kart.is_player=true;kart.auto_drive=false;kart.control_input=LeoPlayerInput.new()
	kart.speed=12.;kart.control_input.inject_test("brake",1.)
	for tick in 150:await physics_frame
	check(kart.speed<-.5 and kart.wheel_motion_speed<-.5,"Braking transitions to reverse on grade")
	check(kart.vehicle_lighting!=null and kart.vehicle_lighting.headlights.size()==2,"Headlights survive surface alignment")
	kart.control_input.inject_test("brake",0.);kart.boost(2.,"TEST");await process_frame;await process_frame
	check(kart.flames.size()==2 and kart.flames[0].visible,"Boost emitters follow aligned chassis")
	Engine.time_scale=1.;kart.stop_audio();root_world.free()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"travelled":travelled,"max_height_gap":max_gap,"length":measured}
	FileAccess.open("res://build/kandy/elevation-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ELEVATION_TEST ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
