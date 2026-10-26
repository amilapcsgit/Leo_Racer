extends RefCounted
## Deterministic physical scenery; positions are in the existing course frame.
var author: Node3D
var reserved: Array[Dictionary]=[]
var textures: Dictionary={}
var placements: Array=[]
func _init(owner_author: Node3D) -> void:
 author=owner_author
 for i in int(author.length/230.):
  var s:=105.+i*230.;reserved.append({"position":author.sample(s,-27.),"radius":12.,"station":s,"kind":"advert"})
 reserved.append({"position":author.sample(0.,-23.),"radius":12.,"station":0.,"kind":"welcome"})
 for i in 4:
  var s: float=author.length*(.12+i*.14);reserved.append({"position":author.sample(s,-23.),"radius":9.,"station":s,"kind":"sector"})
 for entry in [["ceypetco",.08,-46.,20.],["buddha",.46,-75.,24.],["jungle_temple",.67,-58.,23.]]:
  var p: Vector3=author.sample(author.length*entry[1],entry[2]);reserved.append({"position":p,"radius":entry[3],"station":author.length*entry[1],"kind":entry[0]})
 for i in int(author.length/130.):
  var s:=160.+i*130.;var p: Vector3=author.sample(s,-21.5)
  if not is_reserved(p,3.):reserved.append({"position":p,"radius":7.,"station":s,"kind":"shop","art":["tea-shop","cafe","bakery","market"][i%4]})
func is_reserved(p: Vector3,extra: float=0.) -> bool:
 for polygon in author.landmark_exclusions:
  if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):return true
 for area in reserved:
  if Vector2(p.x-area.position.x,p.z-area.position.z).length()<area.radius+extra:return true
 return false
func texture(name: String) -> StandardMaterial3D:
 if textures.has(name):return textures[name]
 var m:=StandardMaterial3D.new();m.albedo_texture=load("res://art/signs/"+name+".png");m.roughness=.86;m.metallic_specular=.12;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC;textures[name]=m;return m
func face(parent: Node3D,name: String,size: Vector2,offset: Vector3) -> void:
 var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size;mesh.mesh=quad;mesh.position=offset;mesh.material_override=texture(name);mesh.set_meta("physical_sign",name);parent.add_child(mesh)
func board(parent: Node3D,p: Vector3,target: Vector3,name: String,size: Vector2,height: float) -> Node3D:
 var root:=Node3D.new();root.name="PhysicalSign_"+name;root.position=p;root.position.y=author.ground(p.x,p.z);var toward:=target-p;root.rotation.y=atan2(toward.x,toward.z);root.set_meta("physical_sign",name);parent.add_child(root)
 author.box(root,Vector3(size.x+.22,size.y+.22,.22),Vector3(0,height,0),"26362d")
 for x in [-size.x*.36,size.x*.36]:author.box(root,Vector3(.18,height+.25,.18),Vector3(x,(height+.25)*.5,-.08),"48534b")
 face(root,name,size,Vector3(0,height,.125))
 placements.append({"kind":"sign","name":name,"position":[root.position.x,root.position.y,root.position.z],"width":size.x,"height":size.y})
 return root
func billboard(parent: Node3D,index: int) -> void:
 var area: Dictionary=reserved[index];var s: float=area.station
 var root:=board(parent,area.position,author.sample(s-50.)+Vector3.UP*4.,"tourism" if index%2==0 else "tea-shop",Vector2(9.,4.5 if index%2==0 else 3.),5.4)
 root.set_meta("advert_station",s);root.set_meta("outer_offset",-27.);root.set_meta("sign_clearance",12.)
func flag(parent: Node3D,distance: float,index: int) -> bool:
 var p: Vector3=author.sample(distance,13. if index%2==0 else -14.)
 if is_reserved(p,2.):return false
 var root:=Node3D.new();root.name="SriLankaFlag%02d"%index;root.position=p;root.position.y=author.ground(p.x,p.z)
 var toward: Vector3=author.sample(distance-18.)-p;root.rotation.y=atan2(toward.x,toward.z);parent.add_child(root)
 author.box(root,Vector3(.10,6.,.1),Vector3(0,3.,0),"b8b4a4")
 # Explicit +Z-facing grid: UV.x=0 (green hoist stripe) is at the pole.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in 20:
  for y in 6:
   for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
    var uv:=Vector2(float(x+corner.x)/20.,float(y+corner.y)/6.)
    st.set_uv(uv);st.set_normal(Vector3.BACK);st.add_vertex(Vector3(.08+uv.x*2.4,5.7-uv.y*1.2,0))
 var node:=MeshInstance3D.new();node.mesh=st.commit();node.set_meta("flag_hoist_uv",0.)
 if not textures.has("flag"):
  var m:=ShaderMaterial.new();m.shader=load("res://shared/sri_flag.gdshader");m.set_shader_parameter("flag_map",load("res://shared/sri_lanka_flag.svg"));textures.flag=m
 node.material_override=textures.flag;root.add_child(node);return true
