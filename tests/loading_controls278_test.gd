extends SceneTree
var output: String
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:errors.append(message);push_error(message)
func run() -> void:
 output=ProjectSettings.globalize_path("res://build/qa278/loading")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(output)
 var screen:=LeoLoadingScreen.new();root.add_child(screen);screen.stage("Startup",10)
 check(not screen.diagram.visible,"Startup guide hidden by default")
 screen.begin_load("track-test","astra_coast");screen.stage("Track change",20)
 check(not screen.diagram.visible,"Track change guide hidden")
 screen.begin_load("race-test","astra_coast","","race");screen.stage("Loading track...",72)
 check(screen.diagram.visible,"Explicit race context enables guide")
 check(screen.spinner.text.is_empty(),"Noninteractive loading has no confirm/back hints")
 check(screen.bar.size.y<=7.,"Loading progress bar stays slim after theme minimum sizing")
 for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160)]:
  root.size=extent
  var cases: Array=[["keyboard"],["gamepad"],["wheel"]]
  for first in ["keyboard","gamepad","wheel"]:
   for second in ["keyboard","gamepad","wheel"]:cases.append([first,second])
  for types in cases:
   var r: LeoInputRouter=screen.diagram.fallback;r.active_slots=types.size()
   for slot in types.size():
    r.players[slot].switch_kind(types[slot]);r.players[slot].reset_defaults(types[slot])
    r.players[slot].device=11+slot if types[slot]!="keyboard" else -1
    if types[slot]=="wheel":
     r.players[slot].set_axis("accelerate",JOY_AXIS_TRIGGER_RIGHT,0.,1.)
     r.players[slot].set_axis("brake",JOY_AXIS_TRIGGER_LEFT,0.,1.)
   if types==["keyboard","keyboard"]:r.configure_keyboards(2)
   if types==["gamepad","gamepad"]:r.players[1].bindings.change_camera=[{"type":"button","index":JOY_BUTTON_LEFT_SHOULDER}]
   for i in 5:await process_frame
   await RenderingServer.frame_post_draw
   var title: String="-".join(types)
   root.get_texture().get_image().save_png(output.path_join("loading-%s-%dx%d.png"%[title,extent.x,extent.y]))
   check(screen.diagram.panels.size()==types.size(),"Exactly one selected device diagram per player / "+title)
   for slot in types.size():
    var panel: LeoControlMapPanel=screen.diagram.panels[slot]
    check(panel.kind==("controller" if types[slot]=="gamepad" else types[slot]),"Diagram follows this player's assigned device")
    check(panel.callouts.size()==6,"Six primary actions have graphical callouts")
    check(panel.route_errors.is_empty(),"All bound actions have routable connectors: "+str(panel.route_errors))
    for row in panel.callouts:
     check(Rect2(Vector2.ZERO,panel.size).encloses(row.rect),"Callout stays inside its panel / "+row.action)
     check((row.path.size()>1)==(row.key!=""),"Connector exists exactly when action is assigned / "+row.action)
     for other in panel.callouts:
      if row!=other:check(not row.rect.intersects(other.rect),"Action labels do not overlap")
     if row.key!="":
      for segment in range(1,row.path.size()):
       var a: Vector2=row.path[segment-1];var b: Vector2=row.path[segment]
       for id in panel.controls:
        if id==row.key or panel.controls[id].rect==panel.controls[row.key].rect:continue
        var rect: Rect2=panel.controls[id].rect.grow(-1.5)
        var hit:=false
        for step in range(1,int(a.distance_to(b)/2.)):
         if rect.has_point(a.lerp(b,float(step)*2./maxf(1.,a.distance_to(b)))):hit=true;break
        check(not hit,"Connector avoids unrelated physical control / "+row.action+" / "+id)
     if row.key!="":
      for other in panel.callouts:
       if other.action==row.action or other.key=="" or panel.controls[other.key].rect==panel.controls[row.key].rect:continue
       var crossed:=false
       for j in range(1,row.path.size()):
        for k in range(1,other.path.size()):
         if Geometry2D.segment_intersects_segment(row.path[j-1],row.path[j],other.path[k-1],other.path[k])!=null:crossed=true
       check(not crossed,"Leader lines for different controls do not cross / "+row.action+" / "+other.action)
     if row.action=="right":check(row.key!="" and row.path.size()>1,"Steering right is present and connected")
 var r: LeoInputRouter=screen.diagram.fallback;r.active_slots=1
 var p: LeoPlayerInput=r.players[0];p.reset_defaults("keyboard");p.bindings.accelerate=[{"type":"key","index":KEY_F}]
 for i in 5:await process_frame
 var panel: LeoControlMapPanel=screen.diagram.panels[0]
 var camera: Dictionary=panel.callouts.filter(func(row):return row.action=="accelerate")[0]
 check(camera.key=="key_F" and camera.path[-1].is_equal_approx(panel.controls.key_F.point),"Saved accelerator remap moves label and connector endpoint to F")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("loading-accelerator-remapped-F.png"))
 p.bindings.accelerate=[]
 for i in 4:await process_frame
 panel=screen.diagram.panels[0];camera=panel.callouts.filter(func(row):return row.action=="accelerate")[0]
 check(camera.binding.text=="Not assigned" and camera.path.is_empty(),"Unassigned action has no misleading connector")
 screen.begin_load("general-after-race");screen.stage("General operation",50)
 check(not screen.diagram.visible,"General loading after race clears guide visibility")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("loading-general-no-guide.png"))
 var calls:=[0];screen.show_failure("Test content failure",func():calls[0]+=1,func():calls[0]+=10)
 check(screen.retry.has_focus(),"Content error gives controller focus to retry")
 var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=true;screen._input(event)
 check(calls[0]==10,"Controller B leaves loading error")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
 FileAccess.open(output.path_join("loading.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOADING278 ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
