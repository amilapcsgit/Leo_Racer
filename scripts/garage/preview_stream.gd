class_name LeoPreviewStream
extends RefCounted
## A single bounded load lane; stale selections never start a queued load.
const MAX_SCENES := 3
const MAX_BYTES := 512*1024*1024
static var shader_warmups: Array[PackedScene]=[]
static var busy := false
static var selected: StringName
static var entries: Dictionary = {}
static var recent: Array[StringName] = []
static var timings: Array[Dictionary] = []
static func request(vehicle: VehicleDefinition, tree: SceneTree, current: Callable, foreground: bool=true) -> PackedScene:
	vehicle=LeoVehiclePresentation.resolve(vehicle)
	if foreground:selected=vehicle.id
	while busy:
		if not current.is_valid() or not current.call():return null
		await tree.process_frame
	if not current.is_valid() or not current.call():return null
	var path:=vehicle.preview_scene if not vehicle.preview_scene.is_empty() else vehicle.model_path
	var fingerprint:=path+String(vehicle.content_data.get("pack_sha256",vehicle.content_data.get("version","")))+RenderingServer.get_current_rendering_method()
	if entries.has(vehicle.id) and entries[vehicle.id].fingerprint==fingerprint:
		recent.erase(vehicle.id);recent.append(vehicle.id);return entries[vehicle.id].scene
	busy=true
	var started:=Time.get_ticks_usec()
	# Upload one external texture at a time. A monolithic scene can otherwise
	# make the render thread upload an entire car's images in one long frame.
	var retained: Array[Resource]=[]
	for resource in vehicle.content_data.get("warmup_resources",[]):
		if not current.is_valid() or not current.call():busy=false;return null
		if ResourceLoader.load_threaded_request(resource)!=OK:busy=false;return null
		while ResourceLoader.load_threaded_get_status(resource)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await tree.process_frame
		if ResourceLoader.load_threaded_get_status(resource)!=ResourceLoader.THREAD_LOAD_LOADED:busy=false;return null
		retained.append(ResourceLoader.load_threaded_get(resource))
		await tree.process_frame
	var scene:=await LeoAssets.scene_async(path,tree)
	busy=false
	if scene:
		entries[vehicle.id]={"scene":scene,"path":path,"fingerprint":fingerprint,"bytes":maxi(vehicle.estimated_bytes,32*1024*1024),"definition":vehicle}
		recent.erase(vehicle.id);recent.append(vehicle.id);trim()
	timings.append({"vehicle":String(vehicle.id),"stage":"resources","ms":(Time.get_ticks_usec()-started)/1000.,"foreground":foreground})
	if timings.size()>128:timings.pop_front()
	return scene if current.is_valid() and current.call() else null
static func trim() -> void:
	var total:=0
	for entry in entries.values():total+=int(entry.bytes)
	while recent.size()>MAX_SCENES or (total>MAX_BYTES and recent.size()>1):
		var id:=recent[0]
		if id==selected:recent.remove_at(0);recent.append(id);continue
		recent.remove_at(0)
		var entry: Dictionary=entries[id];total-=int(entry.bytes)
		LeoAssets.cache.erase(entry.path);LeoAssets._recent.erase(entry.path)
		for key in LeoVehiclePresentation.cache.keys():
			if LeoVehiclePresentation.cache[key].id==id:LeoVehiclePresentation.cache.erase(key)
		entries.erase(id)
static func clear() -> void:
	selected=&""
	for entry in entries.values():LeoAssets.cache.erase(entry.path);LeoAssets._recent.erase(entry.path)
	recent.clear();entries.clear();LeoVehiclePresentation.cache.clear()
