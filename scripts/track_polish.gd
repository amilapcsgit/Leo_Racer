class_name LeoTrackPolish
extends RefCounted
## Runtime instance overrides; authored geometry, baked lights and sources survive.
static var profiles: Dictionary={}
static func install(world: Node3D, circuit: LeoCircuit) -> void:
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/track-polish-v1.json"))
	var id:=String(circuit.definition.id) if circuit.definition else "astra_coast"
	world.set_meta("polish_profile",profiles.get(id,{}))
	apply_nodes(world,world)
	# Streamed cells receive the same authored treatment when instantiated.
	var tree:=world.get_tree()
	var callback:=func(node: Node):
		if is_instance_valid(world) and node is GeometryInstance3D and world.is_ancestor_of(node):apply_node(node,world)
	tree.node_added.connect(callback)
	world.tree_exiting.connect(func():
		if tree.node_added.is_connected(callback):tree.node_added.disconnect(callback))
static func apply_nodes(root: Node, world: Node3D) -> void:
	for node in root.find_children("*","GeometryInstance3D",true,false):apply_node(node,world)
static func apply_node(node: GeometryInstance3D, world: Node3D) -> void:
	if node.has_meta("polish_applied"):return
	node.set_meta("polish_applied",true)
	var profile: Dictionary=world.get_meta("polish_profile",{})
	var mesh: Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
	if not mesh:return
	# Streamed cells retire independently, so long sessions do not accumulate
	# materials for cells which have already left the world.
	var retained: Array=[]
	var tree:=world.get_tree()
	node.tree_exiting.connect(func():retire_materials(retained,tree))
	var plant_assets: Array=["res://assets/models/colombo/shade_tree_0.res","res://assets/models/colombo/shade_tree_1.res","res://assets/models/colombo/shade_tree_2.res","res://assets/models/colombo/bush_common.glb","res://shared/landmarks/forest.glb"]
	var plant:=String(node.get_meta("shared_asset","")) in plant_assets
	if plant:
		node.visibility_range_end_margin=maxf(node.visibility_range_end_margin,40.)
		if RenderingServer.get_current_rendering_method()=="forward_plus":node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var original_override: Material=node.material_override
	for surface in mesh.get_surface_count():
		var old: Material=node.get_active_material(surface) if node is MeshInstance3D else (original_override if original_override else mesh.surface_get_material(surface))
		if plant and old is StandardMaterial3D:
			var foliage:=old.duplicate() as StandardMaterial3D
			foliage.albedo_color=old.albedo_color*Color(.91,.96,.87,1.)
			foliage.roughness=maxf(foliage.roughness,.8)
			put_material(node,surface,foliage)
		if not old is ShaderMaterial or not old.shader:continue
		var material: ShaderMaterial
		# This is the authored shared asphalt shader signature, not a name heuristic.
		if old.shader.code.contains("float road_hash") and old.shader.code.contains("uniform float base_roughness"):
			material=old.duplicate() as ShaderMaterial
			material.shader=preload("res://shaders/road_premium.gdshader")
			material.set_shader_parameter("base_roughness",float(profile.get("road_roughness",.7)))
			material.set_shader_parameter("base_albedo_gain",float(profile.get("road_albedo_gain",.43)))
		elif old.shader.code.contains("uv=world.xz/1.5") and old.shader.code.contains("color_map"):
			material=old.duplicate() as ShaderMaterial;material.shader=preload("res://shaders/city_road.gdshader")
		elif String(node.get_meta("surface_role","")) in ["terrain_verge","terrain_detail","terrain_backdrop"]:
			material=old.duplicate() as ShaderMaterial;material.shader=preload("res://shaders/ground_premium.gdshader")
		elif String(node.get_meta("surface_role",""))=="water" or node.name=="KandyLakeColomboWater":
			material=old.duplicate() as ShaderMaterial
			material.set_shader_parameter("deep_color",Color(profile.get("water_deep","1e5057")))
			material.set_shader_parameter("shallow_color",Color(profile.get("water_shallow","508b7d")))
		if material:
			# RD may still inspect the outgoing geometry's material RIDs while
			# processing scene removal. Retire overrides after the render queue.
			retained.append(old);retained.append(material)
			put_material(node,surface,material)
static func retire_materials(materials: Array, tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame
	materials.clear()
static func lighting(world: Node3D, environment: Environment) -> void:
	var profile: Dictionary=world.get_meta("polish_profile",{})
	if profile.is_empty():return
	environment.tonemap_exposure=float(profile.exposure)
	environment.adjustment_saturation=float(profile.saturation)
	environment.adjustment_contrast=1.035
	environment.glow_intensity=.28
	var sun:=world.get_node_or_null("RaceSun") as DirectionalLight3D
	if sun:
		sun.shadow_bias=.025;sun.shadow_normal_bias=.65
static func reflection_positions(circuit: LeoCircuit) -> Array:
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/track-polish-v1.json"))
	var id:=String(circuit.definition.id) if circuit.definition else "astra_coast"
	return profiles.get(id,{}).get("reflection_stations",[.0,.5])

static func put_material(node: GeometryInstance3D, surface: int, material: Material) -> void:
	if node is MeshInstance3D:node.set_surface_override_material(surface,material)
	elif node is MultiMeshInstance3D:
		if not node.has_meta("polish_mesh_instance"):
			node.multimesh=node.multimesh.duplicate();node.multimesh.mesh=node.multimesh.mesh.duplicate();node.material_override=null;node.set_meta("polish_mesh_instance",true)
		node.multimesh.mesh.surface_set_material(surface,material)
