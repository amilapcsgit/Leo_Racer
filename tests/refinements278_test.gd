extends SceneTree
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var measurements: Dictionary={}
var output: String
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func settle(count: int=6) -> void:
 for i in count:await process_frame
func shot(name: String) -> void:
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func button(root_node: Node,title: String) -> Button:
 for node in root_node.find_children("*","Button",true,false):
  if node.text==title:return node
 return null
func pad_a() -> void:
 for down in [true,false]:
  var event:=InputEventJoypadButton.new();event.device=44;event.button_index=JOY_BUTTON_A;event.pressed=down
  root.push_input(event,true);await settle(3)
func run() -> void:
 output=ProjectSettings.globalize_path("res://build/qa278/refinements")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
 DirAccess.make_dir_recursive_absolute(output)
 check(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))==OK and LeoAssets.mount_packs()==OK,"Original asset packages mount")
 LeoVehicleLibrary.discover()
 game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
 print("REFINE_STAGE menu")
 root.size=Vector2i(1280,720);await settle(12)
 var settings:=button(game.hud.menu_root,"Settings")
 check(settings!=null,"Main-menu Settings button found")
 if settings:
  settings.grab_focus();await pad_a()
  check(game.hud.modal_root.find_child("SettingsTabs",true,false)!=null,"Unassigned controller A opens focused main-menu action")
  await shot("controller-settings")
  game.hud.frontend.close_modal()
 var sample:=LeoPlayerInput.new("gamepad");sample.bindings.change_camera=[{"type":"button","index":JOY_BUTTON_LEFT_SHOULDER}]
 var restore:=LeoPlayerInput.new("gamepad");restore.restore(sample.serialize())
 check(restore.bindings.change_camera[0].index==JOY_BUTTON_LEFT_SHOULDER,"Custom gamepad camera binding survives save/restore")
 game.loading.begin_load("qa-race","astra_coast","","race");game.loading.stage("Your controller settings",50);await shot("loading-controller-map");game.loading.hide()
 var h:=LeoHaptics.new();root.add_child(h)
 var now:=[0.];var sent: Array=[]
 h.clock=func():return now[0]
 h.output=func(device,weak,strong,duration):sent.append([device,weak,strong,duration])
 h.play(44,"crash",1.);check(sent[-1][2]>.99,"Full-strength crash reaches full strong motor")
 now[0]=.12;h.tick();check(sent[-1][2]>.99,"Impact holds strong feedback rather than immediately decaying")
 h.stop_all();h.intensity=.5;h.play(44,"crash",1.);check(absf(sent[-1][2]-.5)<.001,"User rumble slider remains proportional")
 h.intensity=0.;h.stop_all();check(sent[-1][2]==0.,"Zero rumble stops output");h.queue_free()
 print("REFINE_STAGE race-loading")
 game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[0].vehicle_id=&"bigster";game.local_players[1].vehicle_id=&"duster_2024"
 await game.start_race();game.set_process(false)
 game.countdown=3.;game.state="countdown"
 for kart in game.karts:kart.active=false
 var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.keycode=KEY_W;event.pressed=true
 game.input_router.feed(event)
 print("REFINE_STAGE prestart")
 for i in 35:await physics_frame
 check(game.player.motor_audio.rpm>3000.,"Held throttle revs during countdown")
 check(absf(game.player.wheel_motion_speed)<.1,"Countdown revving does not move car")
 measurements.countdown_rpm=game.player.motor_audio.rpm
 for slot in 2:
  var kart: LeoKart=game.local_players[slot].kart
  check("cockpit" in LeoCameraViews.available(kart.definition),"Reviewed cockpit enabled / "+String(kart.definition.id))
  var pivot:=kart.visual.find_child("CockpitSteering",true,false) as LeoCockpitSteering
  check(pivot!=null,"Both steering wheel components have a shared hub / "+String(kart.definition.id))
  if pivot:
   kart.set_physics_process(false);kart.steer=.8
   for i in 20:pivot._process(1./60.)
   check(pivot.angle<-.5 and absf(pivot.angle)<=deg_to_rad(135.),"Wheel follows steering within limits")
   check(pivot.get_child_count()==2,"Wheel badge and rim move as one rigid assembly")
   kart.steer=0.;pivot.angle=0.;pivot._process(0.)
   check((pivot.basis*Vector3.UP).y<-.7,"Reviewed neutral pose puts third spoke below the hub")
   kart.set_physics_process(true)
  check(game.split_view.overlays[slot].find_child("CameraView",true,false)==null,"HUD camera selector removed")
  game.local_players[slot].camera_view="cockpit";game.update_local_camera(game.local_players[slot],1.)
 await shot("shared-cockpits-split")
 for extent in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=extent;await settle(8)
  for overlay in game.split_view.overlays:
   check(not overlay.labels.position.get_rect().intersects(overlay.labels.lap.get_rect()),"Compact position/lap panels do not overlap")
   check(not overlay.labels.timer.get_rect().intersects(overlay.labels.track.get_rect()),"Compact time/track labels do not overlap")
   check(not overlay.labels.speed.get_rect().intersects(overlay.labels.rpm_unit.get_rect()),"RPM title and speed digits do not overlap")
   check(not overlay.labels.nitro.get_rect().intersects(overlay.labels.speed.get_rect()),"Nitro status and speed digits do not overlap")
  await shot("split-layout-%dx%d"%[extent.x,extent.y])
 root.size=Vector2i(1280,720);await settle(6)
 var pad: LeoPlayerInput=game.input_router.players[1];pad.switch_kind("gamepad");pad.device=44;pad.bindings.change_camera=[{"type":"button","index":JOY_BUTTON_LEFT_SHOULDER}]
 game.local_players[1].camera_view="chase"
 var camera_event:=InputEventJoypadButton.new();camera_event.device=44;camera_event.button_index=JOY_BUTTON_LEFT_SHOULDER;camera_event.pressed=true
 game.input_router.feed(camera_event)
 check(game.local_players[1].camera_view=="ghost" and game.local_players[0].camera_view=="cockpit","Remapped gamepad action changes only its player's camera")
 game.local_players[1].camera_view="cockpit"
 print("REFINE_STAGE countdown-captures")
 for reduced in [false,true]:
  game.set_reduced_motion(reduced)
  for cue in [3.,2.,1.]:
   game.countdown=cue;game.state="countdown";game._process(.001)
   await settle(2)
   for overlay in game.split_view.overlays:overlay.countdown_letters.set_process(false)
   await shot("countdown-%d-reduced-%s"%[int(cue),str(reduced)])
   for overlay in game.split_view.overlays:overlay.countdown_letters.set_process(true)
 game.countdown=.001;game._process(.01)
 check(game.state=="race" and game.player.active,"GO releases the race hold")
 for i in 45:await physics_frame
 check(game.player.speed>1.,"Throttle held before GO accelerates without a new press")
 measurements.post_go_speed=game.player.speed
 await shot("go-rpm-speed")
 var effects: LeoKartEffects=game.player.effects
 game.player.set_physics_process(false);game.player.grounded=true;game.player.drifting=true;game.player.wheel_motion_speed=18.
 effects.mark_timer=0.;effects._process(.05)
 check(effects.marks.any(func(mark):return mark.visible),"Slipping tire contact leaves visible ground marks")
 var visible_marks:=effects.marks.filter(func(mark):return mark.visible)
 if not visible_marks.is_empty():check(float(visible_marks[0].get_meta("expires"))-effects.elapsed>20.,"Skid marks persist beyond a brief flash")
 await shot("skid-contact")
 game.player.drifting=false;game.player.velocity=Vector3.ZERO;game.player.wheel_motion_speed=0.;game.player.rev_throttle=0.
 var cursor:=effects.mark_cursor;effects.mark_timer=0.;effects._process(.05)
 check(effects.mark_cursor==cursor,"Stationary tires without slip do not stamp skid marks")
 game.player.set_physics_process(true)
 game.human_count=1;game.split_view.activate(false);game.hud.show_race()
 print("REFINE_STAGE cockpit-captures")
 for id in [&"bigster",&"duster_2024"]:
  game.return_menu();game.selected_kart=game.catalog.vehicle_index(id);game.local_players[0].vehicle_id=id
  await game.start_race();game.set_process(false);game.state="race";game.race_time=2.
  game.local_players[0].camera_view="cockpit";game.update_local_camera(game.local_players[0],1.)
  var systems:=game.player.visual.get_node("LiveCockpit") as LeoCockpitSystems
  check(systems.screens.size()==2 and systems.mirrors.size()==3,"Live instruments, navigation and three mirrors / "+String(id))
  for mirror in systems.mirrors:
   check(mirror.surface.has_meta("reviewed_surface"),"Mirror conforms to authored glass / "+String(id)+" / "+String(mirror.surface.name))
   await mirror_probe(systems,mirror,String(id))
  check(systems.mirrors[0].view.size==Vector2i(128,64),"Rear mirror stays low resolution")
  for row in systems.mirrors:row.renders=0
  systems.set_meta("next_mirror",0.)
  systems._process(.11)
  check(systems.mirrors[0].renders==1 and systems.mirrors[1].renders==0 and systems.mirrors[2].renders==0,"Forward view updates rear mirror only")
  check(absf((game.player.global_transform.affine_inverse()*game.local_players[0].camera.global_position).x)<.05,"Default cockpit is centred on car")
  var origin: Vector3=game.local_players[0].camera.global_position
  game.input_router.players[0].inject_test("camera_right",1.);game.update_local_camera(game.local_players[0],1.)
  check(origin.distance_to(game.local_players[0].camera.global_position)<.001,"Cockpit head-look keeps the driver-eye position inside the cabin")
  for row in systems.mirrors:row.renders=0
  systems.set_meta("next_mirror",0.);systems._process(.11)
  check(systems.mirrors[2].renders==1 and systems.mirrors[1].renders==0,"Head-look updates only the visible side mirror")
  await shot(String(id)+"-look-right")
  game.input_router.players[0].inject_test("camera_right",0.);game.local_players[0].camera_rig.reset();game.update_local_camera(game.local_players[0],1.)
  for row in systems.mirrors:row.renders=0
  systems.set_meta("next_mirror",0.);systems._process(.11)
  check(systems.mirrors[1].renders==0 and systems.mirrors[2].renders==0,"Side mirror updates stop after returning forward")
  await shot(String(id)+"-cockpit")
 if "--capture-countdown" in OS.get_cmdline_user_args():
  print("REFINE_STAGE countdown-film");Engine.max_fps=30
  var frames:=output.path_join("countdown-frames");DirAccess.make_dir_recursive_absolute(frames)
  game.state="countdown";game.countdown=3.4;game.race_time=0.;game.last_beep=-1
  for kart in game.karts:kart.active=false
  game.set_reduced_motion(false)
  for i in 120:
   game.input_router.players[0].inject_test("accelerate",1.)
   game.input_router.players[0].inject_test("right",maxf(0.,sin(float(i)*.08)))
   game._process(1./30.)
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(frames.path_join("%04d.png"%i))
 game.state="race";game.race_time=2.;await settle(2)
 check(not game.hud.unified_hud.countdown_container.visible,"Countdown viewport disappears completely after GO")
 var tracks: Array=[]
 for i in 6:game.music.pick();tracks.append(game.music.last_track)
 check(tracks.slice(0,3).size()==3 and tracks[0]!=tracks[1] and tracks[1]!=tracks[2] and tracks[2]!=tracks[3],"Playlist shuffles without immediate repeats")
 check(AudioServer.get_bus_index("Announcer")>=0,"Independent Announcer gain bus available")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"measurements":measurements}
 FileAccess.open(output.path_join("refinements278.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("REFINEMENTS278 ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)


func red_pixels(image: Image) -> int:
 var count:=0
 for x in range(0,image.get_width(),2):
  for y in range(0,image.get_height(),2):
   var c:=image.get_pixel(x,y)
   if c.r>.6 and c.g<.25 and c.b<.25:count+=1
 return count
func mirror_probe(systems: LeoCockpitSystems,row: Dictionary,id: String) -> void:
 systems.update_mirror(row);await settle(2);await RenderingServer.frame_post_draw
 var before:=red_pixels(row.view.get_texture().get_image())
 var probe:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.65;sphere.height=1.3;probe.mesh=sphere
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color.RED;probe.material_override=material;probe.layers=1<<11;game.world.add_child(probe)
 probe.global_position=row.camera.global_position-row.camera.global_basis.z*4.
 systems.update_mirror(row);await settle(3);await RenderingServer.frame_post_draw
 var actual:=red_pixels(row.view.get_texture().get_image())
 check(actual>before+8,"Mirror renders moving shared-world geometry / "+id+" / "+String(row.surface.name))
 measurements[id+"-"+String(row.surface.name)]={"baseline_red_pixels":before,"probe_red_pixels":actual,"texture_size":str(row.view.size)}
 probe.free();systems.update_mirror(row);await settle(2)
