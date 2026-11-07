class_name LeoCockpitSystems
extends Node3D
## Optional reviewed cockpit presentation. No physics or source material changes.
const MIRROR_BITS=[1<<18,1<<19]
const MIRROR_HZ := 30.0
const MIRROR_INTERVAL := 1.0 / MIRROR_HZ
const Profile = preload("res://scripts/catalog/cockpit_profile279.gd")
var kart: LeoKart
var mirrors: Array[Dictionary]=[]
var screens: Array[Dictionary]=[]
var clock:=0.
var cursor:=0
var warmed:=false
var last_quality:=-1
var needles: Array[Dictionary] = []
var profile: Dictionary = {}
static func install(owner_kart: LeoKart) -> void:
 if not owner_kart.is_player or not owner_kart.definition.official or Profile.for_vehicle(String(owner_kart.definition.id)).is_empty():return
 var systems:=LeoCockpitSystems.new();systems.name="LiveCockpit";owner_kart.visual.add_child(systems);systems.setup(owner_kart)
func surface(view: SubViewport,at: Vector3,extent: Vector2,normal: Vector3,mirror: bool,parent: Node3D=null) -> MeshInstance3D:
 var plane:=MeshInstance3D.new();var mesh:=QuadMesh.new();mesh.size=extent;plane.mesh=mesh
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=view.get_texture();material.cull_mode=BaseMaterial3D.CULL_DISABLED
 if mirror:material.uv1_scale=Vector3(-1,1,1);material.uv1_offset=Vector3(1,0,0)
 plane.material_override=material;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 plane.layers=MIRROR_BITS[kart.local_slot] if mirror else LeoCameraViews.BODY_BITS[kart.local_slot]
 add_child(plane);plane.transform=kart.chassis.transform*Transform3D(Basis.looking_at(-normal.normalized(),Vector3.UP),at)
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
  # Imported surfaces may contain custom packed attributes whose format flags
  # belong to the source mesh. The unshaded overlay needs only this geometry
  # and its freshly authored UVs; do not copy opaque custom-array channels.
  var overlay_arrays: Array=[];overlay_arrays.resize(Mesh.ARRAY_MAX)
  overlay_arrays[Mesh.ARRAY_VERTEX]=vertices;overlay_arrays[Mesh.ARRAY_TEX_UV]=uv
  overlay_arrays[Mesh.ARRAY_INDEX]=arrays[Mesh.ARRAY_INDEX]
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,overlay_arrays)
  var overlay:=MeshInstance3D.new();overlay.mesh=mesh;overlay.layers=MIRROR_BITS[kart.local_slot] if flip else LeoCameraViews.BODY_BITS[kart.local_slot];overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=view.get_texture();material.cull_mode=BaseMaterial3D.CULL_DISABLED
  if flip:material.uv1_scale=Vector3(-1,1,1);material.uv1_offset=Vector3(1,0,0)
  overlay.material_override=material;source.add_child(overlay);overlay.set_meta("reviewed_surface",String(original.resource_name));return overlay
 return null
