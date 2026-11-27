extends SceneTree
## Retained release entrypoint; now checks usable rows rather than leader routing.
var output: String
var checks:=0
var errors: Array[String]=[]
class ComparisonGame extends Node3D:
 var race_modified:=false
 var session_id:="comparable"
 func format_time(seconds: float) -> String:return "%.3f"%seconds
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:errors.append(message);push_error(message)
func settle() -> void:
 for i in 6:await process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func check_panel(panel: LeoControlMapPanel) -> void:
 var scale_factor: float=panel.get_global_transform_with_canvas().get_scale().y
 check(panel.callouts.size()==6,"Six graphical device callouts")
 check(panel.device_texture!=null,"Selected device uses a real PNG illustration")
 check(LeoControlMapPanel.PLATE_COLOR.a<=.4,"Image remains visible behind translucent tile")
 check(panel.heading.get_theme_font_size("font_size")*scale_factor>=23.99,"Player/device heading renders at least 24px")
 check(panel.secondary.get_theme_font_size("font_size")*scale_factor>=12.99,"Secondary controls remain legible at 13px")
 check(Rect2(Vector2.ZERO,panel.size).encloses(panel.secondary.get_rect()),"Secondary rows remain inside the panel")
 for i in panel.callouts.size():
  var row: Dictionary=panel.callouts[i]
  check(row.action==LeoControlMapPanel.ACTIONS[i],"Stable driving-action reading order")
  check(Rect2(Vector2.ZERO,panel.size).encloses(row.rect),"Driving row remains inside its panel")
  check(row.rect.size.y*scale_factor>=35.99,"Driving rows render at least 36px high")
  for node in [row.title,row.binding]:
   var fs: int=node.get_theme_font_size("font_size")
   check(fs*scale_factor>=(19.99 if node==row.title else 17.99),"Driving text renders at least 20px")
   check(node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x<=node.size.x+.1,"Complete binding/action text fits without truncation: "+node.text)
  check(not row.title.get_rect().intersects(row.binding.get_rect()),"One unambiguous binding/action pair")
  check(row.binding.text==panel.binding_text(row.action),"Driving row follows this player's live binding")
