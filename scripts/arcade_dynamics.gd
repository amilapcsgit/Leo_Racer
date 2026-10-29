class_name LeoArcadeDynamics
extends RefCounted
const GRAVITY := 12.
const SNAP := .15
const AIR_GRIP := .20
const RESTITUTION := .08
const LANDING_THRESHOLD := 1.5
var compression := Vector3.ZERO
var spring_velocity := Vector3.ZERO
func reset() -> void:
	compression=Vector3.ZERO;spring_velocity=Vector3.ZERO
func spring(target: Vector3,dt: float) -> Vector3:
	# Substeps keep this damped spring stable at low frame rates.
	var steps:=maxi(1,ceili(dt/(1./120.)))
	var h:=minf(dt,.1)/steps
	var omega:=TAU*3.
	for i in steps:
		spring_velocity+=((target-compression)*omega*omega-2.*.8*omega*spring_velocity)*h
		compression+=spring_velocity*h
	compression.x=clampf(compression.x,-.06,.08)
	compression.y=clampf(compression.y,-deg_to_rad(3.),deg_to_rad(3.))
	compression.z=clampf(compression.z,-deg_to_rad(5.),deg_to_rad(5.))
	return compression
