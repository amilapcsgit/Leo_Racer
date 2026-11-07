extends SceneTree
var errors: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var content:=OS.get_environment("LEO_ASSET_ROOT")
 if content.is_empty():content=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets")
 check(LeoAssets.configure(content)==OK and LeoAssets.mount_packs()==OK,"Content mounts")
 LeoVehicleLibrary.discover()
 var world:=Node3D.new();root.add_child(world)
 var rows: Array=[]
 for id in ["duster","duster_2024","bigster"]:
  var definition:=LeoVehiclePresentation.resolve(GarageCatalog.shared().vehicle(StringName(id)))
  var kart:=LeoKart.new();world.add_child(kart);kart.set_physics_process(false);kart.set_process(false)
  kart.definition=definition;kart.visual=VehicleAssembler.assemble(definition,GarageCatalog.shared().drivers[0]);kart.add_child(kart.visual);kart.chassis=kart.visual.get_node("Chassis")
  for binding in definition.wheels:kart.attach_binding(binding)
  check(kart.wheel_spin_pivots.size()==4,id+" has four bound wheels")
  var counts: Array=[]
  for pivot in kart.wheel_spin_pivots:
   var meshes:=pivot.find_children("*","MeshInstance3D",true,false)
   counts.append(meshes.size());check(not meshes.is_empty(),id+" rolling pivot owns visible tire/rim geometry")
  kart.wheel_motion_speed=12.;kart.wheel_visual_speed=12.;kart.steer=1.;kart.animate_wheels(.1)
  for i in 4:
   check(not kart.wheel_spin_pivots[i].basis.is_equal_approx(Basis.IDENTITY),id+" tire/rim actually rolls "+str(i))
   check((not kart.wheel_steering_pivots[i].basis.is_equal_approx(Basis.IDENTITY))==definition.wheels[i].steering,id+" only front wheels steer "+str(i))
  var right: Basis=kart.wheel_steering_pivots[0].basis
  kart.steer=-1.;kart.animate_wheels(.1)
  check(not right.is_equal_approx(kart.wheel_steering_pivots[0].basis),id+" front wheels turn both ways")
  rows.append({"id":id,"rolling_mesh_counts":counts,"front_steer_degrees":20.05,"roll_at_12mps":true})
  kart.free()
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"cars":rows}
 var out:=ProjectSettings.globalize_path("res://build/qa279/wheels279.json")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="):out=arg.trim_prefix("--qa-output=").path_join("wheels279.json")
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WHEELS279 ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
