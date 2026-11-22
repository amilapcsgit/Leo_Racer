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
# Load beyond the visible edge so the camera can approach either way.
const VIEW_DISTANCES := [390.0, 510.0, 700.0, 900.0]
const PRELOAD_MARGIN := 210.0
const EVICT_MARGIN := 160.0
const FADE_WIDTH := 150.0
var view_distance := 510.0
var fade_materials: Dictionary = {}
var stats := {"loads":0,"unloads":0,"peak_cells":0}

func setup(owner_game: Node3D, track: LeoTrackDefinition) -> void:
	name="ColomboSceneryStreaming";game=owner_game;definition=track
	var path:=track.folder.path_join("cells.json")
	if FileAccess.file_exists(path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:cells=data.get("cells",[])
	update_view_distance()
	await refresh(true)

func anchors() -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if game.karts.is_empty():result.append(game.circuit.sample(0))
	else:
		for slot in game.human_count:
			var kart: LeoKart=game.local_players[slot].kart
			if is_instance_valid(kart) and kart.is_inside_tree():
				result.append(kart.global_position)
				result.append(kart.global_position + kart.velocity * 2.0)
			var camera: Camera3D=game.local_players[slot].camera
			if is_instance_valid(camera) and camera.is_inside_tree():result.append(camera.global_position)
	if result.is_empty():result.append(game.circuit.sample(0))
	return result
func priority(center: Vector3) -> float:
	var score:=INF
	for slot in game.human_count:
		var local: LeoLocalPlayer=game.local_players[slot]
		if not is_instance_valid(local.kart) or not local.kart.is_inside_tree():continue
		var kart: LeoKart=local.kart
		var future:=kart.global_position+kart.velocity*4.
		score=minf(score,minf(center.distance_to(kart.global_position),center.distance_to(future)*.8))
	return score

func wanted(center: Vector3, distance: float, positions: Array[Vector3]) -> bool:
	for position in positions:
		if Vector2(position.x-center.x,position.z-center.z).length()<distance:return true
	return false

func _process(dt: float) -> void:
	if halted or not is_instance_valid(game):return
	update_view_distance()
	if busy:return
	timer+=dt
	if timer>.25:timer=0.;refresh()

func update_view_distance() -> void:
	var distance: float = VIEW_DISTANCES[game.graphics.draw_distance]
	if distance == view_distance:return
	view_distance=distance
	for material in fade_materials.values():
		set_fade_band(material)
	timer=.25

func set_fade_band(material: BaseMaterial3D) -> void:
	material.distance_fade_min_distance=view_distance
	material.distance_fade_max_distance=view_distance-FADE_WIDTH

func refresh(initial: bool = false) -> void:
	if busy or halted:return
	busy=true
	var positions:=anchors()
	var load_radius := view_distance + PRELOAD_MARGIN
	var unload_radius := load_radius + EVICT_MARGIN
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
					began=Time.get_ticks_usec();LeoSceneInstances.restore_one(item);LeoAssets.apply_overrides(item,false)
					if item is MeshInstance3D:
						apply_distance_fade(item)
					LeoPreparationBudget.record(began)
				if halted:node.free();break
				await LeoPreparationBudget.checkpoint(get_tree())
				began=Time.get_ticks_usec();add_child(node);LeoPreparationBudget.record(began);loaded[id]=node;stats.loads+=1
				stats.peak_cells=maxi(stats.peak_cells,loaded.size())
				await get_tree().process_frame
	busy=false

func faded_material(material: BaseMaterial3D) -> BaseMaterial3D:
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		return material
	if not fade_materials.has(material):
		var faded := material.duplicate() as BaseMaterial3D
		faded.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		set_fade_band(faded)
		fade_materials[material] = faded
	return fade_materials[material]

func apply_distance_fade(mesh: MeshInstance3D) -> void:
	# Terrain, road shaders and transparent materials keep their authored treatment.
	if not mesh.mesh or mesh.has_meta("surface_role"):
		return
	if mesh.material_override is BaseMaterial3D:
		mesh.material_override = faded_material(mesh.material_override)
	elif not mesh.material_override:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material:
				mesh.set_surface_override_material(surface, faded_material(material))

func stop() -> void:
	halted=true
	while busy:await get_tree().process_frame
