extends Node3D
## Small, deterministic garden pockets complement the authored streetscape.
## This layer owns no collision, lights, reflection captures or moving scenery.
const ATLAS := "res://assets/art/scenery279/sri_lanka_surfaces.png"
const PLANTS := ["bush_common_flowers","fern_1","plant_7"]
const MAX_POCKETS := 18
var circuit: LeoCircuit
var placements: Array[Dictionary]=[]
var batches: Dictionary={}
var parts: Dictionary={}
var quality_clock := 0.0
var ready_for_review := false
var planter_material: StandardMaterial3D
var support_meshes: Array[Dictionary]=[]
var kit_materials: Dictionary={}

func configure(track: LeoCircuit) -> void:
	name="SriLankaRoadside279";circuit=track

func _ready() -> void:
	build.call_deferred()

func build() -> void:
	if not circuit or not is_inside_tree():return
	var id:=String(circuit.definition.id) if circuit.definition else "astra_coast"
	# External/custom courses retain their own authored scenery policy.
	if id not in ["astra_coast","colombo_city","kandy_lake"]:ready_for_review=true;return
	await get_tree().physics_frame
	if not is_inside_tree():return
	collect_support_meshes()
	var rng:=RandomNumberGenerator.new();rng.seed=279+absi(id.hash())
	var count:=mini(MAX_POCKETS,maxi(8,int(circuit.length/125.)))
	planter_material=atlas_material(0,Color(.72,.72,.68))
	for index in count:
		var station:=circuit.length*(float(index)+.45)/float(count)
		# The start/finish and landmark approach retain an open visual corridor.
		if station<55. or station>circuit.length-45.:continue
		var side:=-1. if index%2 else 1.
		var location:=find_pocket(station,side)
		if location.is_empty():continue
		var point: Vector3=location.position
		var frame:=circuit.frame_at(station)
		# Keep furniture upright on near-level support; plants get a seeded yaw.
		var basis:=Basis(Vector3.UP,frame.get_euler().y+PI*.5)
		placements.append({"station":station,"position":point,"clearance":float(location.clearance),"kind":index%3,"support":location.support})
		var group:=int(station/240.)
		var kit:=index%3
		var bed:=BoxMesh.new();bed.size=Vector3(2.7,.34,1.15)
		bed.material=atlas_material([0,3,1][kit],Color(.72,.72,.68))
		append_mesh("planter-"+str(kit),bed,Transform3D(basis,point+Vector3.UP*.17),group,false)
		var soil:=BoxMesh.new();soil.size=Vector3(2.48,.028,.93);soil.material=atlas_material(1,Color(.27,.24,.20))
		append_mesh("soil",soil,Transform3D(basis,point+Vector3.UP*.35),group,false)
		for plant_index in 3:
			var shift:=Vector3((float(plant_index)-1.)*.82,.31,(rng.randf()-.5)*.25)
			var plant_pose:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.40,.56)),point+basis*shift)
			append_model(PLANTS[(index+plant_index)%PLANTS.size()],plant_pose,group)
		# A compact stone edge grounds each pocket without a repeated billboard.
		var stone_pose:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*.23),point+basis*Vector3(1.65,.05,.2))
		append_model("rock_medium_1",stone_pose,group)
		if kit==1:
			var edge:=BoxMesh.new();edge.size=Vector3(.14,.43,1.28);edge.material=atlas_material(3,Color(.70,.72,.69))
			for x in [-1.38,1.38]:append_mesh("stone-edge",edge,Transform3D(basis,point+basis*Vector3(x,.215,0)),group,false)
		# Two small shade/flower stands use the woven-cloth tile. Their footprint
		# stays inside the same checked pocket, and Low omits the upper detail.
		if placements.size() in [3,11]:awning(point,basis,group)
		if index%4==1:
			var timber:=BoxMesh.new();timber.size=Vector3(1.65,.10,.40);timber.material=material(Color("634a33"))
			append_mesh("bench",timber,Transform3D(basis,point+basis*Vector3(0,.48,-1.22)),group,false)
			var leg:=BoxMesh.new();leg.size=Vector3(.10,.43,.32);leg.material=material(Color("333e3a"))
			for x in [-.58,.58]:append_mesh("bench-leg",leg,Transform3D(basis,point+basis*Vector3(x,.22,-1.22)),group,false)
	flush()
	support_meshes.clear()
	ready_for_review=true;apply_quality()
	set_meta("pocket_count",placements.size())
	set_meta("decorative_only",true)
	print("SRI_ROADSIDE279 | pockets=%d | batches=%d"%[placements.size(),get_child_count()])

