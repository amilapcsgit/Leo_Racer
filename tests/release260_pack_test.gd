extends SceneTree
var checks:=0
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://build/sdk260-final-export")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sdk-folder="):folder=arg.trim_prefix("--sdk-folder=")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("vehicle.json")))
	# Exercise all untrusted-pack checks even if a deterministic SDK export
	# happens to reproduce the officially registered binary byte-for-byte.
	LeoVehiclePack.official={"fixture":{}}
	var problem:=LeoVehiclePack.problem(data,folder)
	check(problem.is_empty(),"Independent SDK pack passes full validation: "+problem)
	var fixture:=ProjectSettings.globalize_path("res://build/qa260/pack-fixtures")
	DirAccess.make_dir_recursive_absolute(fixture)
	var node:=Node3D.new();var script:=GDScript.new();script.source_code="extends Node3D\n";script.reload();node.set_script(script)
	var scene:=PackedScene.new();scene.pack(node);node.free()
	var disk:=fixture.path_join("scripted.scn");ResourceSaver.save(scene,disk)
	var pck:=PCKPacker.new();var path:=fixture.path_join("script_probe.pck")
	pck.pck_start(path);pck.add_file("res://leo_vehicles/script_probe/model.scn",disk);pck.flush()
	var malicious:={"id":"script_probe","pack":"script_probe.pck","pack_sha256":FileAccess.get_sha256(path),"model_scene":"res://leo_vehicles/script_probe/model.scn"}
	problem=LeoVehiclePack.problem(malicious,fixture)
	check(problem.contains("embedded scripts"),"Embedded CPU scripts are rejected before resource loading: "+problem)
	check(not ResourceLoader.exists("res://leo_vehicles/script_probe/model.scn"),"Rejected script pack never mounts")
	var state:=PackedScene.new();var request:=HTTPRequest.new();state.pack(request);request.free()
	check(not LeoVehiclePack.scene_problem(state).is_empty(),"Non-model native nodes are rejected")
	var result:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"sdk_pack_sha256":FileAccess.get_sha256(folder.path_join(data.pack))}
	FileAccess.open("res://build/qa260/sdk.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PACK260 ",JSON.stringify(result));quit(0 if errors.is_empty() else 2)
