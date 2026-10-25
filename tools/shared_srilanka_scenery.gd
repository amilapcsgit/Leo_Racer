extends RefCounted
## Reusable, offline scenery composition for all Sri Lankan track authoring jobs.
var author: Node3D
var mesh_cache: Dictionary={}
var materials: Dictionary={}
var report: Dictionary={"billboards":0,"flags":0,"shade_trees":0,"shrubs":0,"lamps":0,"secondary_frontages":0,"source_tracks":["astra_coast","colombo_city"]}
func _init(owner_author: Node3D) -> void:author=owner_author
func material(color: String) -> StandardMaterial3D:return author.material(color)
func pbr(key: String) -> ShaderMaterial:
 if materials.has(key):return materials[key]
 var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://shared/scenery.json"))
 var asset: Dictionary=registry.assets[key];var m:=ShaderMaterial.new();m.shader=load(asset.shader)
 for pair in [["color_map","Color"],["normal_map","NormalGL"],["rough_map","Roughness"]]:m.set_shader_parameter(pair[0],load(asset.texture_prefix+pair[1]+".jpg"))
 if key=="surface.asphalt":m.set_shader_parameter("base_roughness",.64)
 materials[key]=m;return m
func parts(node: Node3D,pose: Transform3D,result: Array) -> void:
 var transform:=pose*node.transform
 if node is MeshInstance3D and node.mesh:result.append({"mesh":node.mesh,"pose":transform})
 for child in node.get_children():
  if child is Node3D:parts(child,transform,result)
func meshes(path: String) -> Array:
 if mesh_cache.has(path):return mesh_cache[path]
 var resource:=load(path);var result: Array=[]
 if resource is Mesh:result.append({"mesh":resource,"pose":Transform3D.IDENTITY})
 elif resource is PackedScene:
  var scene:=resource.instantiate() as Node3D;parts(scene,Transform3D.IDENTITY,result);scene.free()
 mesh_cache[path]=result;return result
func batch_model(parent: Node3D,path: String,poses: Array[Transform3D],limit: float=0.) -> void:
 for part in meshes(path):
  var transforms: Array[Transform3D]=[]
  for pose in poses:transforms.append(pose*part.pose)
  var old_count:=parent.get_child_count();author.batch(parent,part.mesh,transforms,"")
  for i in range(old_count,parent.get_child_count()):
   var node:=parent.get_child(i) as GeometryInstance3D
   node.visibility_range_end=limit;node.visibility_range_end_margin=25. if limit>0 else 0.
   node.set_meta("shared_asset",path)
func billboard(parent: Node3D,distance: float,index: int) -> void:
 var root:=Node3D.new();root.name="SharedBillboard%02d"%index;root.position=author.sample(distance,-24. if index%3 else 24.);root.rotation.y=atan2(-author.frame(distance).z.x,-author.frame(distance).z.z)+PI
 parent.add_child(root)
 author.box(root,Vector3(9.25,5.35,.25),Vector3(0,5.8,0),"202c2b")
 for x in [-3.3,3.3]:author.box(root,Vector3(.2,6.,.22),Vector3(x,3.,-.1),"333d37")
 var face:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(8.9,5.);face.mesh=quad;face.position=Vector3(0,5.8,.16)
 if index%3==0:
  var mat:=ShaderMaterial.new();mat.shader=load("res://billboard_depth.gdshader");mat.set_shader_parameter("artwork",load("res://art/billboards/kandy_lake.png"));mat.set_shader_parameter("scene_depth",load("res://art/billboards/kandy_lake_depth.png"));face.material_override=mat
 else:
  var key:="advert_"+str(index%3)
  if not materials.has(key):
   var mat:=StandardMaterial3D.new();mat.albedo_texture=load("res://shared/art/colombo_gp.png" if index%3==1 else "res://shared/art/coast_race.png");mat.roughness=.7;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;materials[key]=mat
  face.material_override=materials[key]
 root.add_child(face);report.billboards+=1
func flag(parent: Node3D,distance: float,index: int) -> void:
 var root:=Node3D.new();root.position=author.sample(distance,13. if index%2==0 else -14.);root.rotation.y=atan2(author.frame(distance).x.x,author.frame(distance).x.z);parent.add_child(root)
 author.box(root,Vector3(.10,6.,.1),Vector3(0,3.,0),"b8b4a4")
 var plane:=PlaneMesh.new();plane.orientation=PlaneMesh.FACE_Z;plane.size=Vector2(2.4,1.2);plane.subdivide_width=20;plane.subdivide_depth=6
 var node:=MeshInstance3D.new();node.mesh=plane;node.position=Vector3(1.25,5.1,0)
 if not materials.has("flag"):
  var mat:=ShaderMaterial.new();mat.shader=load("res://shared/sri_flag.gdshader");mat.set_shader_parameter("flag_map",load("res://shared/sri_lanka_flag.svg"));materials.flag=mat
 node.material_override=materials.flag;root.add_child(node);report.flags+=1
