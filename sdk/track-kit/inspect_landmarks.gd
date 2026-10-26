extends SceneTree
func _initialize() -> void:run.call_deferred()
func meshes(node: Node) -> void:
 if node is MeshInstance3D:
  var heights: Array=[]
  for i in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(i);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var top:=-INF
   for v in vertices:top=maxf(top,v.y)
   heights.append(top)
  print("MODEL_GEOMETRY ",node.name," box=",node.get_aabb()," top_by_surface=",heights)
 for child in node.get_children():meshes(child)
func run() -> void:
 for path in ["res://shared/landmarks/mahaweli.glb","res://baked/KandyPrecinct_mahaweli.tscn"]:
  print("INSPECT ",path);var scene: Node=load(path).instantiate();root.add_child(scene);meshes(scene);scene.free()
 quit()
