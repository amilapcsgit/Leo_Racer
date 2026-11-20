extends RefCounted

const VV = "res://assets/Vehera Vihara [1.0]/FBX/"
const LK = "res://assets/Landu Kelae [1.0]/FBX/"
const SB = "res://assets/Stone Blocks [1.0]/FBX/"
const TILE_TEXTURE = "res://assets/Vehera Vihara [1.0]/Textures/RoofTile-Diffuse.png"
var assets := {}
var route: PackedVector3Array
var lake: PackedVector2Array
var tile: StandardMaterial3D

func setup(course: Dictionary, geography: Dictionary):
 for p in course.points:route.append(Vector3(p[0],p[1],p[2]))
 for p in geography.lake:lake.append(Vector2(p[0],p[1]))
 if lake[0].is_equal_approx(lake[-1]):lake.resize(lake.size()-1)
 tile=mat("a86449")
 tile.albedo_texture=load(TILE_TEXTURE)
 tile.uv1_triplanar=true
 tile.uv1_scale=Vector3.ONE*1.5

func mat(color: String) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=Color(color)
 m.roughness=.84
 return m

func bounds(node: Node3D, parent:=Transform3D.IDENTITY) -> AABB:
 var pose:=parent*node.transform
 var result: AABB=pose*node.get_aabb() if node is MeshInstance3D else AABB()
 for child in node.get_children():
  if child is Node3D:
   var child_box:=bounds(child,pose)
   if child_box.has_surface():result=result.merge(child_box) if result.has_surface() else child_box
 return result

func model(path: String) -> Dictionary:
 if not assets.has(path):
  var instance: Node3D=load(path).instantiate()
  assets[path]={"scene":load(path),"bounds":bounds(instance)}
  instance.free()
 return assets[path]

func place(parent: Node3D, path: String, id: String, point: Vector3, size: Vector3, orientation:=Basis.IDENTITY) -> Node3D:
 var definition:=model(path)
 var part: Node3D=definition.scene.instantiate()
 var b: AABB=definition.bounds
 var fit:=size/Vector3(maxf(.001,b.size.x),maxf(.001,b.size.y),maxf(.001,b.size.z))
 var basis:=orientation*Basis.from_scale(fit)
 var anchor:=Vector3(b.get_center().x,b.position.y,b.get_center().z)
 var pivot:=Node3D.new()
 pivot.name=id
 pivot.transform=Transform3D(orientation,point)
 pivot.set_meta("placement_id",id)
 pivot.set_meta("source_asset",path)
 parent.add_child(pivot)
 part.transform=Transform3D(Basis.from_scale(fit), -(Basis.from_scale(fit)*anchor))*part.transform
 pivot.add_child(part)
 return pivot

func scenery_group(parent: Node3D, label: String) -> Node3D:
 var group:=Node3D.new()
 group.name=label
 parent.add_child(group)
 return group

func nearest(point: Vector2) -> Vector3:
 var best:=INF
 var hit:=Vector3.ZERO
 for i in route.size():
  var a:=route[i]
  var b:=route[(i+1)%route.size()]
  var start:=Vector2(a.x,a.z)
  var end:=Vector2(b.x,b.z)
  var p:=Geometry2D.get_closest_point_to_segment(point,start,end)
  var distance:=p.distance_squared_to(point)
  if distance<best:
   best=distance
   hit=a.lerp(b,start.distance_to(p)/maxf(.001,start.distance_to(end)))
 return hit

func clearance(point: Vector2, track: Vector3) -> float:
 return point.distance_to(Vector2(track.x,track.z))

func old_wall(node: Node) -> bool:
 if not node is MultiMeshInstance3D or not node.has_meta("cell"):return false
 var size: Vector3=node.multimesh.mesh.get_aabb().size
 return (node.multimesh.mesh is BoxMesh and absf(size.x-.45)<.005 and absf(size.y-.65)<.005) or (node.multimesh.mesh is SphereMesh and absf(size.y-1.1)<.005)

