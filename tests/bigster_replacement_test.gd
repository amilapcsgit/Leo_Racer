extends SceneTree
var errors: Array[String] = []
var checks := 0
const OUT := "res://docs/qa-bigster-replacement/"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks += 1
 print(("PASS " if ok else "FAIL ") + message)
 if not ok: errors.append(message)
func bounds(node: Node3D) -> AABB:
 var box := AABB()
 var found := false
 for child in node.find_children("*", "MeshInstance3D", true, false):
  var b: AABB = (node.global_transform.affine_inverse() * child.global_transform) * child.get_aabb()
  box = box.merge(b) if found else b
  found = true
 return box
func draw() -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
func tire_center(wheel: Node3D) -> Vector3:
 var low := Vector3(INF,INF,INF)
 var high := -low
 for child in wheel.find_children("*", "MeshInstance3D", true, false):
  for surface in child.mesh.get_surface_count():
   var material: StandardMaterial3D = child.mesh.surface_get_material(surface)
   if material.resource_name != "Wheel rubber": continue
   var vertices: PackedVector3Array = child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for vertex in vertices:
    var point: Vector3 = child.global_transform * vertex
    low = low.min(point)
    high = high.max(point)
 return (low + high) * .5
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var v: VehicleDefinition = load("res://assets/catalog/vehicle_bigster.tres")
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 check(document.append_from_file("res://assets/models/bigster/bigster.glb", state) == OK, "Independent GLB import")
 var raw := document.generate_scene(state)
 root.add_child(raw)
 var box := bounds(raw)
 check(absf(box.size.z - 4.570) < .005, "Length within 5 mm")
 check(absf(box.size.y - 1.712) < .002, "Height preserved")
 check(absf(box.size.x - 2.0424371) < .002, "Authored mirror width preserved")
 var triangles := 0
 var materials := {}
 for mesh in raw.find_children("*", "MeshInstance3D", true, false):
  for surface in mesh.mesh.get_surface_count():
   var arrays: Array = mesh.mesh.surface_get_arrays(surface)
   triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
   var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
   check(material != null, "Portable PBR material")
   if material:
    materials[material.resource_name] = true
    check(material.albedo_texture == null, "No external albedo dependency")
 check(triangles <= 70000 and triangles >= 60000, "Simplified triangle budget")
 for label in ["Gray paint", "Copper accents", "Wheel rubber", "Headlamp white", "Tail lamp red", "Front glass"]:
  check(materials.has(label), "Separated material: " + label)
 raw.free()
 var kart := LeoKart.new()
 root.add_child(kart)
 kart.setup(LeoCircuit.new(), 0, false, &"human", &"bigster")
 kart.set_process(false)
 kart.set_physics_process(false)
 check(v.normalization.basis.get_scale().is_equal_approx(Vector3.ONE * 1.3), "SUV game scale is 130 percent")
 check(v.collision_size.is_equal_approx(Vector3(2.405,2.2256,5.941)), "Collision follows SUV scale")
 check(kart.wheels.size() == 4, "Four animated wheels")
 check(kart.driver != null and kart.driver.get_meta("visible_driver_id") == &"human", "Fixed helmeted driver assembled")
 check(kart.visual.find_children("Driver", "Node3D", true, false).size() == 1, "One driver only")
 for i in 4:
  check(kart.wheel_steering_pivots[i].position.distance_to(v.wheels[i].pivot) < .00001, "Exact wheel pivot " + str(i))
  check(absf(v.wheels[i].radius - .4615) < .00001, "Correct rolling radius " + str(i))
  var caliper := VehicleAssembler.find_group(kart.chassis, NodePath("caliper_" + str(i)))
  check(caliper != null and caliper.get_parent() == kart.wheel_steering_pivots[i], "Caliper steers outside spinning hub " + str(i))
  check(kart.wheels[i].global_position.distance_to(kart.wheel_steering_pivots[i].global_position) < .00001, "Scaled wheel centered on pivot " + str(i))
  var wb := kart.wheels[i].global_transform * bounds(kart.wheels[i])
  check(absf(wb.size.y - .923) < .002 and absf(wb.size.z - .923) < .002, "Circular wheel geometry " + str(i))
 kart.wheel_motion_speed = 12.
 kart.wheel_visual_speed = 12.
 kart.animate_wheels(.1)
 for i in 4:
  check(absf(angle_difference(kart.wheel_angles[i], -1.2 / .4615)) < .00001, "Travel-based wheel rotation " + str(i))
  check(absf(kart.wheel_spin_pivots[i].basis.determinant() - 1.) < .00001, "Orthogonal rotating wheel " + str(i))
 check(v.max_speed == 50. and v.boosted_speed == 62.5 and v.electric_boost, "Existing Bigster driving preset retained")
 for steering in [-1.,0.,1.]:
  kart.steer = steering
  for speed in [-12.,0.,12.]:
   kart.wheel_motion_speed = speed
   kart.wheel_visual_speed = speed
   kart.animate_wheels(.173)
   for i in 4:
    var hub: Vector3 = kart.wheel_steering_pivots[i].global_position
    check(tire_center(kart.wheels[i]).distance_to(hub) < .0001, "Tire stays centered: steering %s speed %s wheel %d" % [steering,speed,i])
    var caliper := VehicleAssembler.find_group(kart.chassis, NodePath("caliper_" + str(i)))
    check(caliper.global_position.distance_to(hub) < .0001, "Caliper stays on hub " + str(i))
 kart.stop_audio()
 kart.free()
 var captured := "--capture" in OS.get_cmdline_user_args()
 if captured:
  var game: Node3D = load("res://scenes/main.tscn").instantiate()
  root.add_child(game);await game.initialization_finished
  await process_frame
  game.diagnostics_mode = true
  game.hud.show_garage()
  var selector: ModularCarSelector = game.hud.garage_selector
  await selector.set_selection(&"human", &"bigster")
  selector.reduced_motion = true
  root.size = Vector2i(1600,900)
  DisplayServer.window_set_size(root.size)
  game.hud.resize_canvas()
  selector.yaw = -.7
  selector.update_camera()
  await draw()
  root.get_texture().get_image().save_png(OUT + "garage.png")
  selector.camera.position = v.preview_target + Vector3(-.6,.35,-1).normalized() * v.preview_distance
  selector.camera.look_at(v.preview_target)
  await draw()
  var image := selector.viewport.get_texture().get_image()
  image.resize(512,320,Image.INTERPOLATE_LANCZOS)
  image.save_png("res://assets/art/garage/thumbnails/vehicle_bigster.png")
  var views := {"front": Vector3(0,1.,-7), "rear": Vector3(0,1.,7), "side": Vector3(-7,1.15,0), "front-quarter": Vector3(-4,2.6,-5), "rear-quarter": Vector3(-4,2.6,5), "driver": Vector3(-1.8,1.65,-2)}
  for label in views:
   selector.camera.position = views[label] * 1.3
   selector.camera.look_at(Vector3(0,1.235,0))
   await draw()
   selector.viewport.get_texture().get_image().save_png(OUT + label + ".png")
  game.selected_kart = game.catalog.vehicle_index(&"bigster")
  game.selected_driver = game.catalog.driver_index(&"human")
  await game.start_race()
  game.state = "race"
  game.player.active = true
  game.player.auto_drive = true
  await create_timer(2.).timeout
  await draw()
  root.get_texture().get_image().save_png(OUT + "race.png")
  game.stop_all_audio()
  game.queue_free()
  await process_frame
  await process_frame
 var report := {"status": "PASS" if errors.is_empty() else "FAIL", "checks": checks, "errors": errors, "triangles": triangles, "bounds": str(box), "material_count": materials.size(), "captures": captured}
 FileAccess.open(OUT + "replacement.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
 print("BIGSTER_REPLACEMENT ", JSON.stringify(report))
 quit(0 if errors.is_empty() else 1)
