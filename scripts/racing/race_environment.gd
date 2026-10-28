class_name LeoRaceEnvironment
extends RefCounted
## One shared environment, driven only by validated checkpoint progress.
var progress := 0.0
var displayed := 0.0
var profile: Dictionary
var sky: ProceduralSkyMaterial
var environment: Environment
var sun: DirectionalLight3D
var night_lights: Array[Light3D]=[]
var light_energy: Array[float]=[]
var world: Node3D
var enabled := false
var original: Dictionary={}
var indirect: Dictionary={}
var probes: Dictionary={}
var last_applied := -1.0
var update_clock:=0.0
var sky_update_clock:=0.0
var last_sky_applied:=-1.0
var neutral: Dictionary={}
var authored_night_root: Node3D
var previous_world_environment: Environment
var extra_suns: Dictionary={}
func prepare(tree: SceneTree, track_id: String, dynamic: bool) -> bool:
	neutral.clear()
	if not dynamic:return true
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/race-environments-v1.json"))
	var settings: Dictionary=profiles.get(track_id,{})
	if not settings.has("neutral_manifest"):return true
	var file: String=settings.neutral_manifest
	if not FileAccess.file_exists(file):return false
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not manifest is Dictionary:return false
	for key in manifest:
		var path: String=manifest[key]
		if not path.begins_with("res://leo_environments/"+track_id+"/"):return false
		if ResourceLoader.load_threaded_request(path,"LightmapGIData")!=OK:return false
		while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await tree.process_frame
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return false
		neutral[key]=ResourceLoader.load_threaded_get(path)
	return true
func configure(target: Node3D, env: Environment, track_id: String, dynamic: bool) -> void:
	if is_instance_valid(world) and not original.is_empty():restore()
	elif not original.is_empty():original.clear();indirect.clear();probes.clear();extra_suns.clear();previous_world_environment=null
	world=target;environment=env;sun=world.get_node_or_null("RaceSun");enabled=dynamic
	progress=0.;displayed=0.;last_applied=-1.;update_clock=0.;sky_update_clock=0.;last_sky_applied=-1.;night_lights.clear();light_energy.clear()
	if not enabled:return
	original={}
	for field in ["sky","sky_rotation","ambient_light_source","ambient_light_color","ambient_light_energy","fog_light_color","fog_density"]:original[field]=environment.get(field)
	if sun:original.sun={"rotation_degrees":sun.rotation_degrees,"light_color":sun.light_color,"light_energy":sun.light_energy,"directional_shadow_mode":sun.directional_shadow_mode,"directional_shadow_max_distance":sun.directional_shadow_max_distance}
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/race-environments-v1.json"))
	previous_world_environment=world.get_world_3d().environment
	world.get_world_3d().environment=environment
	profile=profiles.get(track_id,profiles.astra_coast)
	sky=ProceduralSkyMaterial.new();var resource:=Sky.new();resource.sky_material=sky
	resource.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	var game:=world.get_parent()
	var tier:=mini(int(game.get("graphics_quality")),1) if int(game.get("human_count"))==2 else int(game.get("graphics_quality"))
	resource.radiance_size=Sky.RADIANCE_SIZE_64 if tier<=1 else Sky.RADIANCE_SIZE_256
	environment.sky=resource
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	if not world.get_tree().node_added.is_connected(on_node_added):world.get_tree().node_added.connect(on_node_added)
	collect(world)
	authored_night_root=Node3D.new();authored_night_root.name="DuskNightLights";world.add_child(authored_night_root)
	var circuit: LeoCircuit=world.get_parent().get("circuit")
	if circuit:
		for entry in profile.get("night_lights",[]):
			var light:=OmniLight3D.new();light.position=circuit.sample(circuit.length*float(entry.fraction),float(entry.offset))+Vector3.UP*float(entry.height)
			light.light_color=Color(entry.color);light.light_energy=float(entry.energy);light.omni_range=float(entry.range);light.shadow_enabled=false
			light.distance_fade_enabled=true;light.distance_fade_begin=85.;light.distance_fade_length=35.
			authored_night_root.add_child(light)
	apply()
	enforce_graphics()
func collect(node: Node) -> void:
	if node is ReflectionProbe and String(node.name).begins_with("RaceReflection"):
		probes[node]=node.visible;node.visible=false
	if node is DirectionalLight3D and node!=sun:
		extra_suns[node]=node.light_energy;node.light_energy=0.
	elif node is Light3D and node!=sun:
		node.add_to_group("race_night_lights")
		night_lights.append(node);light_energy.append(node.light_energy)
	if node is LightmapGI:
		var key:=String(node.get_parent().name)
		if neutral.has(key):indirect[node]=node.light_data;node.light_data=neutral[key]
	for child in node.get_children():collect(child)
