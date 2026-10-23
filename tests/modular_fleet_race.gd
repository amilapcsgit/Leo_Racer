extends SceneTree
var game: Node3D
var batch := 0
var elapsed := 0.
var rows: Array=[]
var errors: Array[String]=[]
var advancing := false
func _initialize() -> void:run.call_deferred()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;await process_frame
	game.diagnostics_mode=true
	Engine.time_scale=6
	start_batch()
func start_batch() -> void:
	game.selected_kart=(batch*6)%16;game.selected_driver=batch%6;await game.start_race()
	for i in range(1,6):
		var old: LeoKart=game.karts[i];game.karts.remove_at(i);old.stop_audio();old.free()
		var v: VehicleDefinition=game.catalog.vehicles[(batch*6+i)%16]
		var d: DriverDefinition=game.catalog.drivers[(batch+i)%6]
		var kart:=LeoKart.new();game.add_child(kart);kart.setup(game.circuit,i,false,d.id,v.id)
		kart.racer_name=d.display_name;kart.place(-8.-(i/2)*5.5,-3.2 if i%2==0 else 3.2);kart.gate_crossed.connect(game.on_gate)
		game.karts.insert(i,kart)
	game.state="race";game.player.auto_drive=true
	for k in game.karts:k.active=true
	elapsed=0.;advancing=false
func _process(dt: float) -> bool:
	if not game or not game.player or advancing:return false
	elapsed+=dt
	if game.karts.all(func(k):return k.finished) or elapsed>330.:
		advancing=true;finish_batch.call_deferred()
	return false
func finish_batch() -> void:
	for k in game.karts:
		rows.append({"batch":batch,"vehicle":k.vehicle_key,"driver":String(k.visual.get_meta("driver_id")),"time":k.finish_time,"gate":k.next_gate,"lap":k.lap,"finished":k.finished})
		if not k.finished or k.next_gate!=25:errors.append(k.vehicle_key+" did not finish three ordered laps")
	print("MODULAR_FLEET_BATCH ",batch," elapsed=",elapsed)
	batch+=1
	if batch<3:start_batch();return
	var unique:={}
	for row in rows:unique[row.vehicle]=true
	if unique.size()!=16:errors.append("Not all 16 vehicles raced")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"models":unique.size(),"races":3,"racers_per_race":6,"vehicles":rows}
	FileAccess.open("res://docs/qa-bigster/fleet-race.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MODULAR_FLEET_REPORT ",report.status," models=",unique.size())
	Engine.time_scale=1;game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
