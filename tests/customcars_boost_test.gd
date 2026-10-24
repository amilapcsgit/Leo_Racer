extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true
	var original: VehicleDefinition=game.catalog.vehicle(&"duster")
	var stock:=original.boost_emitters().duplicate()
	var custom:=LeoVehicleCodec.deserialize(LeoVehicleCodec.serialize(original),original.model_path.get_base_dir())
	custom.model_path=original.model_path;custom.id=&"boost_probe";custom.official=false;custom.exhausts=PackedVector3Array()
	custom.collision_size=Vector3(2.529,2.281,6.13);custom.collision_position=Vector3(0,1.14,0)
	var emitted:=custom.boost_emitters()
	check(emitted.size()==2,"Imported car without exhaust receives two rear jets")
	check(emitted[0].z>3.065 and emitted[1].z>3.065,"Jets sit behind normalized vehicle bounds")
	check(emitted[0].x<0 and emitted[1].x>0,"Jets straddle vehicle center")
	check(custom.exhausts.is_empty(),"Fallback leaves authoritative definition untouched")
	game.catalog.vehicles.append(custom)
	var kart:=LeoKart.new();game.add_child(kart);kart.setup(game.circuit,0,false,"human",String(custom.id));kart.set_physics_process(false)
	game.catalog.vehicles.erase(custom)
	var camera:=Camera3D.new();game.add_child(camera);camera.position=kart.position+Vector3(0,3,6);camera.make_current()
	check(kart.flames.size()==2 and kart.exhaust_trails.size()==2 and kart.effects.ribbons.size()==2,"Actual game assembly creates flames and trails")
	kart.active=true;kart.boost_time=1.;kart.effects._process(.016)
	check(kart.effects.ribbons.all(func(p):return p.emitting),"Boost enables both trails")
	check((kart.flames[0].material_override as StandardMaterial3D).emission.b>.8,"Synthetic jets use blue electric presentation")
	kart.boost_time=0.;kart.effects._process(.016)
	check(kart.effects.ribbons.all(func(p):return not p.emitting),"Boost trails stop after boost")
	check(original.boost_emitters()==stock,"Official Duster emitter positions are unchanged")
	kart.queue_free();game.stop_all_audio();game.queue_free();await process_frame;await process_frame
	print("CUSTOMCARS_BOOST_TEST ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