func on_node_added(node: Node) -> void:
	if not enabled or not is_instance_valid(world) or not world.is_ancestor_of(node):return
	if node is LightmapGI:
		var key:=String(node.get_parent().name)
		if neutral.has(key):indirect[node]=node.light_data;node.light_data=neutral[key]
	elif node is WorldEnvironment:
		world.get_world_3d().environment=environment
	elif node is DirectionalLight3D and node!=sun:
		extra_suns[node]=node.light_energy;node.light_energy=0.
	elif node is Light3D and node!=sun:
		node.add_to_group("race_night_lights")
		night_lights.append(node);light_energy.append(node.light_energy)
func enforce_graphics() -> void:
	if not enabled or not is_instance_valid(world) or not world.is_inside_tree():return
	var game:=world.get_parent()
	var tier:=mini(int(game.get("graphics_quality")),1) if int(game.get("human_count"))==2 else int(game.get("graphics_quality"))
	if sun and tier<=1 and RenderingServer.get_current_rendering_method()=="forward_plus":
		sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_max_distance=minf(sun.directional_shadow_max_distance,80.)
	for probe in probes:
		if is_instance_valid(probe):probe.visible=false
func restore() -> void:
	for field in original:
		if field!="sun":environment.set(field,original[field])
	if is_instance_valid(sun) and original.has("sun"):
		for field in original.sun:sun.set(field,original.sun[field])
	for i in night_lights.size():
		if is_instance_valid(night_lights[i]):night_lights[i].light_energy=light_energy[i]
	for lightmap in indirect:
		if is_instance_valid(lightmap):lightmap.light_data=indirect[lightmap]
	for probe in probes:
		if is_instance_valid(probe):probe.visible=probes[probe]
	for light in extra_suns:
		if is_instance_valid(light):light.light_energy=extra_suns[light]
	extra_suns.clear()
	if is_instance_valid(world):world.get_world_3d().environment=previous_world_environment
	if is_instance_valid(authored_night_root):authored_night_root.free()
	original.clear();indirect.clear();probes.clear()
func reset() -> void:
	progress=0.;displayed=0.;last_applied=-1.;last_sky_applied=-1.;sky_update_clock=0.
	if enabled:apply()
func advance(karts: Array, dt: float, frozen: bool) -> void:
	if not enabled or frozen:return
	for kart in karts:
		if not is_instance_valid(kart) or kart.retired:continue
		progress=maxf(progress,clampf(float(kart.next_gate-1)/(LeoCircuit.GATES*3.),0.,1.))
	displayed=move_toward(displayed,progress,dt*.12)
	sky_update_clock+=dt
	update_clock+=dt
	if update_clock>=.1:
		update_clock=0.
		for i in range(night_lights.size()-1,-1,-1):
			if not is_instance_valid(night_lights[i]):night_lights.remove_at(i);light_energy.remove_at(i)
		for lightmap in indirect.keys():
			if not is_instance_valid(lightmap):indirect.erase(lightmap)
		apply()
func apply(force_sky: bool=false) -> void:
	if not force_sky and is_equal_approx(last_applied,displayed) and is_equal_approx(last_sky_applied,displayed):return
	last_applied=displayed
	var t:=smoothstep(0.,1.,displayed)
	# Directional-light changes also invalidate sky radiance. Update the coupled
	# sky/sun at 2 Hz; ambient, fog and authored night groups retain 10 Hz blending.
	if force_sky or last_sky_applied<0. or sky_update_clock>=.5:
		sky_update_clock=0.;last_sky_applied=displayed
		sky.sky_top_color=Color(profile.dusk_top).lerp(Color(profile.night_top),t)
		sky.sky_horizon_color=Color(profile.dusk_horizon).lerp(Color(profile.night_horizon),t)
		sky.ground_bottom_color=Color("11151f");sky.ground_horizon_color=sky.sky_horizon_color
		environment.sky_rotation=Vector3(0,displayed*.18,0)
		if sun:
			sun.rotation_degrees=Vector3(lerpf(-12.,8.,t),float(profile.sun_yaw),0)
			sun.light_color=Color("ffd2a2").lerp(Color("91b7ef"),t)
			sun.light_energy=lerpf(.8,.055,t)
	environment.ambient_light_color=Color("a99ba2").lerp(Color("526785"),t)
	environment.ambient_light_energy=lerpf(.48,.25,t)
	environment.fog_light_color=Color(profile.dusk_horizon).lerp(Color(profile.night_horizon),t);environment.fog_density=lerpf(.00065,.0013,t)
	for i in night_lights.size():
		if is_instance_valid(night_lights[i]):night_lights[i].light_energy=light_energy[i]*lerpf(.3,1.,smoothstep(.05,.65,t))
