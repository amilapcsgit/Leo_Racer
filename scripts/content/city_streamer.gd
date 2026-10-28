extends Node3D
## Scenery cells are independent of the permanently resident race collision.
var game: Node3D
var definition: LeoTrackDefinition
var cells: Array = []
var loaded: Dictionary = {}
# Keep shared resource graphs alive for this track. Cells still release their
# scene instances; eviction during threaded loads can invalidate shared shader
# resources in the native release renderer. The owner dies on track change.
var scene_resources: Dictionary = {}
var timer := 0.
var busy := false
var halted := false
var load_radius := 600.
var unload_radius := 850.
var stats := {"loads":0,"unloads":0,"peak_cells":0}

func setup(owner_game: Node3D, track: LeoTrackDefinition) -> void:
	name="ColomboSceneryStreaming";game=owner_game;definition=track
	var path:=track.folder.path_join("cells.json")
	if FileAccess.file_exists(path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:cells=data.get("cells",[])
	await refresh(true)

func anchors() -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if game.karts.is_empty():result.append(game.circuit.sample(0))
	else:
		for slot in game.human_count:
			var kart: LeoKart=game.local_players[slot].kart
			if is_instance_valid(kart):result.append(kart.global_position)
			var camera: Camera3D=game.local_players[slot].camera
			if is_instance_valid(camera):result.append(camera.global_position)
	return result
func priority(center: Vector3) -> float:
	var score:=INF
	for slot in game.human_count:
		var local: LeoLocalPlayer=game.local_players[slot]
		if not is_instance_valid(local.kart):continue
		var kart: LeoKart=local.kart
		var future:=kart.global_position+kart.velocity*4.
		score=minf(score,minf(center.distance_to(kart.global_position),center.distance_to(future)*.8))
	return score

func wanted(center: Vector3, distance: float, positions: Array[Vector3]) -> bool:
	for position in positions:
		if Vector2(position.x-center.x,position.z-center.z).length()<distance:return true
	return false

func _process(dt: float) -> void:
	if busy or halted or not is_instance_valid(game):return
	timer+=dt
	if timer>.25:timer=0.;refresh()

func refresh(initial: bool = false) -> void:
	if busy or halted:return
	busy=true
	var positions:=anchors()
	var ordered:=cells.duplicate()
	ordered.sort_custom(func(a,b):return priority(Vector3(a.center[0],0,a.center[1]))<priority(Vector3(b.center[0],0,b.center[1])))
	for cell in ordered:
		if halted:break
		var id:=String(cell.id);var center:=Vector3(float(cell.center[0]),0,float(cell.center[1]))
		if loaded.has(id):
			if not wanted(center,unload_radius,positions):
				var node: Node=loaded[id];remove_child(node);node.queue_free();loaded.erase(id);stats.unloads+=1
		elif wanted(center,load_radius,positions):
			var scene: PackedScene=scene_resources.get(String(cell.scene))
			if not scene:
				scene=await LeoAssets.scene_async(String(cell.scene),get_tree())
				if scene:scene_resources[String(cell.scene)]=scene
			if not is_inside_tree():return
			# Cameras can move while a resource is loading.
			if scene and not halted and (initial or wanted(center,load_radius,anchors())):
				await LeoPreparationBudget.checkpoint(get_tree())
				var began:=Time.get_ticks_usec();var node:=scene.instantiate();LeoPreparationBudget.record(began)
				await LeoPreparationBudget.checkpoint(get_tree())
				var pending: Array[Node]=[node]
				while not pending.is_empty() and not halted:
					await LeoPreparationBudget.checkpoint(get_tree())
					var item: Node=pending.pop_back();pending.append_array(item.get_children())
					began=Time.get_ticks_usec();LeoSceneInstances.restore_one(item);LeoAssets.apply_overrides(item,false);LeoPreparationBudget.record(began)
				if halted:node.free();break
				await LeoPreparationBudget.checkpoint(get_tree())
				began=Time.get_ticks_usec();add_child(node);LeoPreparationBudget.record(began);loaded[id]=node;stats.loads+=1
				stats.peak_cells=maxi(stats.peak_cells,loaded.size())
				await get_tree().process_frame
	busy=false

func stop() -> void:
	halted=true
	while busy:await get_tree().process_frame
