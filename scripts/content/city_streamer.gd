extends Node3D
## Scenery cells are independent of the permanently resident race collision.
var game: Node3D
var definition: LeoTrackDefinition
var cells: Array = []
var loaded: Dictionary = {}
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
	for cell in cells:
		if halted:break
		var id:=String(cell.id);var center:=Vector3(float(cell.center[0]),0,float(cell.center[1]))
		if loaded.has(id):
			if not wanted(center,unload_radius,positions):
				var node: Node=loaded[id];remove_child(node);node.queue_free();loaded.erase(id);stats.unloads+=1
		elif wanted(center,load_radius,positions):
			var scene:=await LeoAssets.scene_async(String(cell.scene),get_tree())
			if not is_inside_tree():return
			# Cameras can move while a resource is loading.
			if scene and not halted and (initial or wanted(center,load_radius,anchors())):
				var node:=scene.instantiate();load("res://scripts/content/scene_instances.gd").restore(node);LeoAssets.apply_overrides(node);add_child(node);loaded[id]=node;stats.loads+=1
				stats.peak_cells=maxi(stats.peak_cells,loaded.size())
				await get_tree().process_frame
	busy=false

func stop() -> void:
	halted=true
	while busy:await get_tree().process_frame