func shore(parent: Node3D, resident: Node3D):
 var group:=scenery_group(parent,"Walakulu_Bemma_and_paving")
 var index:=0
 var plaster:=mat("efe9d9")
 var source:=load("res://assets/Vehera Vihara [1.0]/Textures/WalakuluBemma-Diffuse.png") as Texture2D
 var texture:=source.get_image()
 if texture.is_compressed():texture.decompress()
 texture.resize(512,512)
 texture.convert(Image.FORMAT_RGBA8)
 for y in 512:
  for x in 512:
   var p:=texture.get_pixel(x,y)
   var value:=.48+.49*p.get_luminance()
   texture.set_pixel(x,y,Color(value,value,value,p.a))
 texture.generate_mipmaps()
 plaster.albedo_texture=ImageTexture.create_from_image(texture)
 for old in resident.get_children():
  if not old_wall(old) or not old.multimesh.mesh is BoxMesh:continue
  var data: PackedFloat32Array=old.get_meta("instance_buffer")
  for i in old.multimesh.instance_count:
   var j: int=i*12
   var p:=Vector3(data[j+3],data[j+7],data[j+11])
   var tangent:=Vector3(data[j+2],data[j+6],data[j+10]).normalized()
   var right:=Vector3(data[j],data[j+4],data[j+8]).normalized()
   var basis:=Basis(tangent,Vector3.UP,-right).orthonormalized()
   var span: float=old.multimesh.mesh.get_aabb().size.z
   var before:=nearest(Vector2(p.x,p.z)-Vector2(tangent.x,tangent.z)*5.)
   var after:=nearest(Vector2(p.x,p.z)+Vector2(tangent.x,tangent.z)*5.)
   var curved:=Vector2(after.x-before.x,after.z-before.z).normalized().dot(Vector2(tangent.x,tangent.z))<.995
   var opening:=p.distance_to(Vector3(-9.,4.5,-248.))<2.2 or p.distance_to(Vector3(-378.,3.7,-232.))<2.2
   var count:=3 if curved else 2
   var panel_width:=span/count
   for part_index in count:
    if opening and part_index==1:continue
    var center: Vector3=p+tangent*((part_index+.5)*panel_width-span*.5)-Vector3.UP*.325
    var module:="VV-WalakuluBemma-5.fbx" if opening else "VV-WalakuluBemma-1.fbx"
    var panel:=place(group,VV+module,"CloudWall_%04d"%index,center,Vector3(panel_width+.018,1.32,.42),basis)
    detach_asset(panel)
    for part in panel.find_children("*","MeshInstance3D",true,false):part.material_override=plaster
    index+=1
   if not opening:
    place(group,SB+"Stone-Blocks 1.fbx","Wall_Base_%04d"%index,p-Vector3.UP*.42,Vector3(span+.018,.19,.49),basis)
   else:
    for step in 3:
     place(group,SB+"Stone-Blocks 1.fbx","Promenade_Step_%04d_%d"%[index,step],p+right*(.32+step*.34)-Vector3.UP*(.53+step*.15),Vector3(panel_width,.22,.38),basis)
   if index%14==0:
    place(group,SB+"Stone-Tiles 1.fbx","Promenade_Inset_%04d"%index,p+right*.8-Vector3.UP*.31,Vector3(span,.045,.6),basis)
 print("KANDY_WALL_MODULES ",index)