func setup(owner_kart: LeoKart) -> void:
 kart=owner_kart
 profile=Profile.for_vehicle(String(kart.definition.id))
 var data: Dictionary=profile.get("cluster",{})
 var cluster:=display(false,Vector2i(512,200),String(data.get("kind","digital")))
 surface(cluster,Profile.vector(data,"position"),Vector2(float(data.size[0]),float(data.size[1])),Profile.vector(data,"normal",Vector3.BACK),false)
 data=profile.get("navigation",{})
 var navigation:=display(true,Vector2i(640,360))
 if data.get("fitted",false):
  var at: Vector3=Profile.vector(data,"position")
  var extent:=Vector2(float(data.size[0]),float(data.size[1]));var normal: Vector3=Profile.vector(data,"normal",Vector3.BACK)
  var panel:=surface(navigation,at,extent,normal,false);panel.name="FittedNavigationDisplay"
  var bezel:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(extent.x+.017,extent.y+.017,.022);bezel.mesh=mesh
  var material:=StandardMaterial3D.new();material.albedo_color=Color("15181b");material.roughness=.48;material.metallic=.12;bezel.material_override=material
  bezel.layers=LeoCameraViews.BODY_BITS[kart.local_slot];bezel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  kart.chassis.add_child(bezel);bezel.name="FittedNavigationBezel";bezel.position=at-normal.normalized()*.013;bezel.basis=Basis.looking_at(-normal.normalized(),Vector3.UP)
 else:surface_overlay(navigation,Profile.node(kart.chassis,String(data.get("node",""))) as MeshInstance3D,String(data.get("material","gps_screen")))
 for binding in profile.get("analog",[]):
  var needle:=Profile.node(kart.chassis,String(binding.node))
  if needle:needles.append({"node":needle,"base":needle.transform,"binding":binding})
 if profile.get("mirrors","")=="duster2014":
  mirror("Rear",Vector3(0,1.29,-.40),Vector2(.205,.067),Vector3(-.15,-.05,1),Vector3(0,1.23,1.25),Vector3(0,-.08,1),Profile.node(kart.chassis,"Duster_My_2014_ceiling"))
  for side in [-1.,1.]:
   mirror("Left" if side<0 else "Right",Vector3(side*.88,1.0,-.67),Vector2(.14,.08),Vector3(-side*.4,0,1),Vector3(side*.94,1.0,-.69),Vector3(side*.24,-.08,1),Profile.node(kart.chassis,"Duster_My_2014_mirror_L" if side<0 else "Duster_My_2014_mirror_R"))
  return
 mirror("Rear",Vector3(0,1.435,-.41),Vector2(.265,.09),Vector3(-.25,-.08,1),Vector3(0,1.32,1.25),Vector3(0,-.08,1),kart.chassis.find_child("dust25_intermirror",true,false) as MeshInstance3D)
 for side in [-1.,1.]:
  var parent:=kart.chassis.find_child("dust25_mirror_L" if side<0 else "dust25_mirror_R",true,false) as Node3D
  mirror("Left" if side<0 else "Right",Vector3(side*.947,1.205,-.465),Vector2(.16,.09),Vector3(-side*.45,0,1),Vector3(side*1.04,1.22,-.48),Vector3(side*.24,-.08,1),parent)
func display(navigation: bool,extent: Vector2i,kind: String="digital") -> SubViewport:
 var view:=SubViewport.new();view.disable_3d=true;view.size=extent;view.render_target_update_mode=SubViewport.UPDATE_DISABLED;view.gui_disable_input=true;add_child(view)
 var canvas:=LeoCockpitCanvas.new();canvas.kart=kart;canvas.navigation=navigation;canvas.kind=kind;canvas.size=Vector2(extent);view.add_child(canvas);screens.append({"view":view,"canvas":canvas,"next":0.})
 return view
func mirror(title: String,at: Vector3,extent: Vector2,normal: Vector3,eye: Vector3,direction: Vector3,parent: Node3D) -> void:
 var view:=SubViewport.new();view.name=title+"MirrorView";view.size=Vector2i(128,64);view.world_3d=kart.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 view.positional_shadow_atlas_size=0;view.msaa_3d=Viewport.MSAA_DISABLED;view.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED;view.gui_disable_input=true;add_child(view)
 var camera:=Camera3D.new();camera.fov=62.;camera.near=.06;camera.far=80.;camera.current=true;view.mesh_lod_threshold=5.
 camera.cull_mask=((1<<20)-1)&~(MIRROR_BITS[0]|MIRROR_BITS[1]|(1<<16)|LeoCameraViews.BODY_BITS[kart.local_slot]|LeoCameraViews.DRIVER_BITS[kart.local_slot])
 var source: Environment=kart.get_parent().get("environment")
 if source:
  camera.environment=source.duplicate();camera.environment.glow_enabled=false;camera.environment.ssao_enabled=false;camera.environment.ssil_enabled=false;camera.environment.ssr_enabled=false;camera.environment.volumetric_fog_enabled=false
 view.add_child(camera)
 var plane:=surface_overlay(view,parent as MeshInstance3D,"mirror",true)
 if not plane:plane=surface(view,at,extent,normal,true,parent)
 plane.name=title+"LiveMirror"
 mirrors.append({"view":view,"camera":camera,"eye":eye,"direction":direction,"surface":plane,"renders":0,"next_due":0.,"was_visible":false})
func active() -> bool:
 var locals: Array=kart.get_parent().local_players
 return kart.local_slot<locals.size() and not locals[kart.local_slot].photo and locals[kart.local_slot].kart==kart and LeoCameraViews.effective(locals[kart.local_slot])=="cockpit"
