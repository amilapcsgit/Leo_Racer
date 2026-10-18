extends SceneTree
## Diagnostic captures only. All variants duplicate runtime resources; source stays intact.
var game: Node3D
var road: MeshInstance3D
var original: ShaderMaterial
var saved_ssr := false
var suns: Array[DirectionalLight3D] = []
var probes: Array[ReflectionProbe] = []
var images: Array[String] = []
const OUT := "res://build/astra-road-probe"
func _initialize() -> void: run.call_deferred()
func collect(node: Node) -> void:
	if node is DirectionalLight3D:suns.append(node)
	if node is ReflectionProbe:probes.append(node)
	for child in node.get_children():collect(child)
func variant(code: String) -> void:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	for pair in [["color_map","Color"],["normal_map","NormalGL"],["rough_map","Roughness"]]:
		material.set_shader_parameter(pair[0],load("res://assets/materials/Asphalt023S_2K-JPG_%s.jpg"%pair[1]))
	material.set_shader_parameter("base_roughness",.35)
	road.material_override = material
func capture(label: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label+".png")
	images.append(label)
	print("ROAD_PROBE_CAPTURE ",label)
func restore() -> void:
	road.material_override=original
	game.environment.ssr_enabled=saved_ssr
	for sun in suns:sun.shadow_enabled=true
	for probe in probes:probe.visible=true
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hud.photo_mode=true
	game.hud.hud_root.hide()
	game.hud.menu_root.hide()
	collect(game)
	road=game.world.find_child("AstraContinuousAsphalt",true,false)
	original=road.material_override
	saved_ssr=game.environment.ssr_enabled
	var decals := get_nodes_in_group("astra_road_decal")
	var p: Vector3=decals[0].global_position
	game.camera.global_position=p+Vector3(0,8,7)
	game.camera.look_at(p)
	game.camera.fov=56
	await capture("00-baseline")
	var code := original.shader.code
	variant(code.replace("NORMAL_MAP_DEPTH=mix(.40,.12,wet);","NORMAL_MAP_DEPTH=0.0;"))
	await capture("01-zero-normal-depth")
	restore()
	game.environment.ssr_enabled=false
	await capture("02-no-ssr")
	restore()
	var world_basis := code.replace("void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}","void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;TANGENT=vec3(1.0,0.0,0.0);BINORMAL=vec3(0.0,0.0,1.0);}")
	variant(world_basis)
	await capture("03-world-tangent-basis")
	restore()
	for sun in suns:sun.shadow_enabled=false
	await capture("04-no-directional-shadows")
	restore()
	for probe in probes:probe.visible=false
	await capture("05-no-probes")
	restore()
	variant(code.replace("float wet=smoothstep(.36,.65,noise(wp.xz*.12));","float wet=0.5;"))
	await capture("06-constant-wetness")
	restore()
	variant(code.replace("NORMAL_MAP=texture(normal_map,uv).rgb;", "").replace("NORMAL_MAP_DEPTH=mix(.40,.12,wet);", ""))
	await capture("09-no-normal-output")
	restore()
	variant(code.replace("ALBEDO = base*vec3(.43)*mix(1.0,.76,wet)*(.95+grain*.10);", "ALBEDO=vec3(.08);"))
	await capture("10-flat-albedo")
	restore()
	variant(code.replace("ROUGHNESS = clamp(base_roughness+mix(.06,-.08,wet)+(texture(rough_map,uv).r-.5)*.06,.20,.55);", "ROUGHNESS=.35;"))
	await capture("11-constant-roughness")
	restore()
	variant(code.replace("ALBEDO = base*vec3(.43)*mix(1.0,.76,wet)*(.95+grain*.10);", "ALBEDO=base*vec3(.43);"))
	await capture("12-albedo-texture-only")
	restore()
	variant(code.replace("NORMAL_MAP=texture(normal_map,uv).rgb;", "").replace("NORMAL_MAP_DEPTH=mix(.40,.12,wet);", "").replace("ROUGHNESS = clamp(base_roughness+mix(.06,-.08,wet)+(texture(rough_map,uv).r-.5)*.06,.20,.55);", "ROUGHNESS=.35;"))
	await capture("13-fixed-light-inputs")
	restore()
	variant("shader_type spatial; render_mode unshaded; uniform sampler2D color_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){ALBEDO=texture(color_map,wp.xz/1.25).rgb;}")
	await capture("14-unshaded-texture")
	restore()
	variant(code.replace("shader_type spatial;", "shader_type spatial; render_mode unshaded;").replace("ALBEDO = base*vec3(.43)*mix(1.0,.76,wet)*(.95+grain*.10);", "ALBEDO=vec3(wet);"))
	await capture("15-debug-wetness")
	restore()
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(.11,.11,.11)
	mat.roughness=.4
	road.material_override=mat
	await capture("07-flat-standard-material")
	restore()
	game.world.find_child("SculptedAstraCoastAndGardenHills",true,false).visible=false
	await capture("08-no-ground-mesh")
	var arrays: Array=road.mesh.surface_get_arrays(0)
	var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var unique_tangent: Dictionary={}
	var unique_normal: Dictionary={}
	for i in range(100*6):
		var j := i*4
		unique_tangent[str(Vector4(tangents[j],tangents[j+1],tangents[j+2],tangents[j+3]))]=true
		unique_normal[str(normals[i])]=true
	FileAccess.open(OUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"camera":str(game.camera.position),"images":images,"straight_first100_normal_variants":unique_normal.keys(),"straight_first100_tangent_variants":unique_tangent.keys()},"  "))
	print("ROAD_PROBE_DONE | ",images)
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
