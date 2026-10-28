class_name LeoTrackIllumination
extends Node3D
## Fixture identities come from exported lamp hardware; beams are a bounded pool.
var game: Node3D
var anchors: Array[Dictionary]=[]
var pool: Array[SpotLight3D]=[]
var assignments: Array[int]=[]
var levels: Array[float]=[]
var faces: Array[StandardMaterial3D]=[]
var leds: Array[ShaderMaterial]=[]
var night_gain:=-1.
var animation_clock:=0.
var refresh_clock:=0.
var fixture_mesh: MultiMeshInstance3D
var settings: Dictionary={}
func setup(owner_game: Node3D) -> void:
	game=owner_game;name="TrackIllumination"
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/race-environments-v1.json"))
	settings=profiles.get(game.chosen_track_id,{})
	var tower: Node=game.world.get_node_or_null("AuthenticLotusTower")
	if tower:bind_tower(tower)
	if game.chosen_track_id=="astra_coast":return
	# A compiler emits exact hardware positions, including reserved-area exclusions.
	var path: String=game.track_definition.folder.path_join(String(settings.get("fixture_data","illumination.json")))
	if FileAccess.file_exists(path):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("fixtures") is Array and data.fixtures.size()<=4096:
			for entry in data.fixtures:
				if entry is Dictionary and LeoVehicleLibrary.finite_vector(entry.get("position")) and LeoVehicleLibrary.finite_vector(entry.get("target")):anchors.append(entry)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(settings.get("emission",{}).get("lamp_color","fff0c9"));material.emission_enabled=true;material.emission=Color("ffe4b2");material.set_meta("night_energy",float(settings.get("emission",{}).get("lamp_energy",1.8)));faces.append(material)
	var mesh:=BoxMesh.new();mesh.size=Vector3(1.45,.035,.34);mesh.material=material
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=anchors.size()
	for i in anchors.size():mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,float(anchors[i].get("yaw",0.))),LeoVehicleCodec.vector(anchors[i].position)-Vector3.UP*.08))
	fixture_mesh=MultiMeshInstance3D.new();fixture_mesh.multimesh=mm;fixture_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(fixture_mesh)
	build_advertising()
	var compatible: bool=RenderingServer.get_current_rendering_method()=="gl_compatibility"
	var tier: int=clampi(game.graphics_quality,0,2)
	var light_settings: Dictionary=settings.get("street_lights",{})
	var count: int=light_settings.get("compatibility" if compatible else "forward_plus",[8,16,16] if compatible else [12,24,32])[tier]
	for i in count:
		var light:=SpotLight3D.new();light.light_color=Color(light_settings.get("color","ffdeb0"));light.spot_range=float(light_settings.get("range",20.));light.spot_angle=float(light_settings.get("angle",30.));light.spot_attenuation=.65
		light.shadow_enabled=false;light.light_energy=0.;light.light_cull_mask=1<<16
		add_child(light);pool.append(light);assignments.append(-1);levels.append(0.)
	if not game.get_tree().node_added.is_connected(on_node_added):game.get_tree().node_added.connect(on_node_added)
	for node in [game.world]+game.world.find_children("*","Node",true,false):on_node_added(node)
func on_node_added(node: Node) -> void:
	if not is_instance_valid(game) or not game.is_ancestor_of(node):return
	if node is GeometryInstance3D and not node is GPUParticles3D:
		var vehicle:=false;var ancestor:=node.get_parent()
		while ancestor and ancestor!=game:
			if ancestor.has_meta("vehicle_id"):vehicle=true;break
			ancestor=ancestor.get_parent()
		node.layers=(node.layers|(1<<16)) if vehicle or bool(node.get_meta("street_receiver",false)) else (node.layers & ~(1<<16))
func advertising_batch(mesh: Mesh,poses: Array[Transform3D],label: String) -> void:
	if poses.is_empty():return
	var batch:=MultiMeshInstance3D.new();batch.name=label;var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=mesh;instances.instance_count=poses.size();batch.multimesh=instances
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch);LeoSceneInstances.store(batch,poses)
func build_advertising() -> void:
	var frames: Array[Transform3D]=[];var designs: Array=[[],[],[],[]]
	for i in anchors.size():
		if i%3!=1:continue
		var position:=LeoVehicleCodec.vector(anchors[i].position)-Vector3.UP*2.7
		var projection: Dictionary=game.circuit.project(position);var forward: Vector3=game.circuit.direction(projection.distance)
		var frame:=Transform3D(Basis(Vector3.UP,atan2(-forward.x,-forward.z)),position);frames.append(frame)
		for side in [-1,1]:designs[i%4].append(frame*Transform3D(Basis(Vector3.UP,PI if side<0 else 0.),Vector3(0,0,side*.08)))
	var box:=BoxMesh.new();box.size=Vector3(1.43,2.65,.14);box.material=LeoRaceVisuals.flat_material(Color("182b32"),.5);advertising_batch(box,frames,"AdvertisingFrames")
	for design in 4:
		var material:=StandardMaterial3D.new();material.albedo_texture=load(LeoSriLankaWorld.ART+LeoSriLankaWorld.PORTRAITS[design]+".png")
		material.albedo_color=Color(.92,.92,.92);material.emission_enabled=true;material.emission=Color.WHITE;material.emission_texture=material.albedo_texture
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC;material.set_meta("night_energy",float(settings.get("emission",{}).get("billboard_energy",1.2)));faces.append(material)
		var quad:=QuadMesh.new();quad.size=Vector2(1.25,2.5);quad.material=material;var poses: Array[Transform3D]=[];poses.assign(designs[design]);advertising_batch(quad,poses,"AdvertisingFaces%d"%design)
