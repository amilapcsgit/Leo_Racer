extends SceneTree
func _initialize() -> void:
	var output:="res://build/VehicleWorkshop"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var pack:=PCKPacker.new()
	if pack.pck_start(output.path_join("workshop.pck"))!=OK:quit(2);return
	for paths in [["res://tools/vehicle_workshop/workshop.gd","res://tools/vehicle_workshop/workshop.gd"],["res://tools/vehicle_workshop/converter.gd","res://scripts/content/workshop_converter.gd"]]:
		if pack.add_file(paths[0],ProjectSettings.globalize_path(paths[1]))!=OK:printerr("WORKSHOP_PACK_FAILED ",paths[0]);quit(2);return
	if pack.flush()!=OK:quit(2);return
	var metadata:={"format":1,"workshop_api":1,"version":"1.1.0","core_min":"2.3.2","core_major":2,"engine":"4.7","offline":true,"entry":"res://tools/vehicle_workshop/workshop.gd","sha256":FileAccess.get_sha256(output.path_join("workshop.pck"))}
	FileAccess.open(output.path_join("workshop.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata,"  ")+"\n")
	print("WORKSHOP_PACK_BUILT ",JSON.stringify(metadata));quit()