func run() -> void:
 output=ProjectSettings.globalize_path("res://build/qa279/loading")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(output)
 var screen:=LeoLoadingScreen.new();root.add_child(screen);screen.stage("Startup",10)
 check(not screen.diagram.visible,"Startup does not show race-only controls")
 screen.begin_load("track-test","astra_coast");screen.stage("Track change",20)
 check(not screen.diagram.visible,"Track change does not show race-only controls")
 screen.begin_load("race-test","astra_coast","","race");screen.stage("Loading track…",72)
 check(screen.diagram.visible,"Race loading shows active controls")
 check(screen.spinner.text.is_empty(),"Loading does not show misleading confirm/back prompts")
 check(screen.bar.size.y<=7.,"Progress bar stays slim")
 for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160)]:
  root.size=extent
  var cases: Array=[["keyboard"],["gamepad"],["wheel"]]
  for first in ["keyboard","gamepad","wheel"]:
   for second in ["keyboard","gamepad","wheel"]:cases.append([first,second])
  for types in cases:
   var router: LeoInputRouter=screen.diagram.fallback;router.active_slots=types.size()
   for slot in types.size():
    router.players[slot].switch_kind(types[slot]);router.players[slot].reset_defaults(types[slot]);router.players[slot].device=11+slot if types[slot]!="keyboard" else -1
    if types[slot]=="wheel":
     router.players[slot].set_axis("accelerate",JOY_AXIS_TRIGGER_RIGHT,0.,1.)
     router.players[slot].set_axis("brake",JOY_AXIS_TRIGGER_LEFT,0.,1.)
   if types==["keyboard","keyboard"]:router.configure_keyboards(2)
   if types==["gamepad","gamepad"]:router.players[1].bindings.change_camera=[{"type":"button","index":JOY_BUTTON_LEFT_SHOULDER}]
   await settle()
   var title: String="-".join(types)
   check(screen.diagram.panels.size()==types.size(),"Exactly one control list per player")
   for slot in types.size():
    var panel: LeoControlMapPanel=screen.diagram.panels[slot]
    check(panel.kind==("controller" if types[slot]=="gamepad" else types[slot]),"Rows follow assigned device")
    check_panel(panel)
   if types.size()==2:check(not screen.diagram.panels[0].get_global_rect().intersects(screen.diagram.panels[1].get_global_rect()),"Player control lists do not overlap")
   await capture("loading-%s-%dx%d"%[title,extent.x,extent.y])
 var router: LeoInputRouter=screen.diagram.fallback;router.active_slots=1
 var player: LeoPlayerInput=router.players[0];player.reset_defaults("keyboard");player.bindings.accelerate=[{"type":"key","index":KEY_F}]
 await settle()
 var panel: LeoControlMapPanel=screen.diagram.panels[0]
 check(panel.callouts[0].binding.text=="F","Remapped accelerator displays F")
 await capture("loading-accelerator-remapped-F")
 player.bindings.accelerate=[];await settle()
 check(screen.diagram.panels[0].callouts[0].binding.text=="Not assigned","Unbound accelerator displays explicit status")
 player.reset_defaults("gamepad");player.set_axis("left",JOY_AXIS_RIGHT_X,0.,-1.);await settle()
 check(screen.diagram.panels[0].callouts[2].binding.text=="RS ←","Steering remap identifies the actual right stick")
 player.reset_defaults("wheel");player.set_axis("accelerate",8,-1.,1.);await settle()
 check(screen.diagram.panels[0].callouts[0].binding.text=="Axis 8 +","Wheel pedal row identifies its actual calibrated axis")
 screen.hide();screen.stage("General stage",50)
 check(not screen.diagram.visible,"Completed race load clears race-only controls")
 var calls:=[0];screen.show_failure("Test content failure",func():calls[0]+=1,func():calls[0]+=10)
 check(screen.retry.has_focus(),"Loading failure focuses retry")
 var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=true;screen._input(event)
 check(calls[0]==10,"Controller B leaves loading failure")
 var comparison_game:=ComparisonGame.new();var front:=LeoFrontend.new();front.game=comparison_game
 front.result_reference_session="comparable";front.result_reference_time=100.
 check(front.result_comparison(0,true,99.).begins_with("PERSONAL BEST"),"Comparable faster finish receives personal-best emphasis")
 check(front.result_comparison(0,true,101.).begins_with("FROM YOUR BEST"),"Comparable slower finish displays a positive delta")
 check(front.result_comparison(1,true,99.).is_empty(),"Player two never receives player one's comparison")
 comparison_game.race_modified=true
 check(front.result_comparison(0,true,99.).is_empty(),"Modified race has no official personal-best claim")
 comparison_game.race_modified=false;comparison_game.session_id="different"
 check(front.result_comparison(0,true,99.).is_empty(),"Previous-session reference is not reused")
 front.free();comparison_game.free()
 var ui_audio:=LeoUIAudio.new();root.add_child(ui_audio);ui_audio.cue("select")
 check(ui_audio.players.any(func(player):return player.stream!=null),"UI cue uses a prepared procedural stream")
 ui_audio.shutdown()
 check(ui_audio.players.all(func(player):return player.stream==null and not player.playing),"Shutdown releases UI playback streams")
 check(ui_audio.streams.is_empty() and ui_audio.voice.stream==null,"Shutdown releases procedural and voice resources")
 ui_audio.cue("select");ui_audio.say("finish")
 check(ui_audio.players.all(func(player):return player.stream==null) and ui_audio.voice.stream==null,"Late hover/voice callbacks cannot restart audio during shutdown")
 ui_audio.queue_free();await settle();await create_timer(.08).timeout
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
 FileAccess.open(output.path_join("loading.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOADING279 ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