func find_pocket(station: float, side: float) -> Dictionary:
	var space:=get_world_3d().direct_space_state
	var half_width:=circuit.width_at(station)*.5
	for offset in [4.2,5.8]:
		var point:=circuit.sample(station,side*(half_width+float(offset)))
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*8.,point-Vector3.UP*8.,1)
		var hit:=space.intersect_ray(ray)
		var visual:=hit.is_empty()
		if hit.is_empty():hit=visual_support(point)
		if hit.is_empty() or (hit.normal as Vector3).y<.96:continue
		var support: Vector3=hit.position
		if absf(support.y-point.y)>2.5:continue
		point.y=support.y+.06
		# Reject buildings, barriers and occupied bays before adding any decoration.
		var shape:=BoxShape3D.new();shape.size=Vector3(3.8,2.0,3.4)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*1.15)
		if not space.intersect_shape(query,1).is_empty():continue
		var projection:=circuit.project(point)
		var clearance:=absf(float(projection.offset))-circuit.width_at(float(projection.distance))*.5
		if clearance<3.2:continue
		var profile: LeoArtProfile=circuit.definition.profile() if circuit.definition else null
		if profile and not profile.parking_clear(point,circuit,2.2):continue
		return {"position":point,"clearance":clearance,"support":"visual" if visual else "physics"}
	return {}

func collect_support_meshes() -> void:
	for node in get_parent().find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		var role:=String(node.get_meta("surface_role",""))
		if role in ["landmark_ground","distant_mountains"]:continue
		var ground:=role in ["terrain_verge","terrain_detail","terrain_backdrop"] or "terrain" in String(node.name).to_lower()
		for index in node.mesh.get_surface_count():
			var surface: Material=node.get_active_material(index)
			if surface is ShaderMaterial and surface.shader:
				var code: String=surface.shader.code
				ground=ground or code.contains("ground_normal") or code.contains("uv=world.xz*.45")
		if ground:support_meshes.append({"node":node,"bounds":node.global_transform*node.mesh.get_aabb()})

func visual_support(point: Vector3) -> Dictionary:
	# Elevated courses deliberately omit collision outside the permanent road.
	# Read their authored paving/terrain triangles instead of inventing a floor.
	var result: Dictionary={}
	for entry in support_meshes:
		var box: AABB=entry.bounds
		if point.x<box.position.x or point.x>box.end.x or point.z<box.position.z or point.z>box.end.z:continue
		if not entry.has("faces"):
			var node: MeshInstance3D=entry.node
			var faces: PackedVector3Array=node.mesh.get_faces()
			for index in faces.size():faces[index]=node.global_transform*faces[index]
			entry.faces=faces
		var faces: PackedVector3Array=entry.faces
		for index in range(0,faces.size()-2,3):
			var a:=faces[index];var b:=faces[index+1];var c:=faces[index+2]
			if point.x<minf(a.x,minf(b.x,c.x)) or point.x>maxf(a.x,maxf(b.x,c.x)) or point.z<minf(a.z,minf(b.z,c.z)) or point.z>maxf(a.z,maxf(b.z,c.z)):continue
			var normal: Vector3=(b-a).cross(c-a).normalized()
			if absf(normal.y)<.96:continue
			var hit: Variant=Geometry3D.segment_intersects_triangle(point+Vector3.UP*8.,point-Vector3.UP*8.,a,b,c)
			if hit is Vector3 and absf(hit.y-point.y)<=2.5 and (result.is_empty() or hit.y>result.position.y):result={"position":hit,"normal":-normal if normal.y<0. else normal}
	return result

func material(color: Color) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_color=color;result.roughness=.86;result.metallic_specular=.12
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return result

func atlas_material(tile: int, tint: Color) -> StandardMaterial3D:
	var key:=str(tile)+str(tint)
	if kit_materials.has(key):return kit_materials[key]
	var result:=material(tint)
	if ResourceLoader.exists(ATLAS):
		result.albedo_texture=load(ATLAS);result.uv1_scale=Vector3(.48,.48,1.)
		result.uv1_offset=Vector3(.01+float(tile%2)*.5,.01+float(tile>>1)*.5,0.)
	kit_materials[key]=result;return result