func bind_tower(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var original:=node.get_active_material(i) as BaseMaterial3D
			if not original:continue
			var key:=String(original.resource_name)
			var target: Dictionary={}
			for entry in settings.get("landmark_led",{}).get("materials",[]):
				if entry.get("name","")==key:target=entry;break
			if target.is_empty():continue
			var led:=ShaderMaterial.new();led.shader=preload("res://shaders/lotus_led.gdshader")
			led.resource_name="LotusLED_"+key;led.set_shader_parameter("base_color",original.albedo_color)
			led.set_shader_parameter("led_color",Color(target.get("color","53d9d5")))
			led.set_shader_parameter("pattern",float(target.get("pattern",0.)));node.set_surface_override_material(i,led);leds.append(led)
	for child in node.get_children():bind_tower(child)
func set_gain(value: float) -> void:
	if is_equal_approx(night_gain,value):return
	night_gain=value
	for material in faces:material.emission_energy_multiplier=lerpf(.35,float(material.get_meta("night_energy",1.8)),value)
	for material in leds:material.set_shader_parameter("night_gain",lerpf(.12,1.,value))
func update(dt: float,frozen: bool) -> void:
	if frozen:return
	budget_headlights()
	animation_clock+=dt
	var period: float=settings.get("landmark_led",{}).get("period_seconds",12.)
	for material in leds:material.set_shader_parameter("phase",0. if game.reduced_motion else fmod(animation_clock,period)/period)
	if pool.is_empty():return
	refresh_clock-=dt
	if refresh_clock<=0.:refresh_clock=.2;assign_nearest()
	for i in pool.size():
		var desired:=0.
		if assignments[i]>=0:
			var distance:=nearest_distance(LeoVehicleCodec.vector(anchors[assignments[i]].position))
			desired=(1.-smoothstep(65.,95.,distance))*night_gain
		levels[i]=move_toward(levels[i],desired,dt/(.3 if desired>levels[i] else .2))
		pool[i].light_energy=levels[i]*float(settings.get("street_lights",{}).get("energy",3.4))
func budget_headlights() -> void:
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":return
	var available:=4
	var order: Array=game.karts.duplicate()
	order.sort_custom(func(a,b):return (0. if a.is_player else 10000.)+nearest_distance(a.global_position)<(0. if b.is_player else 10000.)+nearest_distance(b.global_position))
	for kart in order:
		if not kart.vehicle_lighting:continue
		var lights: LeoVehicleFeatures=kart.vehicle_lighting
		var allowed:=available>=lights.headlights.size()
		lights.set_headlight_projection(allowed)
		if allowed:available-=lights.headlights.size()
func nearest_distance(point: Vector3) -> float:
	var result:=INF
	for slot in int(game.human_count):
		var local: LeoLocalPlayer=game.local_players[slot]
		if is_instance_valid(local.camera):result=minf(result,local.camera.global_position.distance_to(point))
	return result
func assign_nearest() -> void:
	var order: Array[int]=[]
	for i in anchors.size():
		if nearest_distance(LeoVehicleCodec.vector(anchors[i].position))<105.:order.append(i)
	order.sort_custom(func(a,b):return nearest_distance(LeoVehicleCodec.vector(anchors[a].position))<nearest_distance(LeoVehicleCodec.vector(anchors[b].position)))
	order.resize(mini(order.size(),pool.size()))
	for i in pool.size():
		if assignments[i] in order:continue
		if levels[i]>.01:assignments[i]=-1;continue
		assignments[i]=-1
		for candidate in order:
			if candidate in assignments:continue
			assignments[i]=candidate;var point:=LeoVehicleCodec.vector(anchors[candidate].position);pool[i].global_position=point
			pool[i].look_at(LeoVehicleCodec.vector(anchors[candidate].target),Vector3.UP);break
