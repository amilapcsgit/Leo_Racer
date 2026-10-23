extends SceneTree
var game: Node3D
var viewport: SubViewport
var errors: Array[String]=[]
var checks:=0
var visual:=false
var output:="res://build/qa-neon/"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,words: String) -> void:
 checks+=1
 if not ok:errors.append(words);push_error(words)
func frames(count: int=3) -> void:
 for i in count:await process_frame
func shot(name: String,delay: float=.28) -> void:
 if not visual:return
 await create_timer(delay).timeout;await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png(output+name+".png")
func run() -> void:
 visual="--visual-test" in OS.get_cmdline_user_args();output+=RenderingServer.get_current_rendering_method()+"/";DirAccess.make_dir_recursive_absolute(output)
 # One operation survives bootstrap handoff/progress/retries; distinct operations alternate.
 var first:=LeoLoadingBackdrops.begin_load("boot")
 check(first in [LeoLoadingBackdrops.DAY,LeoLoadingBackdrops.NIGHT],"Random first backdrop is shipped day or night artwork")
 check(LeoLoadingBackdrops.begin_load("boot")==first,"Bootstrap handoff retains the same artwork")
 var second:=LeoLoadingBackdrops.begin_load("test-race")
 check(second!=first and LeoLoadingBackdrops.begin_load("test-race")==second,"Distinct loading alternates; retry retains artwork")
 check(LeoLoadingBackdrops.begin_load("test-track")==first,"Loading alternates back on the next operation")
 viewport=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game);await game.initialization_finished;game.diagnostics_mode=true;await frames()
 var ui: LeoFrontend=game.hud.frontend;var service: LeoUIEffects=game.hud.ui_effects
 var go: LeoActionButton
 for candidate in game.hud.menu_root.find_children("*","Button",true,false):
  if candidate.text.begins_with("Go Race"):go=candidate
 check(go!=null,"Home retains Go Race")
 go.release_focus();go.hovered=false;go.update_active();game.ui_audio.last_move=-1000
 var moves:=int(game.ui_audio.cue_counts.get("move",0));go.hovered=true;go.enter();game.ui_audio.last_move=-1000;go.grab_focus()
 check(int(game.ui_audio.cue_counts.get("move",0))==moves+1,"Hover plus focus produces one entry cue")
 var other:=game.hud.menu_root.find_children("*","Button",true,false).filter(func(button):return button!=go)[0] as LeoActionButton
 check(go.fx.halo.material!=other.fx.halo.material,"Animated buttons have independent shader materials")
 await shot("home-neon")
 var bursts:=service.burst_count;go.pressed.emit();await frames()
 check(service.burst_count==bursts+1 and service.layer.is_inside_tree(),"Activation produces one pooled burst surviving navigation")
 check(game.ui_audio.players.size()==4 and game.ui_audio.streams.has("carousel") and game.ui_audio.streams.has("preview"),"Four UI voices cache distinct procedural cues")
 ui.show_setup(2);var p1_driver: StringName=game.local_players[0].driver_id;var p1_car: StringName=game.local_players[0].vehicle_id;ui.open_garage(1);await frames()
 var garage: ModularCarSelector=game.hud.garage_selector;var carousel: LeoDriverCarousel=garage.carousel
 check(garage.player_slot==1 and game.selected_player_slot==1,"Garage identifies the originating player")
 check(garage.find_children("*","ScrollBar",true,false).is_empty(),"Driver carousel has no scrollbar")
 check(carousel.left.size.x>=48 and carousel.right.size.x>=48,"Both carousel arrow targets are at least 48 px")
 for i in game.catalog.drivers.size():
  carousel.step(1);await frames()
  check(carousel.cards.filter(func(card):return card.visible).size()==3,"Exactly three portraits at carousel position "+str(i))
  check(carousel.driver_name.text==game.catalog.driver(garage.driver_id).display_name,"Complete selected name at carousel position "+str(i))
  await shot("driver-"+str(carousel.selected))
 check(game.local_players[0].driver_id==p1_driver and game.local_players[0].vehicle_id==p1_car,"P2 carousel browsing preserves P1")
 var start:=carousel.selected;carousel.step(1);carousel.step(-1);check(carousel.selected==start,"Rapid direction reversal restores logical selection")
 carousel.step(1);carousel.step(1);carousel.step(-1)
 var deadline:=Time.get_ticks_msec()+30000
 while (not is_instance_valid(garage.assembly) or garage.assembly.get_meta("driver_id")!=garage.driver_id) and Time.get_ticks_msec()<deadline:await frames()
 check(is_instance_valid(garage.assembly) and garage.assembly.get_meta("driver_id")==garage.driver_id,"Latest asynchronous preview matches the selected driver")
 carousel.grab_focus();var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.physical_keycode=KEY_RIGHT;key.pressed=true;var before:=carousel.selected;viewport.push_input(key,true);await frames()
 check(carousel.selected==posmod(before+1,carousel.cards.size()),"Keyboard Right advances the focused carousel exactly once")
 key=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=false;viewport.push_input(key,true)
 var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_DPAD_LEFT;pad.pressed=true;before=carousel.selected;viewport.push_input(pad,true);await frames()
 check(carousel.selected==posmod(before-1,carousel.cards.size()),"Controller D-pad advances the carousel once")
 pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_DPAD_LEFT;pad.pressed=false;viewport.push_input(pad,true)
 var axis:=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_LEFT_X;axis.axis_value=.9;before=carousel.selected;viewport.push_input(axis,true);await frames()
 check(carousel.selected==posmod(before+1,carousel.cards.size()),"Controller stick advances the focused carousel")
 axis=InputEventJoypadMotion.new();axis.axis=JOY_AXIS_LEFT_X;axis.axis_value=0.;viewport.push_input(axis,true)
 before=carousel.selected;carousel.right.pressed.emit();await frames();check(carousel.selected==posmod(before+1,carousel.cards.size()),"Arrow activation advances exactly once")
 var center:=carousel.left.get_global_rect().get_center();var mouse:=InputEventMouseButton.new();mouse.position=center;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;before=carousel.selected;viewport.push_input(mouse,true)
 mouse=InputEventMouseButton.new();mouse.position=center;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=false;viewport.push_input(mouse,true);await frames()
 check(carousel.selected==posmod(before-1,carousel.cards.size()),"Mouse click reaches the left arrow")
 var bar:=garage.stat_bars[0];bar.ratio=0.;bar.target=0.;bar.set_value(1.);await create_timer(.12).timeout
 check(bar.ratio>0. and bar.ratio<1. and bar.flash>0.,"Stats animate and redraw during the value tween")
 bar.set_value(.4);await create_timer(.55).timeout;check(is_equal_approx(bar.ratio,.4),"Interrupted stats settle at their newest target")
 garage.refresh_labels()
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  viewport.size=dimensions;await frames();await shot("garage-%dx%d" % [dimensions.x,dimensions.y])
  var bounds:=carousel.get_global_rect();check(bounds.position.x>=0 and bounds.end.x<=dimensions.x,"Carousel remains inside the viewport at "+str(dimensions))
 game.set_reduced_motion(true);await frames();check(carousel.reduced_motion and not carousel.moves.values().any(func(t):return t.is_running()),"Reduced Motion stops carousel animation")
 check(bar.flash==0. and is_equal_approx(bar.ratio,bar.target),"Reduced Motion settles stats immediately")
 bursts=service.burst_count;service.burst(carousel);check(service.burst_count==bursts,"Reduced Motion suppresses bursts")
 await shot("garage-reduced")
 garage.back_requested.emit();game.return_menu();await frames();await shot("home-reduced")
 var backdrop:=game.hud.menu_root.find_child("BackdropFX",true,false) as LeoBackdropFX
 check(backdrop.reduced_motion and not backdrop.particles.visible,"Reduced Motion freezes parallax and ambient particles")
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  viewport.size=dimensions;await frames()
  for reduced in [true,false]:
   game.set_reduced_motion(reduced);await frames();await shot("home-%dx%d-%s" % [dimensions.x,dimensions.y,"reduced" if reduced else "motion"])
   var artwork_bounds:=backdrop.art.get_global_rect();var glow_bounds:=backdrop.ambient.get_global_rect()
   check(artwork_bounds.position.x<=0 and artwork_bounds.end.x>=dimensions.x and glow_bounds.position.x<=0 and glow_bounds.end.x>=dimensions.x,"Artwork and glow cover the viewport at "+str(dimensions)+" reduced="+str(reduced))
 game.set_reduced_motion(true)
 ui.show_tracks();await frames();await shot("tracks-reduced");ui.close_modal();game.set_reduced_motion(false);ui.show_tracks();await frames();await shot("tracks-hologram");ui.close_modal()
 for id in ["qa-loading-a","qa-loading-b"]:
  game.loading.begin_load(id);var path: String=game.loading.backdrop_path;game.loading.stage("Preparing your next race…",60);await shot("loading-day" if path==LeoLoadingBackdrops.DAY else "loading-night")
  game.loading.stage("Nearly ready…",90);check(game.loading.backdrop_path==path,"Progress updates retain loading artwork")
  game.loading.show_failure("Test retry",func():pass,func():pass);check(game.loading.backdrop_path==path,"Failure recovery retains loading artwork")
 game.loading.hide();game.stop_all_audio();game.queue_free();await frames();viewport.queue_free();await frames();LeoAssets.cache.clear();LeoAssets._patched_meshes.clear()
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"visual":visual,"renderer":RenderingServer.get_current_rendering_method()}
 FileAccess.open(output+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("NEON_UI_TEST ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