func awning(point: Vector3, basis: Basis, group: int) -> void:
	var roof:=PlaneMesh.new();roof.size=Vector2(2.8,1.8)
	var cloth:=atlas_material(2,Color(.82,.86,.81));cloth.cull_mode=BaseMaterial3D.CULL_DISABLED;roof.material=cloth
	append_mesh("cloth-awning",roof,Transform3D(basis*Basis(Vector3.RIGHT,-.10),point+Vector3.UP*2.08),group,true)
	var post:=BoxMesh.new();post.size=Vector3(.075,2.05,.075);post.material=material(Color("5d4b35"))
	for x in [-1.18,1.18]:
		for z in [-.70,.70]:append_mesh("shade-post",post,Transform3D(basis,point+basis*Vector3(x,1.025,z)),group,true)

func model_parts(key: String) -> Array:
	if parts.has(key):return parts[key]
	var path:="res://assets/models/colombo/"+key+".glb"
	var result: Array=[]
	if ResourceLoader.exists(path):
		var model:=load(path).instantiate() as Node3D
		collect_parts(model,Transform3D.IDENTITY,result);model.free()
		var bounds:=AABB();var first:=true
		for part in result:
			var box: AABB=part.pose*part.mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		var base:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		for part in result:
			var pose: Transform3D=part.pose;pose.origin-=base;part.pose=pose
	parts[key]=result;return result

func collect_parts(node: Node3D, parent_pose: Transform3D, result: Array) -> void:
	var pose:=parent_pose*node.transform
	if node is MeshInstance3D and node.mesh:result.append({"mesh":node.mesh,"pose":pose})
	for child in node.get_children():
		if child is Node3D:collect_parts(child,pose,result)

func append_model(key: String, pose: Transform3D, group: int) -> void:
	var entries:=model_parts(key)
	for index in entries.size():append_mesh(key+str(index),entries[index].mesh,pose*entries[index].pose,group,true)

func append_mesh(key: String, mesh: Mesh, pose: Transform3D, group: int, detail: bool) -> void:
	var batch_key:=str(group)+"-"+key
	if not batches.has(batch_key):batches[batch_key]={"mesh":mesh,"poses":[],"detail":detail}
	batches[batch_key].poses.append(pose)

func flush() -> void:
	for key in batches:
		var entry: Dictionary=batches[key]
		var mesh:=MultiMesh.new();mesh.transform_format=MultiMesh.TRANSFORM_3D;mesh.mesh=entry.mesh;mesh.instance_count=entry.poses.size()
		var batch:=MultiMeshInstance3D.new();batch.name="Garden-"+key;batch.multimesh=mesh
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.set_meta("roadside_detail279",entry.detail)
		var center:=Vector3.ZERO
		for pose in entry.poses:center+=pose.origin
		center/=float(entry.poses.size());batch.position=center
		var radius:=0.
		var poses: Array[Transform3D]=[]
		for pose in entry.poses:
			var local_pose: Transform3D=pose;local_pose.origin-=center;poses.append(local_pose)
			radius=maxf(radius,local_pose.origin.length())
		batch.set_meta("cluster_radius279",radius)
		LeoSceneInstances.store(batch,poses);add_child(batch)
	# Meshes remain owned by the MultiMeshes; CPU composition data can retire.
	batches.clear();parts.clear()

func apply_quality() -> void:
	var game:=get_parent().get_parent()
	if not game or not "graphics_quality" in game:return
	var split:=int(game.get("human_count"))==2
	var tier:=mini(int(game.get("graphics_quality")),1) if split else int(game.get("graphics_quality"))
	for batch in get_children():
		if not batch is GeometryInstance3D:continue
		var detail:=bool(batch.get_meta("roadside_detail279",false))
		batch.visible=not detail or tier>0
		batch.visibility_range_end=float(batch.get_meta("cluster_radius279",0.))+([60.,90.,135.][clampi(tier,0,2)] if detail else [80.,120.,175.][clampi(tier,0,2)])
		batch.visibility_range_end_margin=20.
		if RenderingServer.get_current_rendering_method()=="forward_plus":batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _process(dt: float) -> void:
	quality_clock+=dt
	if quality_clock>=.5:quality_clock=0.;apply_quality()
