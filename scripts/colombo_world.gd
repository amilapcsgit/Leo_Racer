class_name LeoColomboWorld
extends Node3D
## Additive decoration. Does not add physics bodies or touch track vertices.
const DIR := "res://assets/models/colombo/"
var profile: LeoArtProfile
var circuit: LeoCircuit
var bins: Dictionary = {}
var models: Dictionary = {}
var count := 0

static func pbr_material(shader_path: String, asset: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	for pair in [["color_map","Color"],["normal_map","NormalGL"],["rough_map","Roughness"]]:
		m.set_shader_parameter(pair[0],load("res://assets/materials/%s_2K-JPG_%s.jpg"%[asset,pair[1]]))
	return m

static func environment_setup(env: Environment, sun: DirectionalLight3D, p: LeoArtProfile) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/colombo_sky.gdshader")
	material.set_shader_parameter("zenith",p.sky_top)
	material.set_shader_parameter("horizon",p.sky_horizon)
	material.set_shader_parameter("clouds",load("res://assets/art/lotus_coast_sky.png"))
	var sky := Sky.new()
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_energy = p.ambient_energy
	env.tonemap_exposure = p.exposure
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.10
	env.glow_intensity = p.bloom_intensity
	env.glow_bloom = .025
	env.glow_hdr_threshold = 1.25
	env.fog_light_color = p.haze_color
	env.fog_density = p.haze_density
	env.fog_sky_affect = .12
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.3
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssr_enabled = forward
	env.ssr_max_steps = 24
	env.ssr_fade_in = .18
	env.ssr_fade_out = 1.6
	env.volumetric_fog_enabled = forward
	env.volumetric_fog_density = .00008
	env.volumetric_fog_albedo = Color("d6a878")
	env.volumetric_fog_length = 210
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	sun.light_specular = .16
	sun.rotation_degrees = p.sun_angles
	sun.directional_shadow_max_distance = 130
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance = .8

func setup(track: LeoCircuit, p: LeoArtProfile) -> void:
	name = "Colombo2026"
	profile = p
	circuit = track
	_terrain()
	_foliage()
	_prom_details()
	_flush()
	_reflections()
	print("COLOMBO_WORLD_READY | new_instances=%d | spatial_batches=%d"%[count,bins.size()])

func _terrain() -> void:
	# Legacy authoring terrain is optional. Astra overrides this method with its
	# existing procedural mesh; Colombo uses baked scenery, so neither needs the DLL.
	if not ClassDB.class_exists("Terrain3D"):return
	if not ResourceLoader.exists("res://assets/terrain/terrain3d-2-2.res") and DirAccess.get_files_at("res://assets/terrain").is_empty(): return
	var t=ClassDB.instantiate("Terrain3D")
	t.name = "SculptedCoastalDunes"
	t.region_size = 256
	t.vertex_spacing = 1.0
	t.collision_mode = 0
	t.free_editor_textures = false
	t.mesh_lods = 5
	t.mesh_size = 24
	t.data_directory = "res://assets/terrain"
	t.material = ClassDB.instantiate("Terrain3DMaterial")
	t.assets = ClassDB.instantiate("Terrain3DAssets")
	var sand=ClassDB.instantiate("Terrain3DTextureAsset")
	sand.name = "Coastal sand"
	sand.albedo_color = Color("a98453")
	sand.albedo_texture = load("res://assets/materials/shore_AlbedoHeight.png")
	sand.normal_texture = load("res://assets/materials/shore_NormalRoughness.png")
	sand.normal_depth = .20
	sand.roughness = .85
	sand.uv_scale = .55
	t.assets.set_texture(0,sand)
	add_child(t)
	t.collision.mode = 0 # Terrain3DCollision.DISABLED
	t.material.set_shader_param("world_background",0)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		var haze := FogVolume.new()
		haze.name = "BayHaze"
		haze.position = Vector3(-210,8,-165)
		haze.size = Vector3(110,25,140)
		var fm := FogMaterial.new()
		fm.density = profile.bay_fog_density
		fm.albedo = profile.haze_color
		haze.material = fm
		add_child(haze)

func _load_model(key: String) -> Array:
	if models.has(key): return models[key]
	var result: Array = []
	if key.begins_with("shade_tree"):
		result.append([load(DIR+key+".res"),Transform3D.IDENTITY])
	else:
		var scene: Node3D = load(DIR+key+".glb").instantiate()
		_collect(scene,Transform3D.IDENTITY,result,key)
		scene.free()
	models[key] = result
	return result

func _collect(node: Node, parent_transform: Transform3D, result: Array, key: String) -> void:
	var tr := parent_transform
	if node is Node3D: tr = parent_transform*node.transform
	if node is MeshInstance3D:
		var mesh := node.mesh.duplicate() as Mesh
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface) as StandardMaterial3D
			if source and source.resource_name.contains("Palm_Leaf"):
				var leaf := ShaderMaterial.new()
				leaf.shader = load("res://shaders/foliage_wind.gdshader")
				leaf.set_shader_parameter("leaf_color",Color("3d762a") if source.resource_name.contains("Light") else Color("176337"))
				mesh.surface_set_material(surface,leaf)
		result.append([mesh,tr])
	for child in node.get_children(): _collect(child,tr,result,key)

