extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var path:="res://build/qa260/worker-records.sqlite3"
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(path+"-wal");DirAccess.remove_absolute(path+"-shm")
	var store=load("res://scripts/LocalRankingStore.cs").new()
	check(store.open_store(ProjectSettings.globalize_path(path)),"Worker opens SQLite")
	var row:={"finished":true,"retired":false,"next_gate":25,"race_time":140.,"best_lap":45.,"profile_id":"fixture","name":"Original snapshot","driver":"human","vehicle":"duster","class_id":"arcade_v2","place":1}
	var request: int=store.write_async("immutable",1,[row],false,false,"astra_coast",1,"distinct_v5_static")
	row.name="Changed after enqueue";row.race_time=1.
	while not store.request_ready(request):await process_frame
	check(store.take_write(request)==1,"Worker saves immutable result")
	request=store.query_async(1,"arcade_v2","",false,"astra_coast",1,"distinct_v5_static")
	while not store.request_ready(request):await process_frame
	var rows: Array=store.take_query(request)
	check(rows.size()==1 and rows[0].name=="Original snapshot" and rows[0].race_ms==140000,"Mutable Godot values never cross the worker boundary")
	for ruleset in ["distinct_v4","distinct_v5_dusk_night"]:
		request=store.query_async(1,"arcade_v2","",false,"astra_coast",1,ruleset)
		while not store.request_ready(request):await process_frame
		check(store.take_query(request).is_empty(),"Separate records / "+ruleset)
	for i in 25:
		request=store.query_async(1,"arcade_v2","",false,"astra_coast",1,"distinct_v5_static");store.cancel_request(request)
	row.profile_id="flushed";row.name="Shutdown flush";row.race_time=150.
	store.write_async("flush",1,[row],false,false,"astra_coast",1,"distinct_v5_static")
	store.close_store();store=null
	store=load("res://scripts/LocalRankingStore.cs").new();store.open_store(ProjectSettings.globalize_path(path))
	request=store.query_async(1,"arcade_v2","",false,"astra_coast",1,"distinct_v5_static")
	while not store.request_ready(request):await process_frame
	rows=store.take_query(request)
	check(rows.size()==2,"Orderly shutdown flushes queued writes")
	store.close_store();store=null
	var result:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open("res://build/qa260/worker.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WORKER260 ",JSON.stringify(result));quit(0 if errors.is_empty() else 2)
