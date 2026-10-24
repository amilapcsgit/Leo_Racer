extends SceneTree
var game: Node3D
var samples: Array[float]=[]
var draws: Array[float]=[]
var physics: Array[float]=[]
var started:=0
var last:=0
var collecting:=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);root.content_scale_size=Vector2i.ZERO
 Engine.max_fps=120;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var baseline:=load("res://assets/catalog/runtime/catalog.tres") as GarageCatalog
 baseline.vehicles.assign(baseline.vehicles.filter(func(v):return v.id in [&"bigster",&"duster"]))
 game=load("res://scenes/main.tscn").instantiate();game.local_players[0].vehicle_id=&"bigster";root.add_child(game);await game.initialization_finished;await process_frame
 game.diagnostics_mode=true;game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.selected_driver=game.catalog.driver_index(&"mario");game.local_players[1].vehicle_id=&"duster"
 await game.start_race();game.state="race"
 for kart in game.karts:kart.active=true;kart.auto_drive=true
 await create_timer(6.,true,false,true).timeout
 started=Time.get_ticks_usec();last=started;collecting=true
 print("SPLIT_PROFILE_STARTED ",RenderingServer.get_current_rendering_method()," ",RenderingServer.get_video_adapter_name()," views=",game.split_view.views[0].size,"/",game.split_view.views[1].size)
func _process(_delta: float) -> bool:
 if not collecting:return false
 var now:=Time.get_ticks_usec();samples.append((now-last)/1000.);last=now
 draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
 if now-started>=45000000:collecting=false;finish.call_deferred()
 return false
func mean(values: Array[float]) -> float:
 var total:=0.
 for value in values:total+=value
 return total/maxi(1,values.size())
func percentile(values: Array[float],p: float) -> float:
 var sorted:=values.duplicate();sorted.sort();return sorted[clampi(int((sorted.size()-1)*p),0,sorted.size()-1)]
func finish() -> void:
 var renderer:=RenderingServer.get_current_rendering_method();var elapsed: float=(Time.get_ticks_usec()-started)/1000000.
 var report:={"status":"MEASURED","renderer":renderer,"gpu":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"left":str(game.split_view.views[0].size),"right":str(game.split_view.views[1].size),"six_racers":game.karts.size(),"humans":game.human_count,"seconds":elapsed,"fps":samples.size()/elapsed,"p50_ms":percentile(samples,.5),"p95_ms":percentile(samples,.95),"p99_ms":percentile(samples,.99),"draw_calls":mean(draws),"physics_ms":mean(physics),"progress_m":[game.karts[0].progress,game.karts[1].progress],"target_fps":60,"target_met":samples.size()/elapsed>=60.,"root_3d_camera":str(root.get_camera_3d())}
 DirAccess.make_dir_recursive_absolute("res://build/modularity");FileAccess.open("res://build/modularity/baseline-%s.json" % renderer,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("SPLIT_RENDER_PROFILE ",report)
 game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit()
