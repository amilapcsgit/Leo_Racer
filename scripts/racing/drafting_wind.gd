class_name LeoDraftingWind
extends GPUParticles3D
var kart: LeoKart
func setup(source: LeoKart) -> void:
	kart=source;amount=18;lifetime=.35;emitting=false;local_coords=true
	visibility_aabb=AABB(Vector3(-3,-1,-5),Vector3(6,5,12))
	var process:=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(1.5,.7,1.8)
	process.direction=Vector3.BACK;process.spread=2.;process.gravity=Vector3.ZERO
	process.initial_velocity_min=13.;process.initial_velocity_max=20.
	process.color=Color(.65,.85,1.,.22);process_material=process
	var line:=BoxMesh.new();line.size=Vector3(.008,.008,.65)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(.65,.85,1.,.22)
	line.material=material;draw_pass_1=line;position.y=1.1
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _process(_dt: float) -> void:
	layers=1<<(18+kart.local_slot)
	var game:=kart.get_parent()
	var reduced:=bool(game.get("reduced_motion"))
	var photo:=false
	if game.get("local_players")!=null:
		photo=game.local_players[kart.local_slot].photo
	emitting=kart.drafting and kart.active and not reduced and not photo and not get_tree().paused
	if not emitting:amount_ratio=0.
	else:amount_ratio=1.
func reset() -> void:
	emitting=false;restart()
