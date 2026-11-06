class_name LeoCockpitSteering
extends Node3D
## One rigid steering assembly. Authored hub/shaft are in chassis-local space.
const HUB=Vector3(-.348568,1.035044,-.616297)
const SHAFT=Vector3(0,-.26,.965609)
const NEUTRAL_BASIS=Basis(Vector3.RIGHT,PI) # Face the driver; lower spoke down and column behind the rim.
var angle:=0.
static func relative_pose(node: Node3D,root: Node3D) -> Transform3D:
 var pose:=node.transform;var parent:=node.get_parent()
 while parent is Node3D and parent!=root:pose=parent.transform*pose;parent=parent.get_parent()
 return pose
static func install(body: Node3D,vehicle: VehicleDefinition) -> void:
 if not vehicle.official or String(vehicle.id) not in ["bigster","duster_2024"]:return
 var wheels: Array[MeshInstance3D]=[]
 for mesh in body.find_children("*","MeshInstance3D",true,false):
  if String(mesh.name).begins_with("dust25_steering_wheel"):wheels.append(mesh)
 if wheels.is_empty():return
 var pivot:=LeoCockpitSteering.new();pivot.name="CockpitSteering";body.add_child(pivot);pivot.position=HUB+Vector3(0,-.08,0)
 for wheel in wheels:
  var pose:=relative_pose(wheel,body)
  wheel.owner=null;wheel.get_parent().remove_child(wheel);pivot.add_child(wheel);wheel.transform=Transform3D(Basis.IDENTITY,-HUB)*pose
 pivot.basis=NEUTRAL_BASIS
func _process(dt: float) -> void:
 var parent: Node=get_parent()
 while parent and not parent is LeoKart:parent=parent.get_parent()
 var target: float=-clampf(parent.steer,-1.,1.)*deg_to_rad(135.) if parent is LeoKart else 0.
 angle=lerpf(angle,target,1.-exp(-dt*12.))
 basis=Basis(SHAFT.normalized(),angle)*NEUTRAL_BASIS
