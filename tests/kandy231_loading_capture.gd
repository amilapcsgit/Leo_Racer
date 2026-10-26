extends SceneTree
var watching:=true
var captured: Dictionary={}
func _initialize() -> void:run.call_deferred()
func watch(game: Node3D) -> void:
 while watching:
  await process_frame
  if not game.loading or not game.loading.visible or not game.loading.detail:continue
  var operation: String=game.loading.operation_id.get_slice("-",0)
  if captured.has(operation):continue
  var words: String=game.loading.detail.text
  if not words.contains("…"):continue
  captured[operation]={"detail":words,"summary":game.loading.summary.text}
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/kandy231/loading/"+operation+".png")
func run() -> void:
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/kandy231/loading"))
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);watch.call_deferred(game);await game.initialization_finished
 await game.select_track("colombo_city");await game.select_track("kandy_lake")
 game.diagnostics_mode=true;game.human_count=1;await game.start_race()
 watching=false
 FileAccess.open("res://build/kandy231/loading/copy.json",FileAccess.WRITE).store_string(JSON.stringify(captured,"  "))
 print("KANDY231_LOADING_CAPTURES ",JSON.stringify(captured));await game.quit_game(0 if captured.size()>=3 else 2)
