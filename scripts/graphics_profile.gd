class_name LeoGraphics
extends RefCounted
const NAMES := ["Low","Medium","High"]

static func apply(world: Node3D, environment: Environment, quality: int, split: bool, showroom: bool = false) -> void:
	var tier := mini(quality,1) if split else clampi(quality,0,2)
	var forward := RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.ssao_enabled=forward and tier>0
	environment.ssao_radius=.8;environment.ssao_intensity=.65
	environment.glow_enabled=tier>0
	environment.glow_intensity=.4;environment.glow_bloom=.035
	environment.adjustment_saturation=1.03;environment.adjustment_contrast=1.02
	environment.ssr_enabled=forward and tier==2 and not showroom
	environment.volumetric_fog_enabled=forward and tier==2 and not showroom
	environment.volumetric_fog_density=.002 if tier==2 else 0.
	environment.volumetric_fog_length=90.
	# Baked precincts contain their own lights. Preserve their authored state.
	var light := world.get_node_or_null("RaceSun") as DirectionalLight3D
	if light:
		light.shadow_enabled=true
		light.directional_shadow_max_distance=[65.,100.,140.][tier]
		light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		if not forward and split:
			light.directional_shadow_max_distance=minf(light.directional_shadow_max_distance,80.)
			light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	for probe in world.get_children():
		if probe is ReflectionProbe and String(probe.name).begins_with("RaceReflection"):
			probe.visible=tier>0
			# Two GLES viewports otherwise repeat expensive local captures. Keep
			# prefiltered sky reflections in split-screen; single-player keeps probes.
			if not forward and split:probe.queue_free()
		if probe is FogVolume and String(probe.name).begins_with("RaceMist"):probe.visible=forward and tier==2 and not showroom

static func install_reflections(world: Node3D, circuit: LeoCircuit) -> void:
	for fraction in [0.,.5]:
		var probe := ReflectionProbe.new()
		probe.name="RaceReflection"+str(int(fraction*2.))
		probe.position=circuit.sample(circuit.length*fraction)+Vector3.UP*4.
		probe.size=Vector3(150,40,150);probe.max_distance=100.
		probe.update_mode=ReflectionProbe.UPDATE_ONCE;probe.intensity=.65
		probe.enable_shadows=false
		world.add_child(probe)
		if RenderingServer.get_current_rendering_method()=="forward_plus":
			var mist := FogVolume.new()
			mist.name="RaceMist"+str(int(fraction*2.))
			mist.position=circuit.sample(circuit.length*fraction,circuit.width_at(circuit.length*fraction)*.5+6.)+Vector3.UP*1.5
			mist.size=Vector3(20,4,25);mist.visible=false
			var fog := FogMaterial.new();fog.density=.025;fog.albedo=Color("cfddd9")
			mist.material=fog;world.add_child(mist)