func sign_set(parent: Node3D) -> void:
 board(parent,author.sample(0,-23.),author.sample(-30.),"welcome",Vector2(6.,3.),3.1)
 for i in 4:
  var s: float=author.length*(.12+i*.14);board(parent,author.sample(s,-23.),author.sample(s-35.),"sector-%d"%i,Vector2(6.,2.),3.)
 for area in reserved:
  if area.kind=="shop":board(parent,area.position,author.sample(area.station-12.),area.art,Vector2(4.8,1.6),2.8)
func attach_bakes() -> void:
 if "--use-lightmaps" not in OS.get_cmdline_user_args():return
 for parent in [author.get_node("Resident"),author.get_node("Details")]:
  for node in parent.get_children():
   if not node.has_meta("baked_precinct"):continue
   var path: String="res://baked/"+String(node.name)+".tscn"
   if not ResourceLoader.exists(path):continue
   var baked: Node3D=load(path).instantiate();var gi:=baked.get_node("BakedIndirectLight") as LightmapGI
   if not gi.light_data or gi.light_data.lightmap_textures.is_empty():push_error("Missing baked indirect light: "+path);continue
   var sun:=baked.get_node_or_null("BakeSun")
   if sun:sun.free()
   var environment:=baked.get_node_or_null("BakeEnvironment")
   if environment:environment.free()
   baked.transform=node.transform;baked.name=node.name;baked.set_meta("baked_precinct",true)
   for key in node.get_meta_list():baked.set_meta(key,node.get_meta(key))
   parent.remove_child(node);node.free();parent.add_child(baked)
   print("BAKED_PRECINCT_ATTACHED ",path)
func arch(parent: Node3D) -> Node3D:
 var root:=Node3D.new();root.name="KandyStartArch";root.transform=Transform3D(author.frame(6.),author.sample(6.));root.set_meta("start_arch",true);root.set_meta("baked_precinct",true);parent.add_child(root)
 var half: float=author.road_half+1.8
 for side in [-1.,1.]:
  var base: Vector3=root.global_transform*Vector3(side*half,0,0);var depth: float=maxf(.3,root.position.y-author.ground(base.x,base.z))
  author.box(root,Vector3(1.4,depth+.25,1.4),Vector3(side*half,-depth*.5,0),"b6b3a7")
  for z in [-.4,.4]:author.box(root,Vector3(.18,7.9,.18),Vector3(side*half,3.95,z),"bbc3c0")
  for i in 7:
   var beam: MeshInstance3D=author.box(root,Vector3(.14,1.5,.14),Vector3(side*half,.6+i,0),"909e99");beam.rotation.x=PI*.25*(1. if i%2 else -1.)
 for y in [7.15,8.35]:
  for z in [-.4,.4]:author.box(root,Vector3(half*2.+.8,.16,.16),Vector3(0,y,z),"bbc3c0")
 for i in 15:
  var beam: MeshInstance3D=author.box(root,Vector3(1.7,.12,.12),Vector3(-half+.75+i*(half*2./15.),7.75,0),"909e99");beam.rotation.z=PI*.25*(1. if i%2 else -1.)
 author.box(root,Vector3(half*1.72,2.0,.12),Vector3(0,7.65,0),"173c34")
 face(root,"start",Vector2(half*1.7,1.98),Vector3(0,7.65,.52))
 var back:=Node3D.new();back.rotation.y=PI;root.add_child(back);face(back,"start",Vector2(half*1.7,1.98),Vector3(0,7.65,.52))
 return root
