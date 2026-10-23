extends SceneTree
## Offscreen viewports avoid desktop window-size limits during layout QA.
var checks := 0
var errors: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var game: Node3D = load("res://scenes/main.tscn").instantiate()
		viewport.add_child(game);await game.initialization_finished
		await process_frame
		await game.start_race()
		game.state = "capture"
		game.race_time = 3.0
		for kart in game.karts: kart.set_physics_process(false)
		game.player.place(20,0)
		var direction: Vector3 = game.circuit.direction(20)
		game.camera.position = game.player.position-direction*7+Vector3.UP*3.1
		game.camera.look_at(game.player.position+direction*7+Vector3.UP*1.8)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var suffix := "%dx%d"%[dimensions.x,dimensions.y]
		image.save_png("res://docs/qa-srilanka/layout-"+suffix+".png")
		verify(image.get_size()==dimensions,"Rendered exact "+suffix)
		var hud: LeoHUD = game.hud
		var end := hud.position+Vector2(1600,900)*hud.scale
		print("LAYOUT_BOUNDS ",dimensions," ",hud.position," ",hud.scale," ",end)
		verify(hud.position.x>=-.1 and hud.position.y>=-.1 and end.x<=dimensions.x+.1 and end.y<=dimensions.y+.1,"HUD stays inside "+suffix)
		game.stop_all_audio()
		viewport.queue_free()
		await process_frame
		await process_frame
	var report := {"checks":checks,"status":"PASS" if errors.is_empty() else "FAIL","errors":errors}
	var file := FileAccess.open("res://docs/qa-srilanka/layout-test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("LAYOUT_REPORT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
func verify(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: errors.append(message)
