class_name LeoCockpitSystems
extends Node3D
## Optional reviewed cockpit presentation. No physics or source material changes.
const MIRROR_BITS=[1<<18,1<<19]
var kart: LeoKart
var mirrors: Array[Dictionary]=[]
var screens: Array[Dictionary]=[]
var clock:=0.
var cursor:=0
var warmed:=false
var last_quality:=-1
static func install(owner_kart: LeoKart) -> void:
 if not owner_kart.is_player or not owner_kart.definition.official or String(owner_kart.definition.id) not in ["bigster","duster_2024"]:return
 var systems:=LeoCockpitSystems.new();systems.name="LiveCockpit";owner_kart.visual.add_child(systems);systems.setup(owner_kart)
func surface(view: SubViewport,at: Vector3,extent: Vector2,normal: Vector3,mirror: bool,parent: Node3D=null) -> MeshInstance3D:
 var plane:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=extent;plane.mesh=mesh
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=view.get_texture();material.cull_mode=BaseMaterial3D.CULL_DISABLED
 if mirror:material.uv1_scale=Vector3(-1,1,1);material.uv1_offset=Vector3(1,0,0)
 plane.material_override=material;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 plane.layers=MIRROR_BITS[kart.local_slot] if mirror else LeoCameraViews.BODY_BITS[kart.local_slot]
 add_child(plane);plane.position=at;plane.basis=Basis.looking_at(-normal.normalized(),Vector3.UP)
 if parent:
  var pose: Transform3D=kart.chassis.global_transform.affine_inverse()*plane.global_transform
  var parent_pose:=LeoVehicleFeatures.local_pose(parent,kart.chassis)
  remove_child(plane);parent.add_child(plane);plane.transform=parent_pose.affine_inverse()*pose
 return plane
func surface_overlay(view: SubViewport,source: MeshInstance3D,material_match: String,flip: bool=false) -> MeshInstance3D:
 if not source or not source.mesh:return null
 for i in source.mesh.get_surface_count():
  var original:=source.get_active_material(i)
  if not original or not material_match in String(original.resource_name).to_lower():continue
  var arrays:=source.mesh.surface_get_arrays(i)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var pose:=LeoVehicleFeatures.local_pose(source,kart.chassis)
  var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
  for point in vertices:
   var local_point:=pose*point;var xy:=Vector2(local_point.x,local_point.y);minimum=minimum.min(xy);maximum=maximum.max(xy)
  var uv:=PackedVector2Array();uv.resize(vertices.size())
  for n in vertices.size():
   var point:=pose*vertices[n];uv[n]=Vector2((point.x-minimum.x)/maxf(.001,maximum.x-minimum.x),1.-(point.y-minimum.y)/maxf(.001,maximum.y-minimum.y))
   if normals.size()==vertices.size():vertices[n]+=normals[n]*.0015
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var overlay:=MeshInstance3D.new();overlay.mesh=mesh;overlay.layers=MIRROR_BITS[kart.local_slot] if flip else LeoCameraViews.BODY_BITS[kart.local_slot];overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=view.get_texture();material.cull_mode=BaseMaterial3D.CULL_DISABLED
  if flip:material.uv1_scale=Vector3(-1,1,1);material.uv1_offset=Vector3(1,0,0)
  overlay.material_override=material;source.add_child(overlay);overlay.set_meta("reviewed_surface",String(original.resource_name));return overlay
 return null
func setup(owner_kart: LeoKart) -> void:
 kart=owner_kart
 var cluster:=display(false,Vector2i(512,200));surface(cluster,Vector3(-.348,1.064,-.684),Vector2(.305,.119),Vector3(0,.12,1),false)
 var navigation:=display(true,Vector2i(640,360));surface_overlay(navigation,kart.chassis.find_child("dust25_dash",true,false) as MeshInstance3D,"gps_screen")
 mirror("Rear",Vector3(0,1.435,-.41),Vector2(.265,.09),Vector3(-.25,-.08,1),Vector3(0,1.32,1.25),Vector3(0,-.08,1),kart.chassis.find_child("dust25_intermirror",true,false) as MeshInstance3D)
 for side in [-1.,1.]:
  var parent:=kart.chassis.find_child("dust25_mirror_L" if side<0 else "dust25_mirror_R",true,false) as Node3D
  mirror("Left" if side<0 else "Right",Vector3(side*.947,1.205,-.465),Vector2(.16,.09),Vector3(-side*.45,0,1),Vector3(side*1.04,1.22,-.48),Vector3(side*.24,-.08,1),parent)
