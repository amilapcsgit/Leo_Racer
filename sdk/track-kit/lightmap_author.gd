extends RefCounted
## Prepare self-contained, UV2-unwrapped precinct scenes for the native editor bake.
func own(node: Node,scene: Node) -> void:
 for child in node.get_children():child.owner=scene;own(child,scene)
func prepare_mesh(node: Node) -> void:
 if node is MeshInstance3D and node.mesh:
  if node.mesh is PrimitiveMesh:
   var st:=SurfaceTool.new();st.create_from(node.mesh,0);node.mesh=st.commit()
  if node.mesh is ArrayMesh and not node.mesh.surface_get_format(0)&Mesh.ARRAY_FORMAT_TEX_UV2:
   var mesh: ArrayMesh=node.mesh.duplicate();var error:=mesh.lightmap_unwrap(node.global_transform,.65)
   if error!=OK:push_error("Lightmap unwrap failed: "+str(node.name));return
   node.mesh=mesh
  node.gi_mode=GeometryInstance3D.GI_MODE_STATIC
  var extent: float=node.mesh.get_aabb().size.length()
  node.mesh.lightmap_size_hint=Vector2i(1024,1024) if extent>15. else Vector2i(64,64)
 for child in node.get_children():prepare_mesh(child)
func prepare(author: Node3D) -> void:
 DirAccess.make_dir_recursive_absolute("res://baked")
 var roots: Array[Node]=[]
 for parent in [author.get_node("Resident"),author.get_node("Details")]:
  for child in parent.get_children():
   if child.has_meta("baked_precinct") and (String(child.name).contains("tooth_temple") or String(child.name).contains("mahaweli") or child.has_meta("start_arch")):roots.append(child)
 for original in roots:
  # Reconstruct native nodes to discard imported PackedScene inheritance/state.
  var flattener=load("res://resource_baker.gd").new("res://.lightmap-scratch","res://.lightmap/")
  var scene: Node3D=flattener.flatten(original);var key:=String(original.name);scene.position=Vector3.ZERO;scene.rotation=Vector3.ZERO
  author.add_child(scene);prepare_mesh(scene)
  var gi:=LightmapGI.new();gi.name="BakedIndirectLight";gi.quality=LightmapGI.BAKE_QUALITY_MEDIUM;gi.bounces=3;gi.max_texture_size=2048;gi.generate_probes_subdiv=LightmapGI.GENERATE_PROBES_SUBDIV_4
  gi.environment_mode=LightmapGI.ENVIRONMENT_MODE_CUSTOM_SKY
  var sky:=Sky.new();var panorama:=PanoramaSkyMaterial.new();panorama.panorama=load("res://art/environment/daylight.exr");sky.sky_material=panorama;gi.environment_custom_sky=sky
  var data:=LightmapGIData.new();var data_path:="res://baked/"+key+".lmbake";ResourceSaver.save(data,data_path);data.take_over_path(data_path);gi.light_data=data;scene.add_child(gi)
  var sun:=DirectionalLight3D.new();sun.name="BakeSun";sun.rotation_degrees=Vector3(-62,-120,0);sun.light_color=Color("fff4df");sun.light_energy=1.1;sun.light_bake_mode=Light3D.BAKE_DYNAMIC;scene.add_child(sun)
  var world:=WorldEnvironment.new();world.name="BakeEnvironment";world.environment=Environment.new();world.environment.background_mode=Environment.BG_SKY;world.environment.sky=sky;world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;scene.add_child(world)
  own(scene,scene);var packed:=PackedScene.new();packed.pack(scene);ResourceSaver.save(packed,"res://baked/"+key+".tscn");scene.free()
  print("PRECINCT_PREPARED ",key)