func dress(details: Node3D) -> Dictionary:
 heritage_precinct(details)
 for i in int(author.length/230.):billboard(details,45.+i*230.,i)
 for i in int(author.length/58.):flag(details,i*58.+18.,i)
 # Natural premade shade meshes from Astra/Colombo replace the spherical trees.
 var trees: Array=[]
 for variant in 3:trees.append([])
 for i in int(author.length/14.):
  var s:=i*14.;var p: Vector3=author.sample(s,20. if i%2 else -20.);p.y=author.ground(p.x,p.z)
  if p.x< -475. and p.z> -210. and p.z< -15.:continue
  var scale_value: float=author.rng.randf_range(.62,.95)
  trees[i%3].append(Transform3D(Basis(Vector3.UP,author.rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p));report.shade_trees+=1
 var lake:=PackedVector2Array()
 for p in author.geography.lake:lake.append(Vector2(p[0],p[1]))
 for i in 1600:
  var p:=Vector3(author.rng.randf_range(-1050,1050),0,author.rng.randf_range(-1050,1050))
  if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),lake):continue
  var nearest:=INF
  for j in range(0,author.points.size(),10):nearest=minf(nearest,Vector2(author.points[j].x,author.points[j].z).distance_to(Vector2(p.x,p.z)))
  if nearest<85. or nearest>650.:continue
  if Vector2(p.x+530.,p.z+135.).length()<40.:continue
  p.y=author.ground(p.x,p.z);var scale_value: float=author.rng.randf_range(.7,1.25)
  trees[i%3].append(Transform3D(Basis(Vector3.UP,author.rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p));report.shade_trees+=1
 for i in 7:
  var angle:=TAU*i/7.;var p:=Vector3(30.+cos(angle)*6.5,.25,10.+sin(angle)*6.5)
  trees[i%3].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*.65),p));report.shade_trees+=1
 for variant in 3:
  var poses: Array[Transform3D]=[]
  for pose in trees[variant]:poses.append(pose)
  batch_model(details,"res://assets/models/colombo/shade_tree_%d.res"%variant,poses,850.)
 var shrubs: Array[Transform3D]=[]
 for i in int(author.length/9.):
  var p: Vector3=author.sample(i*9.,18. if i%2 else -19.);p.y=author.ground(p.x,p.z)
  shrubs.append(Transform3D(Basis(Vector3.UP,author.rng.randf()*TAU).scaled(Vector3.ONE*author.rng.randf_range(.65,1.1)),p))
 batch_model(details,"res://assets/models/colombo/bush_common.glb",shrubs,220.);report.shrubs=shrubs.size()
 # Reuse completed 12-recipe buildings, rather than loose roofs or wall pieces.
 for i in int(author.length/18.):
  if i%8==0:continue
  var s:=i*18.+7.;var p: Vector3=author.sample(s,-49.);p.y=author.ground(p.x,p.z)
  author.building(details,p,atan2(author.frame(s).x.x,author.frame(s).x.z),i+2);report.secondary_frontages+=1
 # Familiar lamp hardware from the existing Colombo/Astra promenade system.
 var poles: Array[Transform3D]=[];var heads: Array[Transform3D]=[]
 for i in int(author.length/32.):
  var s:=i*32.;var p: Vector3=author.sample(s,12. if i%2 else -12.);var basis: Basis=author.frame(s)
  poles.append(Transform3D(basis,p+Vector3.UP*3.4));heads.append(Transform3D(basis,p+Vector3.UP*6.7+basis.x*.7));report.lamps+=1
 var pole_mesh:=BoxMesh.new();pole_mesh.size=Vector3(.16,6.8,.16);author.batch(details,pole_mesh,poles,"33413c")
 var head_mesh:=BoxMesh.new();head_mesh.size=Vector3(1.6,.14,.4);author.batch(details,head_mesh,heads,"c8c5ae")
 return report
func heritage_precinct(parent: Node3D) -> void:
 for landmark in author.geography.get("landmarks",[]):
  var center:=Vector3(landmark.center[0],0,landmark.center[1]);center.y=author.ground(center.x,center.z)
  var group:=Node3D.new();group.name="ProtectedNorthShoreHeritageMassing";group.position=center;group.set_meta("protected_asset",landmark.id);parent.add_child(group)
  var packed:=load("res://shared/landmarks/tooth_temple.glb") as PackedScene
  var temple:=packed.instantiate() as Node3D;group.add_child(temple)
  report.heritage_precinct=landmark.id
 var stupa_position:=Vector3(-530.,0.,-135.);stupa_position.y=author.ground(stupa_position.x,stupa_position.z)
 var stupa:=load("res://shared/landmarks/mahaweli.glb").instantiate() as Node3D
 stupa.name="MahaweliSeyaStartLandmark";stupa.position=stupa_position;stupa.set_meta("protected_asset","mahaweli_seya");parent.add_child(stupa)
 author.box(parent,Vector3(54.,1.2,54.),stupa_position-Vector3.UP*.6,"d2ccba")
 report.mahaweli_seya={"height_m":60.,"position":[stupa_position.x,stupa_position.y,stupa_position.z],"artistic_placement":true}
 var lake_polygon:=PackedVector2Array()
 for point in author.geography.lake:lake_polygon.append(Vector2(point[0],point[1]))
 var woodland: Array[Transform3D]=[]
 for i in 64:
  var p: Vector3=author.sample(i*author.length/64.,95. if i%2 else -105.)
  if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),lake_polygon):continue
  p.y=author.ground(p.x,p.z)
  if p.distance_to(stupa_position)<42.:continue
  woodland.append(Transform3D(Basis(Vector3.UP,author.rng.randf()*TAU).scaled(Vector3.ONE*author.rng.randf_range(.7,1.2)),p))
 batch_model(parent,"res://shared/landmarks/forest.glb",woodland,650.)
 report.supplied_forest_trees=woodland.size()
