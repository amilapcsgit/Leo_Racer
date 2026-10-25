extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var scene:="res://kandy.tscn";var action:="export"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--scene="):scene=arg.trim_prefix("--scene=")
  if arg.begins_with("--action="):action=arg.trim_prefix("--action=")
 var resource:=load(scene) as PackedScene
 if not resource:printerr("Missing authoring scene "+scene);quit(2);return
 var author: Node3D=resource.instantiate();root.add_child(author)
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):author.destination=argument.trim_prefix("--output=")
 if not author.load_data():quit(2);return
 author.edit_course();await process_frame;await process_frame
 var success: bool=author.validate()
 if success and action!="validate":
  author.dress_scenery();await process_frame;await process_frame
  if action=="export":success=author.export_track()
 if not success:printerr(author.last_error)
 root.remove_child(author);author.free();quit(0 if success else 2)