func temple(parent: Node3D, anchor: Transform3D, old_bounds: AABB):
 var group:=scenery_group(parent,"Temple_of_the_Tooth")
 group.transform=anchor
 var raw:=model("res://assets/temple.glb")
 var measured: AABB=raw.bounds
 var ratio:=minf(old_bounds.size.x/measured.size.x,old_bounds.size.z/measured.size.z)
 ratio=clampf(ratio,.22,1.15)
 var site:=Vector3(old_bounds.get_center().x,old_bounds.position.y,old_bounds.get_center().z)
 var temple_model:=place(group,"res://assets/temple.glb","Supplied_Temple",site,measured.size*ratio)
 detach_asset(temple_model)
 var roofs=["empty_33","empty_69","empty_505"]
 for mesh in temple_model.find_children("*","MeshInstance3D",true,false):
  if mesh.name in roofs:
   for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,tile)
   var footprint: AABB=(group.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
   temple_eaves(group,"Temple_Eaves_"+str(mesh.name),footprint,mesh.name in ["empty_33","empty_69"])
 var entry_z:=site.z+measured.size.z*ratio*.5+1.7
 var court:=scenery_group(group,"Shrine_Courtyard")
 for item in [
  ["VV-BuddhaStatue-1",Vector3(0,.66,-2.8),Vector3(.95,1.45,.9)],
  ["VV-Muragala.L",Vector3(-1.38,0,0),Vector3(.62,1.26,.5)],
  ["VV-Muragala.R",Vector3(1.38,0,0),Vector3(.62,1.26,.5)],
  ["VV-Sadakadapahana",Vector3(0,0,1.08),Vector3(2.25,.17,1.29)],
  ["VV-RoofPillar1",Vector3(-1.7,0,-3.9),Vector3(.35,3.1,.38)],
  ["VV-RoofPillar1",Vector3(1.7,0,-3.9),Vector3(.35,3.1,.38)] ]:
  place(court,VV+item[0]+".fbx",item[0].replace(".","_"),Vector3(site.x,site.y,entry_z)+item[1],item[2])
 for i in 3:
  place(court,SB+"Stone-Blocks 1.fbx","CourtStep_%d"%i,Vector3(site.x,site.y+i*.17,entry_z-.45-i*.47),Vector3(2.5,.18,.56))
 for side in [-1.,1.]:
  var entrance:=Vector3(site.x+side*6.4,site.y,entry_z-2.8)
  var wing:=scenery_group(court,"Side_Entrance_W" if side<0. else "Side_Entrance_E")
  dress_entrance(wing,entrance,"VV-BuddhaStatue-2" if side<0. else "VV-BuddhaStatue-3")
 roof(court,"Shrine_Tiled_Roof",Vector3(site.x,site.y+3.,entry_z-3.1),4.4,3.6,.42)
 for x in [-9.,9.]:
  var lamp:=OmniLight3D.new()
  lamp.position=Vector3(site.x+x,site.y+2.8,entry_z-4.)
  lamp.light_color=Color("ffbc7c")
  lamp.light_energy=.65
  lamp.omni_range=13.
  group.add_child(lamp)
 print("KANDY_TEMPLE source=",measured," stock=",old_bounds," fit=",ratio," origin=",site)

func temple_eaves(parent: Node3D, label: String, footprint: AABB, octagonal: bool):
 var eaves:=scenery_group(parent,label)
 if not timber:
  timber=mat("554032")
  stucco=mat("ddd3bc")
 var center:=footprint.get_center()
 var half:=Vector2(footprint.size.x,footprint.size.z)*.43
 var rim:=PackedVector2Array()
 if octagonal:
  for corner in 8:
   var angle:=TAU*(corner+.5)/8.
   rim.append(Vector2(cos(angle),sin(angle))*half)
 else:
  rim=PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
 for i in rim.size():
  var a:=rim[i]
  var b:=rim[(i+1)%rim.size()]
  var mid:=(a+b)*.5
  var trim:=block(eaves,Vector3(center.x+mid.x,footprint.position.y-.05,center.z+mid.y),Vector3(a.distance_to(b)+.035,.14,.18),timber)
  trim.name="Roof_Plate_%02d"%i
  trim.rotation.y=-atan2(b.y-a.y,b.x-a.x)

func dress_entrance(parent: Node3D, origin: Vector3, statue: String):
 place(parent,VV+statue+".fbx","Buddha",origin+Vector3(0,.55,-1.55),Vector3(.9,1.4,.75))
 place(parent,SB+"Stone-Tiles 1.fbx","Landing",origin+Vector3(0,.31,-.9),Vector3(2.6,.21,2.6))
 place(parent,VV+"VV-Sadakadapahana.fbx","Moonstone",origin+Vector3(0,.02,1.22),Vector3(1.5,.15,.9))
 for side in [-1.,1.]:
  var file:="VV-Muragala.L.fbx" if side<0. else "VV-Muragala.R.fbx"
  place(parent,VV+file,"Guardstone_L" if side<0. else "Guardstone_R",origin+Vector3(side*1.1,.11,.8),Vector3(.44,.94,.37))
 for step in 3:
  place(parent,SB+"Stone-Blocks 1.fbx","Stair_%d"%step,origin+Vector3(0,.10*step,.83-step*.32),Vector3(2.,.16,.39))

var timber: StandardMaterial3D
var stucco: StandardMaterial3D

func roof_structure(parent: Node3D, width: float, depth: float, pitch: float):
 if not timber:
  timber=mat("554032")
  stucco=mat("ddd3bc")
 var half:=depth*.5
 var rise:=half*tan(pitch)
 var rafter_length:=half/cos(pitch)
 var gable:=SurfaceTool.new()
 gable.begin(Mesh.PRIMITIVE_TRIANGLES)
 for end in [-1.,1.]:
  var x: float=end*(width*.5-.15)
  var a:=Vector3(x,-.04,-half+.08)
  var b:=Vector3(x,rise-.10,0.)
  var c:=Vector3(x,-.04,half-.08)
  var vertices: Array=[a,b,c] if end<0. else [c,b,a]
  for v in vertices:
   gable.set_normal(Vector3(end,0.,0.))
   gable.add_vertex(v)
 var ends:=MeshInstance3D.new()
 ends.name="Closed_Gable_Ends"
 ends.mesh=gable.commit()
 ends.material_override=stucco
 ends.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
 parent.add_child(ends)
 for side in [-1.,1.]:
  var soffit:=block(parent,Vector3(0.,rise*.5-.10,side*half*.5),Vector3(width-.05,.115,rafter_length),timber)
  soffit.name="Sloped_Soffit"
  soffit.rotation.x=side*pitch
  block(parent,Vector3(0.,-.045,side*half),Vector3(width+.012,.18,.16),timber).name="Eave_Fascia"
  for end in [-1.,1.]:
   var barge:=block(parent,Vector3(end*width*.5,rise*.5-.035,side*half*.5),Vector3(.15,.16,rafter_length+.13),timber)
   barge.name="Bargeboard"
   barge.rotation.x=side*pitch
 block(parent,Vector3(0.,rise-.115,0.),Vector3(width,.18,.22),timber).name="Ridge_Beam"

func roof(parent: Node3D, id: String, center: Vector3, width: float, depth: float, pitch: float):
 var gable:=scenery_group(parent,id)
 gable.position=center
 roof_structure(gable,width,depth,pitch)
 var count:=maxi(2,roundi(width/1.6))
 var span:=width/count
 for side in [-1.,1.]:
  for i in count:
   var panel:=place(gable,VV+"VV-RoofTile0.fbx","Tiles_%s_%02d"%["N" if side<0. else "S",i],Vector3(-width*.5+span*(i+.5),depth*.25*tan(pitch),side*depth*.25),Vector3(span+.018,.21,depth*.5/cos(pitch)+.07),Basis(Vector3.RIGHT,side*pitch))
   panel.set_meta("roof_panel",true)
 for i in count:
  place(gable,VV+"VV-RoofTile0.fbx","Ridge_%02d"%i,Vector3(-width*.5+span*(i+.5),depth*.5*tan(pitch)+.1,0),Vector3(span+.018,.17,.32))

func town(cell: Node3D, id: String):
 var serial:=0
 for original in cell.get_children():
  if not original is Node3D or original is VisualInstance3D or original is CollisionObject3D or original.get_meta("protected_asset","")!="":continue
  if not original.name.begins_with("_Node3D_") and not original.name in ["shophouse","tea_shop","bakery","lake_residence","garden_cafe","market_terrace","commercial_corner","fort_corner"]:continue
  if original.get_meta("physical_sign",false):continue
  var b:=bounds(original)
  if b.size.x<5.5 or b.size.z<5.5 or b.size.x>25. or b.size.z>23. or b.size.y<4. or b.size.y>16.:continue
  serial+=1
  if serial%3!=1:continue
  var local:=bounds(original,original.transform.affine_inverse())
  var container:=scenery_group(cell,"Roof_"+str(original.name))
  container.transform=original.transform
  roof(container,"Terracotta_Gable",Vector3(local.get_center().x,local.end.y-.08,local.get_center().z),local.size.x+.45,local.size.z+.48,.29 if serial%2==0 else .42)

func vegetation(cell: Node3D, remove: bool):
 for batch in cell.get_children():
  if not batch is MultiMeshInstance3D:continue
  var asset:=String(batch.get_meta("shared_asset",""))
  if not ("tree" in asset or "palm" in asset or "bush" in asset):continue
  var data: PackedFloat32Array=batch.get_meta("instance_buffer",PackedFloat32Array())
  if data.size()!=batch.multimesh.instance_count*12:continue
  var decor:=scenery_group(cell,"Landu_Kelae_"+str(batch.name).trim_prefix("_"))
  var original_height: float=batch.multimesh.mesh.get_aabb().size.y
  for i in batch.multimesh.instance_count:
   var j: int=i*12
   var point:=Vector3(data[j+3],data[j+7],data[j+11])
   var height:=maxf(.5,original_height*absf(data[j+5]))
   var file := "LK-Trunk1-Leaves%d"%(1+i%4)
   var chooser:=RandomNumberGenerator.new()
   chooser.seed=hash(Vector3i(roundi(point.x*10.),roundi(point.y*10.),roundi(point.z*10.)))
   if not "bush" in asset:
    var distance:=clearance(Vector2(point.x,point.z),nearest(Vector2(point.x,point.z)))
    height*=chooser.randf_range(1.15,1.40) if distance>20. and point.distance_to(Vector3(-8,4,-289))>35. else chooser.randf_range(1.,1.16)
   var width:=height*.76
   if "bush" in asset:
    file="LK-Bush-Fern" if i%3==0 else "LK-Bush2"
    width=height*1.25
   elif "palm" in asset:
    file="LK-Coconut%d"%(1+i%4)
    width=height*.67
   elif point.distance_to(Vector3(-8,4,-289))<65.:
    file="LK-Bo"
   var rotation:=Basis(Vector3.UP,atan2(data[j+2],data[j+10])+chooser.randf_range(-.45,.45))
   if file.begins_with("LK-Trunk"):
    broadleaf(decor,file,"Plant_%03d"%i,point,Vector3(width,height,width),rotation,i%11==3)
   else:
    place(decor,LK+file+".fbx","Plant_%03d"%i,point,Vector3(width,height,width),rotation)
  if remove:batch.free()

var blossoms := {}
func flowering(tree: Node3D):
 for mesh in tree.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var m:=mesh.get_active_material(surface) as StandardMaterial3D
   if not m or not m.albedo_texture or not "leaves" in m.albedo_texture.resource_path.to_lower():continue
   if not blossoms.has(m):
    var colored:=m.duplicate() as StandardMaterial3D
    var pixels:=m.albedo_texture.get_image()
    if pixels.is_compressed():pixels.decompress()
    pixels.resize(256,256)
    pixels.convert(Image.FORMAT_RGBA8)
    for y in 256:
     for x in 256:
      var c:=pixels.get_pixel(x,y)
      var n:=c.get_luminance()
      pixels.set_pixel(x,y,Color(.44+n*.54,.13+n*.51,.32+n*.6,c.a))
    pixels.generate_mipmaps()
    colored.albedo_color=Color.WHITE
    colored.albedo_texture=ImageTexture.create_from_image(pixels)
    blossoms[m]=colored
   mesh.set_surface_override_material(surface,blossoms[m])

func block(parent: Node3D, at: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
 var part:=MeshInstance3D.new()
 var box:=BoxMesh.new()
 box.size=size
 part.mesh=box
 part.material_override=material
 part.position=at
 parent.add_child(part)
 return part

func round_block(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, material: StandardMaterial3D):
 var part:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new()
 mesh.top_radius=top
 mesh.bottom_radius=bottom
 mesh.height=height
 mesh.radial_segments=24
 part.mesh=mesh
 part.position=at
 part.material_override=material
 parent.add_child(part)

func hotel(parent: Node3D):
 var h:=scenery_group(parent,"Queens_Hotel")
 h.position=Vector3(-95.0,4.83,-287.6)
 h.rotation.y=.06
 var plaster:=mat("e5e0d7")
 var glazing:=mat("343b41")
 var iron:=mat("514944")
 block(h,Vector3(-5,5.05,-1.0),Vector3(31,10.1,9.6),plaster)
 block(h,Vector3(7.7,5.05,-9),Vector3(9,10.1,18),plaster)
 for i in 9:
  var x:=-19.+3.2*i
  block(h,Vector3(x,1.37,3.85),Vector3(1.8,2.74,.14),glazing)
  round_block(h,Vector3(x,2.74,3.9),.9,.9,.14,glazing)
  var opening: MeshInstance3D=h.get_child(-1)
  opening.rotation.x=PI*.5
  for angle in range(0,181,15):
   var theta:=deg_to_rad(angle)
   var stone:=block(h,Vector3(x+cos(theta)*1.01,2.74+sin(theta)*1.01,4.01),Vector3(.28,.23,.22),plaster)
   stone.rotation.z=theta
  block(h,Vector3(x-1.31,1.86,4.11),Vector3(.36,3.72,.45),plaster)
  for y in [5.25,8.35]:
   block(h,Vector3(x,y,3.89),Vector3(1.13,1.68,.12),glazing)
   block(h,Vector3(x,y-.87,4.03),Vector3(1.38,.2,.41),plaster)
  block(h,Vector3(x,10.63,2.8),Vector3(1.35,1.22,.8),plaster)
  block(h,Vector3(x,10.67,3.23),Vector3(.66,.77,.1),glazing)
  roof(h,"Dormer_%02d"%i,Vector3(x,11.12,2.8),1.57,1.18,.54)
 for y in [3.88,6.88,9.85]:
  block(h,Vector3(-5,y,4.),Vector3(31.1,.24,.68),plaster)
 for i in 25:
  block(h,Vector3(-19.5+i*1.24,4.3,4.49),Vector3(.11,.68,.13),iron)
 block(h,Vector3(-5,4.65,4.49),Vector3(30.5,.12,.18),iron)
 roof(h,"Hotel_Main_Roof",Vector3(-5,10.12,-1.0),31.4,9.95,.28)
 roof(h,"Hotel_Return_Roof",Vector3(7.7,10.12,-12.15),9.28,12.3,.29)
 var corner:=Vector3(10.7,0,3.2)
 round_block(h,corner+Vector3.UP*5.36,2.95,2.95,10.72,plaster)
 for y in [3.45,6.85,10.6]:
  round_block(h,corner+Vector3.UP*y,3.,3.15,.32,plaster)
 for i in 9:
  var turn:=TAU*i/9.
  for y in [5.35,8.65]:
   var pane:=block(h,corner+Vector3(cos(turn)*2.94,y,sin(turn)*2.94),Vector3(1.02,1.55,.17),glazing)
   pane.rotation.y=PI*.5-turn
 round_block(h,corner+Vector3.UP*11.58,3.11,1.82,1.65,plaster)
 round_block(h,corner+Vector3.UP*12.76,1.82,.86,.71,plaster)
 round_block(h,corner+Vector3.UP*13.34,.86,.08,.68,plaster)

func detach_asset(pivot: Node3D):
 var branch:=pivot.get_child(0)
 var flat:=preload("res://resource_baker.gd").new("user://kandy-temp","").flatten(branch)
 branch.free()
 pivot.add_child(flat)

func broadleaf(parent: Node3D, canopy: String, id: String, point: Vector3, size: Vector3, rotation: Basis, pink: bool):
 var tree:=scenery_group(parent,id)
 tree.position=point
 tree.basis=rotation
 var leaf:=model(LK+"LK-Tree Leaves/"+canopy+".fbx")
 var trunk:=model(LK+"LK-Tree Trunks/LK-Trunk1.fbx")
 var a: AABB=leaf.bounds
 var merged:=a.merge(trunk.bounds)
 var fit:=Basis.from_scale(size/merged.size)
 var anchor:=Vector3(merged.get_center().x,merged.position.y,merged.get_center().z)
 for definition in [trunk,leaf]:
  var node: Node3D=definition.scene.instantiate()
  node.transform=Transform3D(fit,-(fit*anchor))*node.transform
  if pink and definition==leaf:
   node=flatten_model(node)
  tree.add_child(node)
 if pink:flowering(tree)

func flatten_model(node: Node3D) -> Node3D:
 var flat: Node3D=preload("res://resource_baker.gd").new("user://kandy-temp","").flatten(node)
 node.free()
 return flat