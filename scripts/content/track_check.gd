extends Node
## Opt-in offline diagnostics for testing independently installed track packs.
var game: Node3D
var mode:="split"
var output:=""
var errors: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func save_report(name: String,data: Dictionary) -> void:
 var file:=FileAccess.open(output.path_join(name+".json"),FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(data,"  "))
func run() -> void:
 output=OS.get_user_data_dir().path_join("track-check")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--track-check="):mode=arg.trim_prefix("--track-check=")
  if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(output)
 game.diagnostics_mode=true;game.human_count=1 if mode=="single" else 2
 game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
 var start:=Time.get_ticks_msec();await game.start_race();var load_ms:=Time.get_ticks_msec()-start
 game.state="race"
 check(game.karts.size()==6,"Six racers assembled")
 for kart in game.karts:kart.active=true;kart.auto_drive=true
 if mode=="performance":await performance(load_ms)
 else:await race()
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","mode":mode,"checks":checks,"errors":errors,"track":game.track_definition.id,"revision":game.track_definition.revision,"length_m":game.circuit.length,"vehicle_load_ms":load_ms,"unranked":game.race_modified,"renderer":RenderingServer.get_current_rendering_method()}
 save_report(mode+"-"+game.track_definition.id,report);print("OFFLINE_TRACK_CHECK ",JSON.stringify(report))
 await game.quit_game(0 if errors.is_empty() else 2)
func race() -> void:
 Engine.time_scale=8.;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=64
 var deadline:=Time.get_ticks_msec()+120000;var independent:=false
 while game.state!="results" and Time.get_ticks_msec()<deadline:
  await get_tree().physics_frame
  if game.human_count==2 and game.karts[0].finished!=game.karts[1].finished:
   independent=true;check(game.state=="race","First human finish leaves other racing")
 Engine.time_scale=1.;Engine.physics_ticks_per_second=60
 check(game.state=="results","Three-lap race completed")
 for slot in game.human_count:check(game.karts[slot].finished and game.karts[slot].next_gate==25,"Human completed all checkpoints")
 if game.human_count==2:check(independent,"Independent finish observed")
 var racers: Array=[]
 for kart in game.karts:racers.append({"name":kart.racer_name,"finished":kart.finished,"gate":kart.next_gate,"seconds":kart.finish_time})
 save_report("racers-"+mode+"-"+game.track_definition.id,{"racers":racers})
func performance(load_ms: int) -> void:
 var root:=get_tree().root;root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i.ZERO;DisplayServer.window_set_size(root.size)
 Engine.max_fps=120;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 game.karts[1].place(game.circuit.length*.5,3.)
 await get_tree().create_timer(6.,true,false,true).timeout
 var frames: Array[float]=[];var static_memory: Array[float]=[];var vram: Array[float]=[]
 var start:=Time.get_ticks_usec();var last:=start
 while Time.get_ticks_usec()-start<30000000:
  await get_tree().process_frame
  var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now
  static_memory.append(Performance.get_monitor(Performance.MEMORY_STATIC));vram.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
 var elapsed:float=(Time.get_ticks_usec()-start)/1000000.
 frames.sort();static_memory.sort();vram.sort()
 var result:={"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1920,1080],"humans":2,"racers":game.karts.size(),"fps":frames.size()/elapsed,"p50_ms":frames[int(frames.size()*.5)],"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"max_frame_ms":frames[-1],"static_peak_mb":static_memory[-1]/1e6,"vram_peak_mb":vram[-1]/1e6,"vehicle_load_ms":load_ms,"separated_players":true}
 save_report("performance-"+RenderingServer.get_current_rendering_method(),result);print("OFFLINE_TRACK_PERFORMANCE ",JSON.stringify(result))
