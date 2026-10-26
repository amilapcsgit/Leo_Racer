extends RefCounted
## Reusable, offline scenery composition for all Sri Lankan track authoring jobs.
var author: Node3D
var presentation: RefCounted
var mesh_cache: Dictionary={}
var materials: Dictionary={}
var report: Dictionary={"billboards":0,"flags":0,"shade_trees":0,"shrubs":0,"lamps":0,"secondary_frontages":0,"source_tracks":["astra_coast","colombo_city"]}
func _init(owner_author: Node3D) -> void:
 author=owner_author;presentation=load("res://kandy_presentation.gd").new(author)
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
 presentation.billboard(parent,index);report.billboards+=1
func flag(parent: Node3D,distance: float,index: int) -> void:
 if presentation.flag(parent,distance,index):report.flags+=1
func dress(details: Node3D) -> Dictionary:
 heritage_precinct(details)
 presentation.extra_landmarks(details)
 presentation.sign_set(details)
 presentation.arch(author.get_node("Resident"))
 presentation.mountains(author.get_node("Resident"))
 for i in int(author.length/230.):billboard(details,45.+i*230.,i)
 for i in int(author.length/58.):flag(details,i*58.+18.,i)
 # Natural premade shade meshes from Astra/Colombo replace the spherical trees.
 var trees: Array=[]
 for variant in 3:trees.append([])
 # A woodland crescent frames the two secondary sacred precincts, leaving their roadward faces open.
 for area in presentation.reserved:
  if area.kind not in ["buddha","jungle_temple"]:continue
  var toward: Vector3=(author.sample(area.station)-area.position).normalized()
  var front:=atan2(toward.x,toward.z)
  for i in 13:
   var angle: float=front+PI*.42+float(i)/12.*PI*1.16
   var p: Vector3=area.position+Vector3(sin(angle),0,cos(angle))*(area.radius+5.+i%3*3.)
   if presentation.is_reserved(p,4.):continue
   p.y=author.ground(p.x,p.z)
   trees[i%3].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*.82),p));report.shade_trees+=1
 for i in int(author.length/14.):
  var s:=i*14.;var p: Vector3=author.sample(s,20. if i%2 else -20.);p.y=author.ground(p.x,p.z)
  if presentation.is_reserved(p,5.):continue
  if p.x< -475. and p.z> -210. and p.z< -15.:continue
  var scale_value: float=author.rng.randf_range(.62,.95)
  trees[i%3].append(Transform3D(Basis(Vector3.UP,author.rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p));report.shade_trees+=1
 var lake:=PackedVector2Array()
 for p in author.geography.lake:lake.append(Vector2(p[0],p[1]))
 for i in 3200:
  var p:=Vector3(author.rng.randf_range(-1050,1050),0,author.rng.randf_range(-1050,1050))
  if presentation.is_reserved(p,5.):continue
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
  if presentation.is_reserved(p,2.):continue
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
  if presentation.is_reserved(p,1.):continue
  poles.append(Transform3D(basis,p+Vector3.UP*3.4));heads.append(Transform3D(basis,p+Vector3.UP*6.7+basis.x*.7));report.lamps+=1
 var pole_mesh:=BoxMesh.new();pole_mesh.size=Vector3(.16,6.8,.16);author.batch(details,pole_mesh,poles,"33413c")
 var head_mesh:=BoxMesh.new();head_mesh.size=Vector3(1.6,.14,.4);author.batch(details,head_mesh,heads,"c8c5ae")
 presentation.attach_bakes()
 report.placements=presentation.placements
 return report
func heritage_precinct(parent: Node3D) -> void:
 for landmark in author.geography.get("landmarks",[]):
  var center:=Vector3(landmark.center[0],0,landmark.center[1]);center.y=author.ground(center.x,center.z)
  var temple: Node3D=presentation.imported_precinct(parent,"tooth_temple",center)
  temple.set_meta("protected_asset",landmark.id);report.heritage_precinct=landmark.id
 var stupa_position:=Vector3(-530.,0.,-135.);stupa_position.y=author.ground(stupa_position.x,stupa_position.z)
 var stupa: Node3D=presentation.imported_precinct(parent,"mahaweli",stupa_position)
 stupa.set_meta("protected_asset","mahaweli_seya");presentation.foundation(stupa,26.)
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