func _instance(key: String, pos: Vector3, scale0: float, angle: float, far: bool=false) -> void:
	var transform0 := Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale0),pos)
	var tile := Vector2i(floori(pos.x/48),floori(pos.z/48))
	for entry in _load_model(key):
		var id := "%s_%d_%d_%d_%s"%[key,tile.x,tile.y,entry[0].get_instance_id(),str(far)]
		if not bins.has(id): bins[id] = {"mesh":entry[0],"transforms":[],"far":far,"tree":key.begins_with("shade_tree"),"origin":Vector3(tile.x*48+24,0,tile.y*48+24)}
		bins[id].transforms.append(transform0*entry[1])
	count += 1

func _foliage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261018
	for i in range(int(circuit.length/16.0)):
		var s := float(i)*16+8
		for side in [-1.0,1.0]:
			var p := circuit.sample(s,side*17.5)
			if p.x < -119: continue
			var angle := rng.randf()*TAU
			var palm_scale := .9+rng.randf()*.18
			_instance("palm_%d"%(i%3),p,palm_scale,angle)
			_instance("palm_%d_lod"%(i%3),p,palm_scale,angle,true)
			for j in range(4):
				var q := circuit.sample(s+j*2.5,side*(14.8+rng.randf()*1.3))
				_instance(["bush_common","plant_1","fern_1","bush_common_flowers"][(j+i)%4],q,.65+rng.randf()*.4,rng.randf()*TAU)
	for i in range(24):
		var a := float(i)*TAU/24
		var p := Vector3(cos(a)*41,0,-25+sin(a)*41)
		var projected := circuit.project(p)
		if p.distance_to(projected.center)>20:
			_instance("shade_tree_%d"%(i%3),p,.48+rng.randf()*.13,a)
	for i in range(32):
		var p := Vector3(-132+rng.randf()*5,.25,-170+i*10)
		_instance("rock_medium_%d"%(1+i%2),p,.25+rng.randf()*.35,rng.randf()*TAU)
		_instance("grass_wispy_short",p+Vector3(1,0,2),1.2,rng.randf()*TAU)

func _prom_details() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("183c44")
	metal.metallic = .65
	metal.roughness = .28
	var neon := StandardMaterial3D.new()
	neon.albedo_color = Color("00b9c4")
	neon.emission_enabled = true
	neon.emission = Color("00c8d6")
	neon.emission_energy_multiplier = 1.7
	for i in range(18):
		var s := float(i)*40+17
		var p := circuit.sample(s,25.0)
		if p.x < -110: continue
		_instance("tuk_tuk" if i%3 else "electric_car",p,1.0,atan2(circuit.direction(s).x,circuit.direction(s).z))
	for i in range(36):
		var s := float(i)*20+4
		var p := circuit.sample(s,-12.6)+Vector3.UP*3.8
		var t := circuit.direction(s)
		var board := Node3D.new()
		board.position = p
		board.rotation.y = atan2(-t.x,-t.z)
		add_child(board)
		LeoRaceVisuals.mesh_box(board,Vector3(1.1,2.3,.11),Vector3.ZERO,metal)
		LeoRaceVisuals.mesh_box(board,Vector3(1.15,.045,.15),Vector3(0,1.16,0),neon)
		var text := LeoRaceVisuals.label(board,"2026" if i%2 else "PORT CITY",Vector3(0,.65,.065),0,.95,Color("a5e6e3"))
		text.remove_from_group("race_sign_text")
		text.add_to_group("colombo_banner_text")
		var flag := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(.92,.63)
		flag.mesh = quad
		flag.position = Vector3(0,-.32,.065)
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = load("res://assets/art/colombo_banner.svg")
		fm.roughness = .7
		flag.material_override = fm
		board.add_child(flag)
	# Existing flat promenade remains; these raised terrace platforms are decorative.
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("9a8766")
	for i in range(9):
		LeoRaceVisuals.mesh_box(self,Vector3(6,.28,12),Vector3(-115,.17,-145+i*34),stone)

func _flush() -> void:
	for data in bins.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data.mesh
		mm.instance_count = data.transforms.size()
		for i in data.transforms.size():
			var tr: Transform3D = data.transforms[i]
			tr.origin -= Vector3(data.origin)
			mm.set_instance_transform(i,tr)
		var node := MultiMeshInstance3D.new()
		node.position = data.origin
		node.multimesh = mm
		node.visibility_range_end = 160 if not data.far else 285
		node.visibility_range_end_margin = 0
		if data.far: node.visibility_range_begin = 160
		if not data.tree and data.far: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func _reflections() -> void:
	if RenderingServer.get_current_rendering_method()!="forward_plus": return
	for i in range(3):
		var s := float(i)*circuit.length/3
		var probe := ReflectionProbe.new()
		probe.position = circuit.sample(s)+Vector3.UP*7
		probe.size = Vector3(155,45,155)
		probe.origin_offset = Vector3(0,5,0)
		probe.max_distance = 190
		probe.intensity = .7
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.enable_shadows = false
		add_child(probe)
