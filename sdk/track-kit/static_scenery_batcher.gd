extends RefCounted
## Shared offline static batching; every exported cell owns its instance buffers.
static func collect(node: Node,result: Array) -> void:
 if node.has_meta("baked_precinct"):return
 if node is MeshInstance3D and node.mesh and not node.has_meta("surface_role"):result.append(node)
 for child in node.get_children():collect(child,result)
static func bake(root: Node3D) -> Dictionary:
 var nodes: Array=[];collect(root,nodes);var groups: Dictionary={};var mesh_cache: Dictionary={}
 for node in nodes:
  var p: Vector3=node.global_transform.origin
  var cell:=Vector2i(floori(p.x/200.),floori(p.z/200.))
  var identity: String=node.mesh.resource_path
  if identity.is_empty():identity=node.mesh.get_class()+str(node.mesh.get_aabb())
  var resource_key: String=identity
  var key: String=str(cell)+identity+str(node.cast_shadow)+str(node.visibility_range_end)
  for i in node.mesh.get_surface_count():
   var mat: Material=node.get_active_material(i);key+="|"+str(mat.get_instance_id() if mat else 0);resource_key+="|"+str(mat.get_instance_id() if mat else 0)
  if not groups.has(key):groups[key]={"nodes":[],"cell":cell,"resource_key":resource_key}
  groups[key].nodes.append(node)
 var merged:=0;var batches:=0
 for group in groups.values():
  if group.nodes.size()<2:continue
  var source: MeshInstance3D=group.nodes[0];var mesh: Mesh
  if mesh_cache.has(group.resource_key):mesh=mesh_cache[group.resource_key]
  else:
   mesh=source.mesh.duplicate()
   if mesh is ArrayMesh:
    for i in mesh.get_surface_count():mesh.surface_set_material(i,source.get_active_material(i))
   mesh_cache[group.resource_key]=mesh
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=group.nodes.size()
  var output:=MultiMeshInstance3D.new();output.multimesh=mm;output.cast_shadow=source.cast_shadow;output.visibility_range_end=source.visibility_range_end;output.visibility_range_end_margin=source.visibility_range_end_margin;output.material_override=source.material_override;output.set_meta("cell",group.cell)
  if source.has_meta("flag_hoist_uv"):output.set_meta("flag_hoist_uv",source.get_meta("flag_hoist_uv"))
  root.add_child(output);var transforms: Array[Transform3D]=[]
  for node in group.nodes:transforms.append(root.global_transform.affine_inverse()*node.global_transform)
  load("res://scene_instances.gd").store(output,transforms)
  for node in group.nodes:node.get_parent().remove_child(node);node.free();merged+=1
  batches+=1
 return {"source_mesh_instances":nodes.size(),"instances_batched":merged,"new_batches":batches}