func imported_precinct(parent: Node3D,key: String,p: Vector3,yaw: float=0.) -> Node3D:
 var root:=Node3D.new();root.name="KandyPrecinct_"+key;root.position=p;root.position.y=author.ground(p.x,p.z);root.rotation.y=yaw;root.set_meta("baked_precinct",true);root.set_meta("protected_asset",key);parent.add_child(root)
 var model: Node3D=load("res://shared/landmarks/"+key+".glb").instantiate();root.add_child(model)
 if key=="tooth_temple":
  var nearest:=Vector3.ZERO;var best:=INF
  for point in author.points:
   var distance: float=Vector2(point.x-p.x,point.z-p.z).length()
   if distance<best:best=distance;nearest=point
  var away:=Vector3(p.x-nearest.x,0,p.z-nearest.z).normalized()
  for iteration in 16:
   var bounds:=AABB();var first:=true
   for node in root.find_children("*","MeshInstance3D",true,false):
    var box: AABB=node.global_transform*node.get_aabb();bounds=box if first else bounds.merge(box);first=false
   var clearance:=INF
   for x in [bounds.position.x,bounds.end.x]:
    for z in [bounds.position.z,bounds.end.z]:clearance=minf(clearance,author.terrain_cutter.distance(Vector2(x,z)))
   if clearance>=17.:break
   root.position+=away*2.;root.position.y=author.ground(root.position.x,root.position.z)
 if key=="tooth_temple":
  var bounds:=AABB();var first:=true
  for node in root.find_children("*","MeshInstance3D",true,false):
   var box: AABB=node.global_transform*node.get_aabb();bounds=box if first else bounds.merge(box);first=false
  reserved.append({"position":bounds.get_center(),"radius":Vector2(bounds.size.x,bounds.size.z).length()*.5+5.,"kind":"temple_clearance"})
 placements.append({"kind":"landmark","name":key,"position":[root.position.x,root.position.y,root.position.z]})
 return root
func extra_landmarks(parent: Node3D) -> void:
 for area in reserved:
  if area.kind not in ["buddha","jungle_temple","ceypetco"]:continue
  var toward: Vector3=author.sample(area.station)-area.position
  var root:=imported_precinct(parent,area.kind,area.position,atan2(toward.x,toward.z))
  var size:=24. if area.kind=="ceypetco" else 16.
  foundation(root,size)
func foundation(root: Node3D,radius: float) -> void:
 # A beveled terrain transition follows all perimeter ground samples, not a floating slab.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 48:
  var a:=TAU*i/48.;var b:=TAU*(i+1)/48.
  var inner_a:=Vector3(cos(a)*radius,.025,sin(a)*radius);var inner_b:=Vector3(cos(b)*radius,.025,sin(b)*radius)
  var outer_a:=Vector3(cos(a)*(radius+6.),0,sin(a)*(radius+6.));var outer_b:=Vector3(cos(b)*(radius+6.),0,sin(b)*(radius+6.))
  var wa: Vector3=root.global_transform*outer_a;var wb: Vector3=root.global_transform*outer_b;outer_a.y=author.ground(wa.x,wa.z)-root.position.y-.03;outer_b.y=author.ground(wb.x,wb.z)-root.position.y-.03
  for v in [Vector3(0,.025,0),inner_b,inner_a,inner_a,inner_b,outer_a,inner_b,outer_b,outer_a]:st.set_uv(Vector2(v.x,v.z)*.1);st.add_vertex(v)
 st.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=author.material("bfc0ac");mesh.set_meta("surface_role","landmark_ground");root.add_child(mesh)
func mountains(parent: Node3D) -> void:
 for layer in 3:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var radius:=1800.+layer*650.
  for i in 256:
   var a:=TAU*i/256.;var b:=TAU*(i+1)/256.
   var ha:=120.+layer*75.+pow(.5+.5*sin(a*7.+layer*2.),2.)*130.+sin(a*13.)*24.
   var hb:=120.+layer*75.+pow(.5+.5*sin(b*7.+layer*2.),2.)*130.+sin(b*13.)*24.
   var va:=Vector3(sin(a)*radius,ha,cos(a)*radius);var vb:=Vector3(sin(b)*radius,hb,cos(b)*radius)
   var ca:=Vector3(sin(a)*(radius+500.),-70,cos(a)*(radius+500.));var cb:=Vector3(sin(b)*(radius+500.),-70,cos(b)*(radius+500.))
   var ia:=Vector3(sin(a)*(radius-450.),-70.,cos(a)*(radius-450.));var ib:=Vector3(sin(b)*(radius-450.),-70.,cos(b)*(radius-450.))
   for v in [va,vb,ca,vb,cb,ca,va,ia,vb,vb,ia,ib]:st.add_vertex(v)
  st.generate_normals();var mesh:=MeshInstance3D.new();mesh.name="DistantMountainLayer%d"%layer;mesh.mesh=st.commit()
  var mat:=ShaderMaterial.new();mat.shader=load("res://shared/kandy_mountains.gdshader");mat.set_shader_parameter("distance_tint",[Color("4b6a5b"),Color("758e87"),Color("93a5a6")][layer]);mesh.material_override=mat
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.set_meta("surface_role","distant_mountains");parent.add_child(mesh)
