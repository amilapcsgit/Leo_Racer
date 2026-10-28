class_name LeoPreviewScheduler
extends Node
## Persistent priority queue: a ready preview includes its driver and a real draw.
var catalog: GarageCatalog
var selected: StringName
var driver: StringName
var direction:=1
var wanted: Array[StringName]=[]
var prepared: Dictionary={}
var failures: Dictionary={}
var busy:=false
var suspended:=false
var warm_view: SubViewport
var warm_root: Node3D
var warm_camera: Camera3D
var serial:=0
signal preview_prepared(vehicle: StringName)
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	warm_view=SubViewport.new();warm_view.size=Vector2i(1216,488);warm_view.own_world_3d=true;warm_view.msaa_3d=get_tree().root.msaa_3d;warm_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(warm_view)
	warm_root=Node3D.new();warm_view.add_child(warm_root)
	warm_camera=Camera3D.new();warm_camera.current=true;warm_camera.fov=43.;warm_root.add_child(warm_camera)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.55
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_ACES;warm_root.add_child(environment)
	for position in [Vector3(-4,6,-4),Vector3(4,4,1),Vector3(0,5,4)]:
		var light:=OmniLight3D.new();light.position=position;light.light_energy=2.;light.omni_range=20.;warm_root.add_child(light)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-30,0);sun.light_energy=.35;sun.shadow_enabled=true;sun.directional_shadow_max_distance=20.;warm_root.add_child(sun)
func key(vehicle: StringName,racer: StringName) -> String:
	var definition:=catalog.vehicle(vehicle)
	return String(vehicle)+":"+String(racer)+":"+String(definition.content_data.get("pack_sha256",definition.model_path))+":"+RenderingServer.get_current_rendering_method()+":"+str(warm_view.msaa_3d)
func anticipate(racer: StringName,vehicle: StringName,travel: int=0) -> void:
	if not catalog or not catalog.vehicle(vehicle) or not catalog.driver(racer):return
	warm_view.msaa_3d=get_tree().root.msaa_3d
	selected=vehicle;driver=racer
	if travel!=0:direction=signi(travel)
	wanted.clear();wanted.append(selected)
	var index:=catalog.vehicle_index(selected)
	for offset in [direction,-direction]:
		var id: StringName=catalog.vehicles[posmod(index+offset,catalog.vehicles.size())].id
		if not id in wanted:wanted.append(id)
	LeoPreviewStream.selected=selected;trim()
func current(vehicle: StringName,racer: StringName) -> bool:
	return is_inside_tree() and not suspended and racer==driver and vehicle in wanted
func hint(vehicle: StringName) -> void:
	if vehicle==selected or not catalog.vehicle(vehicle) or selected==&"":return
	wanted.erase(vehicle);wanted.insert(1,vehicle)
	while wanted.size()>3:wanted.pop_back()
func _process(_dt: float) -> void:
	if suspended or busy or not catalog:return
	for id in wanted:
		var token:=key(id,driver)
		if prepared.has(token) or failures.has(token):continue
		build(id,driver,token);return
func build(id: StringName,racer: StringName,token: String) -> void:
	busy=true
	var valid:=func():return current(id,racer)
	var car:=catalog.vehicle(id)
	var scene:=await LeoPreviewStream.request(car,get_tree(),valid,id==selected)
	if not scene:
		if valid.call():failures[token]="Vehicle unavailable"
		busy=false;return
	var person:=catalog.driver(racer)
	var path:=person.cabin_model_path if car.driver_policy==VehicleDefinition.DriverPolicy.CABIN else person.seated_model_path
	if not path.is_empty() and not await LeoAssets.scene_async(path,get_tree()):failures[token]="Driver unavailable";busy=false;return
	var assembly:=await VehicleAssembler.assemble_async(car,person,get_tree(),valid,scene)
	if not assembly:busy=false;return
	if not valid.call():assembly.free();busy=false;return
	warm_root.add_child(assembly)
	var presentation:=LeoVehiclePresentation.resolve(car)
	var target:=presentation.preview_target
	warm_camera.position=target+Vector3(-.55,.3,-.8).normalized()*presentation.preview_distance;warm_camera.look_at(target)
	var began:=Time.get_ticks_usec();warm_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for frame in 2:
		await get_tree().process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	warm_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;assembly.hide()
	if valid.call():
		serial+=1;prepared[token]={"assembly":assembly,"id":id,"driver":racer,"serial":serial,"bytes":maxi(car.estimated_bytes,32*1024*1024)}
		LeoPreviewStream.timings.append({"vehicle":String(id),"stage":"rendered_ready","frame_latency_ms":(Time.get_ticks_usec()-began)/1000.});preview_prepared.emit(id)
	else:assembly.free()
	busy=false;trim()
func acquire(racer: StringName,vehicle: StringName,valid: Callable) -> Node3D:
	anticipate(racer,vehicle)
	var token:=key(vehicle,racer)
	while valid.is_valid() and valid.call():
		if failures.has(token):return null
		if prepared.has(token):return prepared[token].assembly
		await get_tree().process_frame
	return null
func park(assembly: Node3D) -> void:
	if not is_instance_valid(assembly):return
	assembly.hide()
	if assembly.get_parent()!=warm_root:assembly.reparent(warm_root)
func trim() -> void:
	var bytes:=0
	for entry in prepared.values():bytes+=int(entry.bytes)
	var keys:=prepared.keys();keys.sort_custom(func(a,b):return int(prepared[a].serial)<int(prepared[b].serial))
	for token in keys:
		var entry: Dictionary=prepared[token]
		if token==key(selected,driver):continue
		if not entry.id in wanted or entry.driver!=driver or prepared.size()>3 or bytes>LeoPreviewStream.MAX_BYTES:
			bytes-=int(entry.bytes);entry.assembly.queue_free();prepared.erase(token)
func pause_for_race() -> void:
	suspended=true;wanted.clear()
	for entry in prepared.values():
		if is_instance_valid(entry.assembly):entry.assembly.queue_free()
	prepared.clear();LeoPreviewStream.clear()
