extends SceneTree
func _initialize() -> void:run.call_deferred()
func shot(name_text: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/qa-bigster/"+name_text+".png")
func run() -> void:
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished;await process_frame
 game.diagnostics_mode=true;game.hud.show_garage()
 var selector: ModularCarSelector=game.hud.garage_selector;selector.set_selection(&"human",&"bigster");selector.reduced_motion=true
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
  DisplayServer.window_set_size(resolution);root.size=resolution;await process_frame;game.hud.resize_canvas();await shot("garage-%dx%d"%[resolution.x,resolution.y])
 root.size=Vector2i(1600,900);DisplayServer.window_set_size(root.size);game.hud.resize_canvas();selector.yaw=-.7;selector.update_camera();await shot("grey-bigster")
 game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit()
