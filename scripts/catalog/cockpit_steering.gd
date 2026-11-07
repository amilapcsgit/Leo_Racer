class_name LeoCockpitSteering
extends Node3D
## One rigid steering assembly, using each model's reviewed hub and shaft.
const Profile = preload("res://scripts/catalog/cockpit_profile279.gd")
const HUB=Vector3(-.348568,1.035044,-.616297)
const SHAFT=Vector3(0,-.26,.965609)
const NEUTRAL_BASIS=Basis(Vector3.RIGHT,PI) # Face the driver; lower spoke down and column behind the rim.
var angle:=0.
var shaft := SHAFT
var rest_basis := NEUTRAL_BASIS
var maximum_angle := deg_to_rad(135.)
static func relative_pose(node: Node3D,root: Node3D) -> Transform3D:
 var pose:=node.transform;var parent:=node.get_parent()
 while parent is Node3D and parent!=root:pose=parent.transform*pose;parent=parent.get_parent()
 return pose
static func install(body: Node3D,vehicle: VehicleDefinition) -> void:
 if not vehicle.official:return
 var profile: Dictionary = Profile.for_vehicle(String(vehicle.id))
 if profile.is_empty():return
 var wheels: Array[MeshInstance3D]=[]
 for label in profile.get("wheel_nodes", []):
  var mesh := Profile.node(body, String(label)) as MeshInstance3D
  if not mesh:
   push_warning("Cockpit wheel binding missing: " + String(vehicle.id) + " / " + String(label));return
  wheels.append(mesh)
 var hub: Vector3 = Profile.vector(profile,"hub")
 var pivot:=LeoCockpitSteering.new();pivot.name="CockpitSteering";body.add_child(pivot)
 pivot.position=hub+Profile.vector(profile,"offset")
 pivot.shaft=Profile.vector(profile,"shaft",Vector3.BACK).normalized()
 pivot.rest_basis=Basis.from_euler(Profile.vector(profile,"rest_degrees")*PI/180.)
 pivot.maximum_angle=deg_to_rad(float(profile.get("max_degrees",135.)))
 pivot.set_meta("reviewed_cockpit",String(vehicle.id));pivot.set_meta("swept_clearance_target_m",.015)
 for wheel in wheels:
  var pose:=relative_pose(wheel,body)
  wheel.owner=null;wheel.get_parent().remove_child(wheel);pivot.add_child(wheel);wheel.transform=Transform3D(Basis.IDENTITY,-hub)*pose
 pivot.apply_angle(0.)
func apply_angle(radians: float) -> void:
 angle=clampf(radians,-maximum_angle,maximum_angle)
 basis=Basis(shaft,angle)*rest_basis
func _process(dt: float) -> void:
 var parent: Node=get_parent()
 while parent and not parent is LeoKart:parent=parent.get_parent()
 var target: float=-clampf(parent.steer,-1.,1.)*maximum_angle if parent is LeoKart else 0.
 apply_angle(lerpf(angle,target,1.-exp(-dt*12.)))
