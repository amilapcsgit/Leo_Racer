extends Node3D
## Isolated arcade proving ground. Never creates a race session or ranking store.
var folder := ""
var kart: LeoKart
var router: LeoInputRouter
var camera: Camera3D
var info: Label
var paused := false
var probe := false
var ticks := 0

func configure(path: String) -> void:folder=ProjectSettings.globalize_path(path)

func _ready() -> void:
	DisplayServer.window_set_title("Leo Racer / Private Vehicle Test (unranked)")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("vehicle.json")))
	var errors:=LeoVehicleLibrary.problems(data,folder)
	if not errors.is_empty():failure("; ".join(errors));return
	var definition:=LeoVehicleCodec.deserialize(data,folder);definition.official=false
	var loaded:=await LeoAssets.scene_async(definition.model_path,get_tree())
	if not loaded:failure(LeoAssets.failure);return
	definition.model=loaded
	var track:=LeoTrackDefinition.new();var points: Array=[];var length:=0.
	for i in 128:
		var angle:=TAU*float(i)/128.;points.append([60.*cos(angle),0.,60.*sin(angle)])
	for i in points.size():length+=LeoVehicleCodec.vector(points[i]).distance_to(LeoVehicleCodec.vector(points[(i+1)%points.size()]))
	track.route={"points":points,"length":length,"width":18.}
	var circuit:=LeoCircuit.new(track)
	var floor_node:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(250,1,250);collision.shape=shape;collision.position.y=-.5;floor_node.add_child(collision);add_child(floor_node)
	var mesh_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(250,250);mesh_node.mesh=plane
	var grass:=StandardMaterial3D.new();grass.albedo_color=Color("536750");mesh_node.material_override=grass;add_child(mesh_node)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 128:
		var a:=circuit.sample(i*circuit.step,-9.);var b:=circuit.sample(i*circuit.step,9.);var c:=circuit.sample((i+1)*circuit.step,-9.);var d:=circuit.sample((i+1)*circuit.step,9.)
		for v in [a,c,b,b,c,d]:surface.set_normal(Vector3.UP);surface.add_vertex(v+Vector3.UP*.02)
	var road:=MeshInstance3D.new();road.mesh=surface.commit();var asphalt:=StandardMaterial3D.new();asphalt.albedo_color=Color("263944");asphalt.cull_mode=BaseMaterial3D.CULL_DISABLED;road.material_override=asphalt;add_child(road)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=1.3;add_child(light)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("90bbd2");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color("c8ddee");world.environment.ambient_light_energy=.7;add_child(world)
	router=LeoInputRouter.new();add_child(router);router.active_slots=1;router.gameplay_enabled=true
	if not router.ready_problem(0).is_empty():router.players[0]=LeoPlayerInput.new()
	router.command.connect(func(_slot,action):
		if action=="recover":kart.recover()
		if action=="pause_race":paused=not paused;kart.active=not paused;router.clear_all())
	router.device_lost.connect(func(_slot):paused=true;kart.active=false;router.clear_all();info.text="Controller disconnected. Close this test and reconnect before retrying. Escape closes.")
	kart=LeoKart.new();add_child(kart);kart.setup(circuit,0,true,"human",String(definition.id),definition)
	kart.control_input=router.players[0];kart.active=true;kart.place(0,0);LeoRaceRules.apply(kart)
	camera=Camera3D.new();camera.fov=68;add_child(camera);camera.make_current()
	var canvas:=CanvasLayer.new();add_child(canvas);var box:=VBoxContainer.new();box.position=Vector2(20,20);canvas.add_child(box)
	info=Label.new();info.add_theme_font_size_override("font_size",24);box.add_child(info)
	var back:=Button.new();back.text="Close test / Return to Workshop";back.pressed.connect(func():get_tree().quit());box.add_child(back)
	probe="--workshop-test-probe" in OS.get_cmdline_user_args()
	print("WORKSHOP_PRIVATE_TEST_READY ",String(definition.id)," unranked=true")

func failure(message: String) -> void:
	printerr("WORKSHOP_PRIVATE_TEST_FAILED ",message)
	var text:=Label.new();text.text=message+"\nEscape closes this test.";text.position=Vector2(25,25);add_child(text)
	if "--workshop-test-probe" in OS.get_cmdline_user_args():get_tree().quit(2)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:get_tree().quit();get_viewport().set_input_as_handled()

func _physics_process(_dt: float) -> void:
	if not is_instance_valid(kart):return
	if probe:
		ticks+=1;kart.control_input.inject_test("accelerate",1.)
		if ticks==40:kart.control_input.inject_test("boost",1.)
		if ticks==120:
			var ok:=kart.speed>10. and kart.wheel_spin_pivots.size()==4 and kart.flames.size()>0 and not kart.visual.has_node("Driver")
			print("WORKSHOP_PRIVATE_TEST ",JSON.stringify({"status":"PASS" if ok else "FAIL","speed":kart.speed,"wheels":kart.wheel_spin_pivots.size(),"jets":kart.flames.size(),"rankings_created":false}));get_tree().quit(0 if ok else 2)

func _process(dt: float) -> void:
	if not is_instance_valid(kart) or not camera:return
	var target:=kart.position+Vector3.UP*1.2
	camera.position=camera.position.lerp(target+kart.global_basis.z*maxf(8.,kart.definition.collision_size.z*1.5)+Vector3.UP*4.,1.-exp(-dt*8.));camera.look_at(target)
	if info and not paused:info.text="PRIVATE / UNRANKED · %03d km/h\nP1 controls · Shift boost · R recover · P pause · Escape closes"%int(absf(kart.speed)*3.6)

func _exit_tree() -> void:
	if is_instance_valid(kart):kart.stop_audio()
