extends SceneTree
func _initialize() -> void:
 for i in 3:
  var mesh: Mesh=load("res://assets/models/colombo/shade_tree_%d.res"%i);var tris:=0
  for s in mesh.get_surface_count():tris+=mesh.surface_get_array_index_len(s)/3
  print("SHADE_MESH ",i," aabb=",mesh.get_aabb()," triangles=",tris)
 quit()
