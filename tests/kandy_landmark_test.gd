extends SceneTree
var errors: Array[String]=[]
var checked: Dictionary={}
var game: Node3D
func _initialize() -> void:run.call_deferred()
func inspect(node: Node) -> void:
 var id:=String(node.get_meta("protected_asset",""))
 if id in ["mahaweli_seya","sacred_tooth_precinct"] or (not id.is_empty() and id.contains("191377765")):
  var bounds:=AABB();var first:=true
  for mesh in node.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
  if not first:
   var clearance:=INF
   for x in [bounds.position.x,bounds.end.x]:
    for z in [bounds.position.z,bounds.end.z]:
     for point in game.circuit.points:clearance=minf(clearance,Vector2(point.x,point.z).distance_to(Vector2(x,z)))
   checked[id]={"height":bounds.size.y,"bounds":str(bounds),"root":str(node.global_position),"corner_route_clearance":clearance}
   if clearance<13.:errors.append(id+" intrudes on protected promenade")
   if id=="mahaweli_seya" and absf(bounds.size.y-60.)>.2:errors.append("Stupa scale changed")
 for child in node.get_children():inspect(child)
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 var stream: Node=game.world.find_child("ColomboSceneryStreaming",true,false);await stream.stop();inspect(game.world)
 for cell in stream.cells:
  if stream.loaded.has(cell.id):continue
  var instance: Node3D=load(String(cell.scene)).instantiate();game.add_child(instance);inspect(instance);instance.free()
 if not checked.has("mahaweli_seya"):errors.append("Stupa missing from exported content")
 if checked.size()<2:errors.append("Temple missing from exported content")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","landmarks":checked,"errors":errors}
 FileAccess.open("res://build/kandy/landmark-validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KANDY_LANDMARK_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)

