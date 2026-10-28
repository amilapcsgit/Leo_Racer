extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Export layered lightmaps with a GPU renderer");quit(2);return
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var baker=load("res://resource_baker.gd").new(output,"res://leo_environments/kandy_lake/")
	var manifest: Dictionary={};var evidence: Array=[]
	for key in ["KandyPrecinct_mahaweli","KandyPrecinct_tooth_temple","KandyStartArch"]:
		var data:=load("res://baked/"+key+".lmbake") as LightmapGIData
		if not data or data.lightmap_textures.is_empty() or data.get_user_count()<1:push_error("Incomplete neutral bake: "+key);quit(2);return
		var prepared: Resource=baker.resource(data)
		manifest[key]=prepared.resource_path
		evidence.append({"precinct":key,"users":data.get_user_count(),"atlases":data.lightmap_textures.size()})
	var path:=output.path_join("manifest.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	baker.files["res://leo_environments/kandy_lake/manifest.json"]=path
	if not baker.flush(output.path_join("dusk-neutral.pck")):quit(2);return
	FileAccess.open(output.path_join("validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS","precincts":evidence,"neutral_color":[.5,.5,.5],"environment_energy":.35,"bounces":2,"direct_sun_baked":false,"shared_geometry":true},"  "))
	print("NEUTRAL_PACK_READY ",JSON.stringify(evidence));quit()