func display(navigation: bool,extent: Vector2i) -> SubViewport:
 var view:=SubViewport.new();view.disable_3d=true;view.size=extent;view.render_target_update_mode=SubViewport.UPDATE_DISABLED;view.gui_disable_input=true;add_child(view)
 var canvas:=LeoCockpitCanvas.new();canvas.kart=kart;canvas.navigation=navigation;canvas.size=Vector2(extent);view.add_child(canvas);screens.append({"view":view,"canvas":canvas,"next":0.})
 return view
func mirror(title: String,at: Vector3,extent: Vector2,normal: Vector3,eye: Vector3,direction: Vector3,parent: Node3D) -> void:
 var view:=SubViewport.new();view.name=title+"MirrorView";view.size=Vector2i(256,128);view.world_3d=kart.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 view.positional_shadow_atlas_size=0;view.msaa_3d=Viewport.MSAA_DISABLED;view.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED;view.gui_disable_input=true;add_child(view)
 var camera:=Camera3D.new();camera.fov=62.;camera.near=.06;camera.far=180.;camera.current=true;view.mesh_lod_threshold=3.
 camera.cull_mask=((1<<20)-1)&~(MIRROR_BITS[0]|MIRROR_BITS[1]|(1<<16)|LeoCameraViews.BODY_BITS[kart.local_slot]|LeoCameraViews.DRIVER_BITS[kart.local_slot])
 var source: Environment=kart.get_parent().get("environment")
 if source:
  camera.environment=source.duplicate();camera.environment.glow_enabled=false;camera.environment.ssao_enabled=false;camera.environment.ssil_enabled=false;camera.environment.ssr_enabled=false
 view.add_child(camera)
 var plane:=surface_overlay(view,parent as MeshInstance3D,"mirror",true)
 if not plane:plane=surface(view,at,extent,normal,true,parent)
 plane.name=title+"LiveMirror"
 mirrors.append({"view":view,"camera":camera,"eye":eye,"direction":direction,"surface":plane,"renders":0})
func active() -> bool:
 var locals: Array=kart.get_parent().local_players
 return kart.local_slot<locals.size() and not locals[kart.local_slot].photo and locals[kart.local_slot].kart==kart and LeoCameraViews.effective(locals[kart.local_slot])=="cockpit"
func apply_quality() -> void:
 for row in mirrors:
  row.view.size=Vector2i(128,64);row.camera.far=80.
func mirror_visible(row: Dictionary) -> bool:
 if row.surface.name=="RearLiveMirror":return true
 var local: LeoLocalPlayer=kart.get_parent().local_players[kart.local_slot]
 var yaw: float=local.camera_rig.head_offset.x
 if absf(yaw)<deg_to_rad(12.):return false
 if (row.surface.name=="LeftLiveMirror")!=(yaw>0.):return false
 var camera: Camera3D=local.camera
 var point: Vector3=row.surface.global_transform*row.surface.get_aabb().get_center()
 if camera.is_position_behind(point):return false
 var screen:=camera.unproject_position(point)
 return camera.get_viewport().get_visible_rect().grow(24.).has_point(screen)
func update_mirror(row: Dictionary) -> void:
 apply_quality()
 var pose:=kart.visual.global_transform;var camera: Camera3D=row.camera
 camera.global_position=pose*row.eye;camera.look_at(camera.global_position+pose.basis*row.direction,pose.basis.y)
 row.view.render_target_update_mode=SubViewport.UPDATE_ONCE;row.renders+=1
func warm() -> void:
 for row in mirrors:
  if row.surface.name=="RearLiveMirror":update_mirror(row)
 for row in screens:row.canvas.queue_redraw();row.view.render_target_update_mode=SubViewport.UPDATE_ONCE
 warmed=true
func _process(dt: float) -> void:
 if not is_instance_valid(kart):return
 clock+=dt
 var enabled:=active()
 for row in mirrors:row.surface.visible=enabled and mirror_visible(row)
 if not enabled:return
 for row in screens:
  if clock>=float(row.next):row.canvas.queue_redraw();row.view.render_target_update_mode=SubViewport.UPDATE_ONCE;row.next=clock+.08
 if clock>=float(get_meta("next_mirror",0.)):
  for row in mirrors:
   if mirror_visible(row):update_mirror(row)
  set_meta("next_mirror",clock+.1)
