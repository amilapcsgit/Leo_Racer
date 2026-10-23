extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func row(id: String,name: String,time: float,lap: float,v: String="duster") -> Dictionary:
 return {"finished":true,"retired":false,"next_gate":25,"race_time":time,"best_lap":lap,"profile_id":id,"name":name,"driver":"mario","vehicle":v,"class_id":"suv180" if v=="bigster" else "standard165","place":1}
func run() -> void:
 var path:=ProjectSettings.globalize_path("user://test-rankings-%d.sqlite3" % Time.get_ticks_usec())
 var store=load("res://scripts/LocalRankingStore.cs").new()
 check(store.open_store(path),"SQLite opens with bundled native support")
 var rows: Array=[row("a","Asha",300,90),row("b","Bimal",290,95)]
 check(store.save_session("s1",2,rows,false,false)==2,"Both named results commit atomically")
 check(store.save_session("s1",2,rows,false,false)==0,"Session retry cannot duplicate results")
 check(store.best_times(2,"standard165","",false)[0].name=="Bimal","Race-time ascending ordering")
 check(store.best_times(2,"standard165","",true)[0].name=="Asha","Lap-time independent ordering")
 check(store.best_times(1,"standard165","",false).is_empty(),"Single and multiplayer records separated")
 check(store.best_times(2,"suv180","",false).is_empty(),"Performance classes separated")
 check(store.save_session("s2",1,[row("a","Asha",250,80,"bigster")],false,false)==1,"Bigster result stored")
 check(store.best_times(1,"suv180","bigster",false).size()==1 and store.best_times(1,"suv180","duster",false).is_empty(),"Vehicle and class filters")
 var dnf:=row("c","DNF",100,30);dnf.finished=false;dnf.retired=true
 check(store.save_session("dnf",2,[dnf],false,false)==0,"DNF excluded")
 check(store.save_session("modified",2,rows,true,false)==0 and store.save_session("diagnostic",2,rows,false,true)==0,"Modified and diagnostic records excluded")
 var bad: Array=[row("c","Rollback",200,60),{"finished":true}]
 check(store.save_session("rollback",2,bad,false,false)==-1 and store.best_times(2,"standard165","",false).size()==2,"Failed transaction rolls back all rows")
 store.close_store();check(store.open_store(path) and store.best_times(2,"standard165","",false).size()==2,"Ranking persistence after reopening")
 store.close_store();check(store.save_session("closed",2,rows,false,false)==-1,"Unavailable database fails without stopping game")
 var corrupt:=path+".corrupt";var file:=FileAccess.open(corrupt,FileAccess.WRITE);file.store_string("KEEP EXISTING DATA");file.close()
 check(not store.open_store(corrupt) and FileAccess.get_file_as_string(corrupt)=="KEEP EXISTING DATA","Corrupt database preserved")
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;await process_frame;game.diagnostics_mode=true
 check(game.format_time(320.2)=="05:20.200","Ranking timestamps round to exact milliseconds")
 game.human_count=2;await game.start_race()
 for kart in game.karts:
  var bigster: bool=kart.vehicle_key=="bigster"
  check(is_equal_approx(kart.max_speed,50. if bigster else 165./3.6) and is_equal_approx(kart.boosted_ceiling(),62.5 if bigster else 55.) and kart.acceleration==18. and kart.handling==1.,"Resolved human/AI performance "+kart.vehicle_key)
 check(game.ranking_rows().size()==2 and game.ranking_rows()[0].driver==String(game.player.visual.get_meta("driver_id")),"Main session rows resolve selected driver identity")
 check(game.ranking_store==null,"Diagnostic scene cannot open personal database")
 game.save_ranking_results();check(game.rankings_written and game.ranking_message.begins_with("DIAGNOSTIC"),"Main race excludes diagnostic writes")
 game.hud.show_rankings();await process_frame;check(game.hud.modal_root.get_child_count()==1,"Rankings screen handles unavailable database")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
 FileAccess.open("res://build/qa-ui/rankings.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOCAL_RANKING_TEST ",report)
 game.return_menu();game.stop_all_audio();game.queue_free();store.close_store()
 for suffix in ["","-shm","-wal",".corrupt"]:DirAccess.remove_absolute(path+suffix)
 await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)

