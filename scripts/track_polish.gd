class_name LeoTrackPolish
extends RefCounted
## Runtime instance overrides; authored geometry, baked lights and sources survive.
static var profiles: Dictionary={}
const REVISION := 279
const ROAD_SHADER := preload("res://shaders/road_premium.gdshader")
static func install(world: Node3D, circuit: LeoCircuit) -> void:
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/track-polish-v1.json"))
	var id:=String(circuit.definition.id) if circuit.definition else "astra_coast"
	world.set_meta("polish_profile",profiles.get(id,{}))
	world.set_meta("polish_track_id",id)
	apply_nodes(world,world)
	# Streamed cells receive the same authored treatment when instantiated.
	var tree:=world.get_tree()
	var callback:=func(node: Node):
		if is_instance_valid(world) and node is GeometryInstance3D and world.is_ancestor_of(node):apply_node(node,world)
	tree.node_added.connect(callback)
	world.tree_exiting.connect(func():
		if tree.node_added.is_connected(callback):tree.node_added.disconnect(callback))
	if not world.has_node("SriLankaRoadside279"):
		var roadside:=load("res://scripts/racing/sri_roadside279.gd").new() as Node3D
		roadside.configure(circuit)
		world.add_child(roadside)
static func apply_nodes(root: Node, world: Node3D) -> void:
	for node in root.find_children("*","GeometryInstance3D",true,false):apply_node(node,world)
static func apply_node(node: GeometryInstance3D, world: Node3D) -> void:
	# Compiled lighting cells carry the older boolean tag. Upgrade their surface
	# too, while preserving the near/far lighting partition in their shader.
	if int(node.get_meta("polish_revision",0))==REVISION:return
	var profile: Dictionary=world.get_meta("polish_profile",{})
	var mesh: Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
	if not mesh:return
	node.set_meta("polish_applied",true)
	node.set_meta("polish_revision",REVISION)
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
		# Roads include authored city asphalt and precompiled lighting partitions.
		# Explicit signatures avoid reclassifying paving, paint and vehicle materials.
		if is_road_shader(old.shader):
			material=road_material(old,profile,world)
			node.set_meta("road_surface279",true)
			if not node.has_meta("street_receiver"):node.set_meta("street_receiver",true)
		elif String(node.get_meta("surface_role","")) in ["terrain_verge","terrain_detail","terrain_backdrop"]:
			material=old.duplicate() as ShaderMaterial;material.shader=preload("res://shaders/ground_premium.gdshader")
			if old.get_shader_parameter("ground_albedo")==null:material.set_shader_parameter("ground_albedo",preload("res://assets/materials/Concrete034_2K-JPG_Color.jpg"))
			if old.get_shader_parameter("ground_normal")==null:material.set_shader_parameter("ground_normal",preload("res://assets/materials/Concrete034_2K-JPG_NormalGL.jpg"))
			material.set_shader_parameter("coastal",String(world.get_meta("polish_track_id",""))=="astra_coast")
		elif String(node.get_meta("surface_role",""))=="water" or node.name=="KandyLakeColomboWater":
			material=old.duplicate() as ShaderMaterial
			material.set_shader_parameter("deep_color",Color(profile.get("water_deep","1e5057")))
			material.set_shader_parameter("shallow_color",Color(profile.get("water_shallow","508b7d")))
		if material:
			# RD may still inspect the outgoing geometry's material RIDs while
			# processing scene removal. Retire overrides after the render queue.
			retained.append(old);retained.append(material)
			put_material(node,surface,material)

static func is_road_shader(shader: Shader) -> bool:
	var code:=shader.code
	return (code.contains("float road_hash") and code.contains("uniform float base_roughness")) or (code.contains("uv=world.xz/1.5") and code.contains("color_map"))

static func road_material(original: ShaderMaterial, profile: Dictionary, world: Node3D) -> ShaderMaterial:
	var cache: Dictionary=world.get_meta("polish_road_materials279",{})
	var key:=original.get_instance_id()
	if cache.has(key):return cache[key]
	var material:=original.duplicate() as ShaderMaterial
	material.shader=partition_shader(original.shader,world)
	material.set_shader_parameter("base_roughness",maxf(.68,float(profile.get("road_roughness",.72))))
	material.set_shader_parameter("base_albedo_gain",float(profile.get("road_albedo_gain",.43)))
	material.set_shader_parameter("wetness",clampf(float(profile.get("road_wetness",0.)),0.,1.))
	material.set_shader_parameter("detail_strength",.28)
	cache[key]=material;world.set_meta("polish_road_materials279",cache)
	return material

static func partition_shader(original: Shader, world: Node3D) -> Shader:
	var compact:=original.code.replace(" ","").replace("\t","").replace("\n","").replace("\r","")
	var guard:=""
	for expression in ["length(VERTEX)>150.","length(VERTEX)<=150."]:
		if compact.contains("if("+expression+")discard;"):guard="if("+expression+")discard;";break
	if guard.is_empty():return ROAD_SHADER
	var cache: Dictionary=world.get_meta("polish_partition_shaders279",{})
	if not cache.has(guard):
		var shader:=Shader.new();shader.code=ROAD_SHADER.code.replace("void fragment(){","void fragment(){"+guard)
		cache[guard]=shader;world.set_meta("polish_partition_shaders279",cache)
	return cache[guard]
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
	if node is MeshInstance3D:
		if node.material_override:
			var original:=node.material_override
			for index in node.mesh.get_surface_count():node.set_surface_override_material(index,original)
			node.material_override=null
		node.set_surface_override_material(surface,material)
	elif node is MultiMeshInstance3D:
		if not node.has_meta("polish_mesh_instance"):
			var original: MultiMesh=node.multimesh
			var instances:=MultiMesh.new();instances.transform_format=original.transform_format
			instances.use_colors=original.use_colors;instances.use_custom_data=original.use_custom_data
			instances.mesh=original.mesh.duplicate();instances.instance_count=original.instance_count
			instances.custom_aabb=original.custom_aabb;instances.visible_instance_count=original.visible_instance_count
			var buffer: PackedFloat32Array=node.get_meta("instance_buffer",original.buffer)
			var stride:=(12 if original.transform_format==MultiMesh.TRANSFORM_3D else 8)+(4 if original.use_colors else 0)+(4 if original.use_custom_data else 0)
			if buffer.size()==original.instance_count*stride:instances.buffer=buffer
			else:
				for index in original.instance_count:
					if original.transform_format==MultiMesh.TRANSFORM_3D:instances.set_instance_transform(index,original.get_instance_transform(index))
					else:instances.set_instance_transform_2d(index,original.get_instance_transform_2d(index))
					if original.use_colors:instances.set_instance_color(index,original.get_instance_color(index))
					if original.use_custom_data:instances.set_instance_custom_data(index,original.get_instance_custom_data(index))
			node.multimesh=instances;node.material_override=null;node.set_meta("polish_mesh_instance",true)
		node.multimesh.mesh.surface_set_material(surface,material)
