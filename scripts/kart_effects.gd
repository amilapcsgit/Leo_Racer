class_name LeoKartEffects
extends Node3D
## Fixed-size presentation pools. Detached trails use world coordinates.
var kart: LeoKart
var smoke: Array[GPUParticles3D] = []
var impact_sparks: GPUParticles3D
var heat: Array[MeshInstance3D] = []
var marks: Array[MeshInstance3D] = []
var mark_cursor := 0
var mark_timer := 0.0
var previous := Vector3.ZERO
var elapsed := 0.0
var ribbons: Array[GPUParticles3D] = []
var trace_material: StandardMaterial3D

func setup(owner_kart: LeoKart) -> void:
	kart = owner_kart
	for side in [-1.0,1.0]:
		var ribbon := GPUParticles3D.new()
		ribbon.amount = 6
		ribbon.lifetime = .38
		ribbon.local_coords = false
		ribbon.emitting = false
		ribbon.position = Vector3(side*.5,.49,2.05)
		ribbon.trail_enabled = RenderingServer.get_current_rendering_method()!="gl_compatibility"
		ribbon.trail_lifetime = .28
		ribbon.visibility_aabb = AABB(Vector3(-10,-3,-15),Vector3(20,10,30))
		var trail_mesh := RibbonTrailMesh.new()
		trail_mesh.size = .13
		trail_mesh.sections = 10
		trail_mesh.section_segments = 2
		trail_mesh.section_length = .2
		var taper := Curve.new()
		taper.add_point(Vector2(0,1))
		taper.add_point(Vector2(1,0))
		trail_mesh.curve = taper
		var light := StandardMaterial3D.new()
		light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		light.albedo_color = Color("0bbccb")
		light.emission_enabled = true
		light.emission = Color("00b9d4")
		light.emission_energy_multiplier = 1.6
		light.use_particle_trails = true
		light.cull_mode = BaseMaterial3D.CULL_DISABLED
		trail_mesh.material = light
		if RenderingServer.get_current_rendering_method()=="gl_compatibility":
			ribbon.trail_enabled = false
			light.use_particle_trails = false
			var fallback := SphereMesh.new()
			fallback.radius = .045
			fallback.height = .09
			fallback.material = light
			ribbon.draw_pass_1 = fallback
		else:
			ribbon.draw_pass_1 = trail_mesh
		var rp := ParticleProcessMaterial.new()
		rp.direction = Vector3.BACK
		rp.spread = 4
		rp.gravity = Vector3.ZERO
		rp.initial_velocity_min = 5
		rp.initial_velocity_max = 8
		ribbon.process_material = rp
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ribbon)
		ribbons.append(ribbon)
		var emitter := GPUParticles3D.new()
		emitter.position = Vector3(side*1.05,.22,.95)
		emitter.amount = 22 if kart.is_player else 10
		emitter.lifetime = .75
		emitter.emitting = false
		emitter.local_coords = false
		emitter.visibility_aabb = AABB(Vector3(-12,-3,-15),Vector3(24,14,30))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0,.45,1)
		process.spread = 32
		process.initial_velocity_min = .5
		process.initial_velocity_max = 2.4
		process.gravity = Vector3(0,.45,0)
		process.scale_min = .30
		process.scale_max = .85
		var gradient := Gradient.new()
		gradient.set_color(0,Color(1,1,1,.7))
		gradient.set_color(1,Color(1,1,1,0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		process.color_ramp = ramp
		emitter.process_material = process
		var quad := QuadMesh.new()
		quad.size = Vector2(1,1)
		var soft := ShaderMaterial.new()
		soft.shader = load("res://shaders/particle_soft.gdshader")
		quad.material = soft
		emitter.draw_pass_1 = quad
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(emitter)
		smoke.append(emitter)
		if RenderingServer.get_current_rendering_method()=="forward_plus":
			var h := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(.65,2.0)
			h.mesh = q
			h.rotation_degrees.x = -55
			h.position = Vector3(side*.5,.6,2.6)
			var hm := ShaderMaterial.new()
			hm.shader = load("res://shaders/exhaust_heat.gdshader")
			h.material_override = hm
			h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(h)
			heat.append(h)
	impact_sparks = kart.make_particles(Vector3.ZERO)
	impact_sparks.reparent(self)
	impact_sparks.amount = 28
	impact_sparks.one_shot = true
	impact_sparks.explosiveness = 1.0
	impact_sparks.lifetime = .35
	impact_sparks.local_coords = false
	kart.impacted.connect(_impact)
	kart.recovered.connect(_recover)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("217b83")
	material.emission_enabled = true
	material.emission = Color("00b5c5")
	material.emission_energy_multiplier = 1.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace_material = material
	for i in range(64 if kart.is_player else 20):
		var mark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.13,.006,.8)
		mark.mesh = mesh
		mark.material_override = material
		mark.top_level = true
		mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mark.visible = false
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		marks.append(mark)
	previous = kart.global_position
	for flame in kart.flames:
		var cone := CylinderMesh.new()
		cone.top_radius = .015
		cone.bottom_radius = .18
		cone.height = .85
		cone.radial_segments = 16
		flame.mesh = cone
		(flame.material_override as StandardMaterial3D).emission_energy_multiplier = 1.8
	for trail in kart.exhaust_trails:
		trail.amount = 18
		var mesh := trail.draw_pass_1 as SphereMesh
		mesh.radius = .028
		mesh.height = .056

func _process(dt: float) -> void:
	if not is_instance_valid(kart): return
	elapsed += dt
	previous = kart.global_position
	# The displacement-derived physics speed stays stable between rendered frames.
	var moving := absf(kart.wheel_motion_speed)>4.0
	var near := kart.is_player or get_viewport().get_camera_3d().global_position.distance_to(kart.global_position)<55
	for emitter in smoke: emitter.emitting = kart.drifting and moving and kart.active and near
	var charge_color := Color("00b9d4").lerp(Color("ffae36"),smoothstep(.65,2.5,kart.drift_charge))
	trace_material.emission = charge_color
	for spark in [kart.spark_left,kart.spark_right]:
		spark.emitting = kart.drifting and moving and kart.active and near and kart.drift_charge>.3
		(spark.draw_pass_1.material as StandardMaterial3D).emission = charge_color
	var gain := 1.0 if kart.boost_time>0 and kart.active else 0.0
	if kart.is_player and kart.get_parent().get("feedback"):
		gain = kart.get_parent().feedback.get_boost_gain() if kart.active else 0.0
	for item in heat:
		item.visible = gain>0 and near
		item.material_override.set_shader_parameter("gain",gain)
	for ribbon in ribbons: ribbon.emitting = gain>0 and near
	for i in kart.flames.size():
		var flame := kart.flames[i]
		flame.scale.z = 1.1+gain*.5
		var material := flame.material_override as StandardMaterial3D
		material.emission = Color("ffad38").lerp(Color("20dfff"),.55+.35*sin(elapsed*18))
	mark_timer -= dt
	if kart.drifting and moving and kart.active and near and mark_timer<=0:
		mark_timer = .045
		for side in [-1,1]:
			var mark := marks[mark_cursor]
			mark_cursor = (mark_cursor+1)%marks.size()
			mark.global_position = kart.visual.global_transform*Vector3(side*1.05,0,1.0)
			mark.global_position.y = .075
			mark.rotation = Vector3(0,kart.rotation.y+kart.visual.rotation.y,0)
			(mark.mesh as BoxMesh).size.z = maxf(.8,absf(kart.wheel_motion_speed)*.065)
			mark.set_meta("expires",elapsed+.9)
			mark.visible = true
	for mark in marks:
		if mark.visible and elapsed>float(mark.get_meta("expires",0)): mark.visible = false

func _impact(_kart: LeoKart, point: Vector3, _normal: Vector3, _strength: float) -> void:
	impact_sparks.global_position = point+Vector3.UP*.35
	impact_sparks.restart()

func _recover(_kart: LeoKart) -> void:
	for mark in marks: mark.visible = false
	for emitter in smoke: emitter.restart(); emitter.emitting=false
	for trail in kart.exhaust_trails: trail.restart(); trail.emitting=false
	for ribbon in ribbons: ribbon.restart(); ribbon.emitting=false
	previous = kart.global_position