func apply_quality() -> void:
 var split: bool=int(kart.get_parent().human_count)==2
 var quality:=1 if split else 0
 if quality==last_quality:return
 last_quality=quality
 for row in mirrors:
  row.view.size=Vector2i(64,32) if split else Vector2i(128,64)
  row.camera.far=60. if split else 80.
  row.view.mesh_lod_threshold=6. if split else 5.
func mirror_visible(row: Dictionary) -> bool:
 var local: LeoLocalPlayer=kart.get_parent().local_players[kart.local_slot]
 if row.surface.name!="RearLiveMirror":
  var yaw: float=local.camera_rig.head_offset.x
  if absf(yaw)<deg_to_rad(12.):return false
  if (row.surface.name=="LeftLiveMirror")!=(yaw>0.):return false
 var camera: Camera3D=local.camera
 if not is_instance_valid(camera):return false
 var bounds: AABB=row.surface.global_transform*row.surface.get_aabb()
 var center:=bounds.get_center();var half:=bounds.size*.5
 # Derive each plane's inside sign from a point on the camera's center ray.
 # This includes partially visible mirror glass without assuming plane winding.
 var inside:=camera.global_position-camera.global_basis.z*clampf(1.,camera.near*2.,camera.far*.5)
 for plane: Plane in camera.get_frustum():
  var direction:=1. if plane.distance_to(inside)>=0. else -1.
  if plane.distance_to(center)*direction < -plane.normal.abs().dot(half):return false
 return true
func update_mirror(row: Dictionary) -> void:
 apply_quality()
 var pose:=kart.chassis.get_global_transform_interpolated();var camera: Camera3D=row.camera
 var source: Environment=kart.get_parent().get("environment")
 if source and camera.environment:
  for field in ["ambient_light_color","ambient_light_energy","fog_light_color","fog_density"]:camera.environment.set(field,source.get(field))
 camera.global_position=pose*row.eye;camera.look_at(camera.global_position+pose.basis*row.direction,pose.basis.y)
 row.view.render_target_update_mode=SubViewport.UPDATE_ONCE;row.renders+=1
func warm() -> void:
 for row in mirrors:
  if active() and mirror_visible(row):update_mirror(row)
 for row in screens:row.canvas.queue_redraw();row.view.render_target_update_mode=SubViewport.UPDATE_ONCE
 warmed=true
func _process(dt: float) -> void:
 if not is_instance_valid(kart):return
 clock+=dt
 var mirror_now:=Time.get_ticks_usec()/1000000.0
 var enabled:=active()
 apply_quality()
 for row in mirrors:
  var visible_now: bool=enabled and mirror_visible(row)
  row.surface.visible=visible_now
  if not visible_now:
   row.was_visible=false;row.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
   continue
  if not row.was_visible:
   update_mirror(row)
   var role:=0 if row.surface.name=="RearLiveMirror" else 1
   var phase:=float((kart.local_slot+role)%2)*MIRROR_INTERVAL*.5
   row.next_due=(floorf((mirror_now-phase+0.000001)/MIRROR_INTERVAL)+1.)*MIRROR_INTERVAL+phase
  elif mirror_now+0.000001>=float(row.next_due):
   update_mirror(row)
   # Keep the fractional remainder. A slow frame skips old deadlines rather
   # than issuing several redundant viewport requests or drifting below 30 Hz.
   var skipped:=floorf(maxf(0.,mirror_now-float(row.next_due))/MIRROR_INTERVAL)+1.
   row.next_due=float(row.next_due)+skipped*MIRROR_INTERVAL
  row.was_visible=true
 if not enabled:return
 update_needles()
 for row in screens:
  if clock>=float(row.next):row.canvas.queue_redraw();row.view.render_target_update_mode=SubViewport.UPDATE_ONCE;row.next=clock+.08
func update_needles() -> void:
 for row in needles:
  var data: Dictionary=row.binding
  var value: float=absf(kart.wheel_motion_speed)*3.6 if data.value=="speed" else kart.motor_audio.rpm if kart.motor_audio else 0.
  var degrees:=float(data.get("zero_degrees",135.))+float(data.get("sweep_degrees",-270.))*clampf(value/float(data.maximum),0.,1.)
  row.node.transform=row.base*Transform3D(Basis(Vector3.UP,deg_to_rad(degrees)),Vector3.ZERO)
