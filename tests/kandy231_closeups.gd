extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1600,900)
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 game.diagnostics_mode=true;game.human_count=1;await game.start_race();game.state="capture";game.hud.hide()
 for kart in game.karts:kart.set_physics_process(false)
 var folder:="res://build/kandy231/closeups";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var stream: Node=game.world.find_child("ColomboSceneryStreaming",true,false)
 var targets: Array=[{"name":"stupa","station":0.,"key":"mahaweli_seya","camera":Vector3(-65,25,65),"aim":24.},{"name":"temple","station":game.circuit.length*.24,"key":"sacred_tooth_precinct","camera":Vector3(38,16,43),"aim":5.},{"name":"buddha","station":game.circuit.length*.46,"key":"buddha","camera":Vector3(20,12,30),"aim":9.},{"name":"jungle-temple","station":game.circuit.length*.67,"key":"jungle_temple","camera":Vector3(42,17,48),"aim":5.},{"name":"ceypetco","station":game.circuit.length*.08,"key":"ceypetco","camera":Vector3(27,4.5,33),"aim":3.}]
 for target in targets:
  game.player.place(target.station,0.)
  while stream.busy:await process_frame
  await stream.refresh(true)
  var landmark: Node3D
  for node in game.world.find_children("*","Node3D",true,false):
   if node.get_meta("protected_asset","")==target.key:landmark=node;break
  if not landmark:push_error("Closeup landmark missing: "+target.name);await game.quit_game(2);return
  game.camera.position=landmark.global_position+target.camera;game.camera.look_at(landmark.global_position+Vector3.UP*target.aim)
  await create_timer(.5).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+"/"+target.name+".png")
 print("KANDY231_CLOSEUPS_COMPLETE");await game.quit_game()
