extends SceneTree
var errors: Array[String]=[]
var checks:=0
var rows: Array=[]
var captures:=false
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func bounds(node: Node3D) -> AABB:
 var box:=AABB();var found:=false
 for child in node.find_children("*","MeshInstance3D",true,false):
  var b: AABB=child.global_transform*child.get_aabb()
  box=box.merge(b) if found else b;found=true
 return box
func draw() -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
 captures="--visual-test" in OS.get_cmdline_user_args()
 root.size=Vector2i(960,720);root.content_scale_size=Vector2i.ZERO
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("233245");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8;environment.environment=env;world.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-40,0);light.light_energy=1.4;world.add_child(light)
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=43
 var catalog:=GarageCatalog.shared()
 check(int(VehicleDefinition.DriverPolicy.CABIN)==3 and int(VehicleDefinition.DriverPolicy.FIXED)==2,"Enum resource compatibility preserved")
 for key in [&"duster",&"bigster"]:
  var vehicle:=catalog.vehicle(key);var sc:=1.3 if key==&"bigster" else 1.
  check(vehicle.driver_policy==VehicleDefinition.DriverPolicy.CABIN,"Selected cabin policy "+String(key))
  for driver in catalog.drivers:
   var assembly:=VehicleAssembler.assemble(vehicle,driver);world.add_child(assembly)
   check(assembly.get_node("Driver").get_meta("visible_driver_id")==driver.id,"Correct visible character "+String(key)+"/"+String(driver.id))
   var body: Node3D=assembly.get_node("Driver");var box:=bounds(body)
   check(body.basis.get_scale().is_equal_approx(Vector3.ONE*sc),"Bigster fit scale applied once "+String(driver.id))
   # Cabin envelope includes feet beneath the dashboard. Front windshield
   # slopes above this seated head volume; driver side door is x=-0.82.
   check(box.position.x>-.86*sc and box.end.x<.22*sc,"Driver remains inside cabin width "+String(key)+"/"+String(driver.id))
   check(box.end.y<1.62*sc,"Roof clearance "+String(key)+"/"+String(driver.id))
   check(box.position.z>-1.10*sc and box.end.z<.75*sc,"Windscreen and seat depth "+String(key)+"/"+String(driver.id))
   rows.append({"vehicle":String(key),"driver":String(driver.id),"bounds_min":str(box.position/sc),"bounds_max":str(box.end/sc)})
   if captures:
    camera.position=Vector3(-3.3,1.8,-3.3)*sc;camera.look_at(Vector3(-.25,1.,-.15)*sc);await draw()
    root.get_texture().get_image().save_png("res://docs/qa-local2player/cabin-%s-%s-front.png" % [key,driver.id])
    camera.position=Vector3(-3.3,1.45,.15)*sc;camera.look_at(Vector3(-.25,1.,-.15)*sc);await draw()
    root.get_texture().get_image().save_png("res://docs/qa-local2player/cabin-%s-%s-side.png" % [key,driver.id])
    assembly.get_node("Chassis").hide();camera.position=Vector3(-1.6,1.3,-1.7)*sc;camera.look_at(Vector3(-.37,1.05,-.17)*sc);await draw()
    root.get_texture().get_image().save_png("res://docs/qa-local2player/cabin-%s-%s-pose.png" % [key,driver.id])
   assembly.free()
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"fits":rows,"captures":captures}
 FileAccess.open("res://docs/qa-local2player/drivers.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOCAL_DRIVER_TEST ",report)
 world.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
