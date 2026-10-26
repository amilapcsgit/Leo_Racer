extends RefCounted
## One rig per local player; inputs and camera state never cross viewports.
var reverse_time := 0.
var reverse_view := false
var orbit := Vector2.ZERO
var orbit_idle := 2.
var angle := 0.
var pitch := 0.
var mode := "chase"

func advance(speed: float,input: LeoPlayerInput,dt: float) -> void:
	if speed<-.75:reverse_time+=dt
	else:reverse_time=0.
	if reverse_time>=.15:reverse_view=true
	if speed>.25 or (absf(speed)<.25 and input.value("accelerate")>.1):reverse_view=false
	var mouse := input.orbit_delta()
	var stick := Vector2(input.value("camera_right")-input.value("camera_left"),input.value("camera_down")-input.value("camera_up"))
	if input.orbit_dragging or mouse.length_squared()>.01 or stick.length_squared()>.001:
		if orbit_idle>=1.:orbit.x=angle
		orbit+=Vector2(-mouse.x*.006,-mouse.y*.004)+Vector2(-stick.x*2.,-stick.y*1.3)*dt
		orbit.y=clampf(orbit.y,-.2,.65);orbit_idle=0.
	else:orbit_idle+=dt
	var target := 0.
	var vertical := 0.
	if orbit_idle<1.:
		target=orbit.x;vertical=orbit.y;mode="orbit"
	elif input.value("look_back")>.5:target=PI;mode="look_back"
	elif reverse_view:target=PI;mode="reverse"
	else:mode="chase"
	angle=lerp_angle(angle,target,1.-exp(-dt*7.))
	pitch=lerpf(pitch,vertical,1.-exp(-dt*7.))

func update(local: LeoLocalPlayer,view: Camera3D,kart: LeoKart,input: LeoPlayerInput,dt: float,space: PhysicsDirectSpaceState3D,split: bool) -> void:
	advance(kart.speed,input,dt)
	var pose := kart.get_global_transform_interpolated()
	var yaw := local.heading+angle
	var behind := Vector3(sin(yaw),0,cos(yaw))
	var distance := 6.4+absf(kart.speed)*.012+(maxf(0.,kart.definition.collision_size.z-4.)*.5 if split else 0.)
	var pivot := pose.origin+Vector3.UP*(1.5+kart.camera_height_offset*.5)
	var desired := pose.origin+behind*distance*cos(pitch)+Vector3.UP*(3.1+kart.camera_height_offset+distance*sin(pitch))
	# Sweep a small volume, including on flat city courses. Exclude vehicle layer 2.
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new();sphere.radius=.25
	query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,pivot);query.motion=desired-pivot;query.collision_mask=1
	var safe := space.cast_motion(query)
	view.position=pivot+(desired-pivot)*(maxf(0.,safe[0]-.025) if safe.size()>0 else 1.)
	var focus := 6. if mode=="chase" else 1.5
	var target := pose.origin-behind*focus+Vector3.UP*(1.85+kart.camera_height_offset*.5)
	view.look_at(target)
