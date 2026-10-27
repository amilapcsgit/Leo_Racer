extends RefCounted
## One rig per local player; inputs and camera state never cross viewports.
var reverse_time := 0.
var reverse_view := false
var orbit := Vector2.ZERO
var orbit_idle := 2.
var angle := 0.
var pitch := 0.
var mode := "chase"
var follow_position := Vector3.ZERO
var follow_velocity := Vector3.ZERO
var look_ahead := Vector3.ZERO
var warm := false

func reset() -> void:
	warm=false;follow_velocity=Vector3.ZERO;look_ahead=Vector3.ZERO

static func field_of_view(speed: float, boost: float, reduced: bool, base: float = 63.) -> float:
	return base if reduced else clampf(base+10.*smoothstep(0.,50.,absf(speed))+boost,base,85.)

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

func update(local: LeoLocalPlayer,view: Camera3D,kart: LeoKart,input: LeoPlayerInput,dt: float,space: PhysicsDirectSpaceState3D,split: bool,reduced: bool = false) -> void:
	advance(kart.speed,input,dt)
	var pose := kart.get_global_transform_interpolated()
	var yaw := (pose.basis.get_euler().y if reduced else local.heading)+angle
	var behind := Vector3(sin(yaw),0,cos(yaw))
	var box:=body_bounds(kart)
	var center:=box.get_center()
	var origin:=pose.origin+pose.basis*Vector3(center.x,0.,center.z)
	var distance := 6.4+(0. if reduced else absf(kart.wheel_motion_speed)*.012)+maxf(0.,maxf(box.size.z,kart.definition.collision_size.z)-3.5)*.7
	# Bounds-based clearance also protects long imports in single-player. A
	# narrower selected FOV must still contain the vehicle at rest.
	distance*=maxf(1.,tan(deg_to_rad(63.)*.5)/tan(deg_to_rad(view.fov)*.5))
	var desired := origin+behind*distance*cos(pitch)+Vector3.UP*(3.1+kart.camera_height_offset+distance*sin(pitch))
	if not warm or follow_position.distance_to(desired)>25. or mode!="chase" or reduced:
		follow_position=desired;follow_velocity=Vector3.ZERO;warm=true
	else:
		# Exact critically damped spring step; independent of rendering frequency.
		var displacement := follow_position-desired
		var step := (follow_velocity+displacement*12.)*dt
		follow_position=desired+(displacement+step)*exp(-12.*dt)
		follow_velocity=(follow_velocity-step*12.)*exp(-12.*dt)
	view.position=follow_position
	var focus := 6. if mode=="chase" else 1.5
	var ahead := Vector3.ZERO
	if mode=="chase" and not reduced:
		var velocity := kart.velocity;velocity.y=0.
		ahead=velocity.limit_length(50.)*.065
		var apex := kart.circuit.direction(kart.last_s+maxf(10.,absf(kart.speed)*.45))
		ahead+=apex*clampf(absf(kart.speed)*.035,0.,1.5)
	look_ahead=look_ahead.lerp(ahead,1.-exp(-dt*5.)) if not reduced and mode=="chase" else Vector3.ZERO
	var target := origin-behind*focus+Vector3.UP*(1.85+kart.camera_height_offset*.5)+look_ahead
	view.look_at(target)
	protect(view,kart,space)

func protect(view: Camera3D,kart: LeoKart,space: PhysicsDirectSpaceState3D) -> void:
	# Always run again after final shake/roll offsets have been applied.
	var pose:=kart.get_global_transform_interpolated()
	var center:=body_bounds(kart).get_center()
	var pivot := pose.origin+pose.basis*Vector3(center.x,0.,center.z)+Vector3.UP*(1.5+kart.camera_height_offset*.5)
	var desired := view.position
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new();sphere.radius=.25
	query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,pivot);query.motion=desired-pivot;query.collision_mask=1
	var safe := space.cast_motion(query)
	view.position=pivot+(desired-pivot)*(maxf(0.,safe[0]-.025) if safe.size()>0 else 1.)

static func body_bounds(kart: LeoKart) -> AABB:
	return kart.definition.get_meta("presentation_bounds",AABB(kart.definition.collision_position-kart.definition.collision_size*.5,kart.definition.collision_size))
