extends SceneTree
## Repackage one already-baked built-in track without exporting the application.
func _initialize() -> void:
	var id:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track-id="):id=arg.trim_prefix("--track-id=")
	if not LeoVehicleLibrary.safe_relative(id):printerr("Invalid track ID");quit(1);return
	var source:="res://assets/tracks/"+id;var manifest_path:=source.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):printerr("Unknown built-in track");quit(1);return
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var folder:="res://build/content-tracks/"+id;DirAccess.make_dir_recursive_absolute(folder)
	var cells: Dictionary={"format":1,"cells":[]}
	if FileAccess.file_exists(source.path_join("cells.json")):cells=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("cells.json")))
	var resources: Array=[]
	for key in ["scene","backdrop"]:
		if metadata.has(key):resources.append({"owner":metadata,"key":key,"path":String(metadata[key])})
	for cell in cells.get("cells",[]):resources.append({"owner":cell,"key":"scene","path":String(cell.scene)})
	var staged: Array=[];var fingerprint:=""
	for i in resources.size():
		var entry: Dictionary=resources[i];var scene:=load(String(entry.path)) as PackedScene
		if not scene:printerr("Bake track scenery before exporting: ",entry.path);quit(1);return
		var file:=folder.path_join("stage_%03d.scn"%i)
		if ResourceSaver.save(scene,file,ResourceSaver.FLAG_BUNDLE_RESOURCES)!=OK:quit(1);return
		fingerprint+=FileAccess.get_sha256(file);staged.append(file)
	var prefix:="res://mods/tracks/"+id+"/"+fingerprint.sha256_text().left(16)+"/"
	var pack:=PCKPacker.new();var pack_path:=folder.path_join("scenery.pck")
	if pack.pck_start(pack_path)!=OK:quit(1);return
	for i in resources.size():
		var virtual_path:=prefix+"scene_%03d.scn"%i
		pack.add_file(virtual_path,staged[i]);resources[i].owner[resources[i].key]=virtual_path
	if pack.flush()!=OK:quit(1);return
	for file in staged:DirAccess.remove_absolute(file)
	# Keep API 1 identity/lighting behavior for the two original tracks.
	metadata.packs=[{"file":"scenery.pck","sha256":FileAccess.get_sha256(pack_path)}];metadata.dependencies=[]
	for name in ["route.json","preview.png"]:
		if FileAccess.file_exists(source.path_join(name)):DirAccess.copy_absolute(source.path_join(name),folder.path_join(name))
	FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata,"  ")+"\n")
	FileAccess.open(folder.path_join("cells.json"),FileAccess.WRITE).store_string(JSON.stringify(cells,"  ")+"\n")
	FileAccess.open(folder.path_join("LICENSE.txt"),FileAccess.WRITE).store_string("Original Leo Racer track. See GameAssets/licenses for retained notices and attribution.\n")
	print("INDEPENDENT_TRACK_BUILT ",id," scenes=",resources.size()," core_export_invoked=false");quit()
