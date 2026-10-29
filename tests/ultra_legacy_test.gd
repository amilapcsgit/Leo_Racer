extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-fixture="):path=argument.trim_prefix("--legacy-fixture=")
	var store=load("res://scripts/LocalRankingStore.cs").new()
	var errors: Array[String]=[]
	if not store.open_store(path):errors.append("Legacy database opens: "+store.get_error())
	else:
		var rows: Array=store.best_times_for_track(1,"arcade_v2","",false,"astra_coast",1,"distinct_v5_static",3)
		if rows.is_empty() or rows[0].name!="LEGACY CHAMPION" or rows[0].race_ms!=123456:errors.append("Legacy values and three-lap interpretation preserved")
		if "--after-old-write" in OS.get_cmdline_user_args() and rows.size()!=2:errors.append("New session written by 2.6 is backfilled as three laps")
		if not store.best_times_for_track(1,"arcade_v2","",false,"astra_coast",1,"distinct_v5_static",1).is_empty():errors.append("Legacy race does not enter one-lap board")
		var row:={"finished":true,"retired":false,"next_gate":9,"race_time":80.,"best_lap":80.,"profile_id":"new","name":"ULTRA RACER","driver":"human","vehicle":"bigster","class_id":"arcade_v2","place":1}
		if store.save_session_for_track("ultra-new",1,[row],false,false,"astra_coast",1,"ultra_v6_static",1)<0:errors.append("New ruleset and lap count coexist")
	store.close_store()
	print("ULTRA_LEGACY_TEST ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors}))
	quit(0 if errors.is_empty() else 1)
