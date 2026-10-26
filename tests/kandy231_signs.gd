extends SceneTree
func _initialize() -> void:run.call_deferred()
func photograph(game: Node3D,pose: Transform3D,name: String,height: float) -> void:
 game.camera.position=pose.origin+pose.basis.z*15.+Vector3.UP*height
 game.camera.look_at(pose.origin+Vector3.UP*height)
 await create_timer(.25).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/kandy231/details/"+name+".png")
func run() -> void:
 root.size=Vector2i(1280,720)
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 game.diagnostics_mode=true;game.human_count=1;await game.start_race();game.state="capture";game.hud.hide()
 for kart in game.karts:kart.set_physics_process(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/kandy231/details"))
 var stream: Node=game.world.find_child("ColomboSceneryStreaming",true,false)
 for spec in [["welcome",0.,3.1],["tourism",105.,5.4],["tea-shop",335.,5.4]]:
  game.player.place(spec[1],0.)
  while stream.busy:await process_frame
  await stream.refresh(true)
  for node in game.world.find_children("PhysicalSign_*","Node3D",true,false):
   if node.get_meta("physical_sign","")==spec[0]:await photograph(game,node.global_transform,spec[0],spec[2]);break
 var found:=false
 for node in game.world.find_children("*","MultiMeshInstance3D",true,false):
  if node.has_meta("flag_hoist_uv"):
   await photograph(game,node.global_transform*node.multimesh.get_instance_transform(0),"flag-hoist",5.2);found=true;break
 print("KANDY231_SIGN_CAPTURES ",found);await game.quit_game(0 if found else 2)
