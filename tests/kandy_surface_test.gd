extends SceneTree
## Tests actual exported render geometry, independently of gameplay's collision ribbon.
var game: Node3D
var terrain_meshes:=0
var road_meshes:=0
var probe_root: Node3D
func _initialize() -> void:run.call_deferred()
func collect(node: Node) -> void:
 if node is MeshInstance3D and node.mesh:
  var role:=String(node.get_meta("surface_role",""))
  if role in ["terrain_detail","terrain_backdrop","race_road"]:
   var body:=StaticBody3D.new();body.collision_layer=2048 if role=="race_road" else 1024;body.collision_mask=0
   probe_root.add_child(body);body.global_transform=node.global_transform
   var collider:=CollisionShape3D.new();var shape: ConcavePolygonShape3D=node.mesh.create_trimesh_shape();shape.backface_collision=true;collider.shape=shape;body.add_child(collider)
   if role=="race_road":road_meshes+=1
   else:terrain_meshes+=1
 for child in node.get_children():collect(child)
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 var stream: Node=game.world.find_child("ColomboSceneryStreaming",true,false)
 await stream.stop()
 probe_root=Node3D.new();game.add_child(probe_root)
 collect(game.world)
 # Include unloaded terrain cells, not merely the currently visible vicinity.
 var examined: Dictionary={}
 for cell in stream.cells:
  if stream.loaded.has(cell.id):examined[cell.id]=true;continue
  var packed:=load(String(cell.scene)) as PackedScene
  var instance:=packed.instantiate() as Node3D;game.add_child(instance);instance.visible=false;collect(instance);instance.queue_free()
 await physics_frame;await physics_frame
 var space:=game.get_world_3d().direct_space_state;var blocked: Array=[];var gaps: Array=[];var probes:=0;var error_max:=0.
 for station in range(0,int(game.circuit.length),4):
  for lane in [-8.5,-6.,-3.,0.,3.,6.,8.5]:
   probes+=1;var p: Vector3=game.circuit.sample(float(station),lane)
   var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*600.,p-Vector3.UP*600.,1024)
   var obstruction:=space.intersect_ray(query)
   if not obstruction.is_empty():blocked.append({"distance":station,"lane":lane,"hit_y":obstruction.position.y,"road_y":p.y})
   query.collision_mask=2048;var surface:=space.intersect_ray(query)
   if surface.is_empty():gaps.append({"distance":station,"lane":lane})
   else:error_max=maxf(error_max,absf(surface.position.y-p.y))
 var ok:=blocked.is_empty() and gaps.is_empty() and error_max<.15 and terrain_meshes>50 and road_meshes==32
 var report:={"status":"PASS" if ok else "FAIL","rendered_terrain_meshes":terrain_meshes,"rendered_road_segments":road_meshes,"probes":probes,"terrain_blocked_samples":blocked.size(),"road_gap_samples":gaps.size(),"maximum_rendered_road_height_error_m":error_max,"blocked_examples":blocked.slice(0,12),"gap_examples":gaps.slice(0,12)}
 FileAccess.open("res://build/kandy/surface-clearance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KANDY_RENDER_SURFACE_TEST ",JSON.stringify(report))
 await game.quit_game(0 if ok else 2)
