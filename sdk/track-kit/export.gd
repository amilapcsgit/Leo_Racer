extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=ProjectSettings.globalize_path("res://exported")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=ProjectSettings.globalize_path(arg.trim_prefix("--output="))
	var track: Node3D=load("res://example.tscn").instantiate();root.add_child(track);await process_frame
	var success: bool=track.export_track(output)
	if not success:printerr(track.last_error)
	track.free();quit(0 if success else 1)
