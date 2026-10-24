class_name LeoWorkshopLauncher
extends Node
## A local job/result handshake; no sockets, servers or accounts.
signal completed(result: Dictionary)
static var running: Node
var pid := -1
var job_path := ""
var elapsed := 0.

static func launch(parent: Node, source: String="", definition: Dictionary={}) -> LeoWorkshopLauncher:
	if is_instance_valid(running):return running as LeoWorkshopLauncher
	var helper:=LeoWorkshopLauncher.new();parent.add_child(helper)
	var nonce:=str(Time.get_unix_time_from_system()).replace(".","_")+"_"+str(randi())
	helper.job_path=ProjectSettings.globalize_path("user://vehicle-workshop/jobs/"+nonce+".json")
	DirAccess.make_dir_recursive_absolute(helper.job_path.get_base_dir())
	var job:={"format":1,"source":source,"source_definition":definition,"vehicles_root":LeoVehicleLibrary.default_root(),"job_path":helper.job_path}
	var file:=FileAccess.open(helper.job_path,FileAccess.WRITE)
	if not file:helper.queue_free();return null
	file.store_string(JSON.stringify(job,"  "));file.close()
	var arguments:=PackedStringArray()
	if OS.has_feature("editor"):arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--rendering-method",RenderingServer.get_current_rendering_method(),"--","--vehicle-workshop","--workshop-job="+helper.job_path])
	helper.pid=OS.create_process(OS.get_executable_path(),arguments)
	if helper.pid<=0:helper.queue_free();return null
	running=helper
	return helper

static func write_result(path: String, result: Dictionary) -> Error:
	if path.is_empty():return OK
	var file:=FileAccess.open(path+".result.tmp",FileAccess.WRITE)
	if not file:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(result,"  "));file.close()
	return DirAccess.rename_absolute(path+".result.tmp",path+".result.json")

func _process(dt: float) -> void:
	elapsed+=dt
	if elapsed<.3:return
	elapsed=0.
	if pid>0 and OS.is_process_running(pid):return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(job_path+".result.json")) if FileAccess.file_exists(job_path+".result.json") else null
	var result: Dictionary=parsed if parsed is Dictionary else {"status":"cancelled","error":"Workshop closed. Your source file is unchanged."}
	running=null;completed.emit(result);queue_free()
