extends SceneTree
## Focused regressions for the material precedence and compiled-cell defects.
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func road_node(shader: Shader) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=BoxMesh.new()
	var material:=ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("color_map",preload("res://assets/materials/Asphalt023S_2K-JPG_Color.jpg"))
	material.set_shader_parameter("normal_map",preload("res://assets/materials/Asphalt023S_2K-JPG_NormalGL.jpg"))
	material.set_shader_parameter("rough_map",preload("res://assets/materials/Asphalt023S_2K-JPG_Roughness.jpg"))
	node.material_override=material;return node
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	world.set_meta("polish_profile",{"road_roughness":.73,"road_albedo_gain":.54})
	var node:=road_node(preload("res://shaders/road_surface.gdshader"));world.add_child(node)
	var original:=node.material_override
	LeoTrackPolish.apply_node(node,world)
	var material:=node.get_active_material(0) as ShaderMaterial
	check(node.material_override==null and material!=original,"Surface override is visible instead of being hidden behind material_override")
	check(material.shader==LeoTrackPolish.ROAD_SHADER,"Legacy asphalt receives shared premium shader")
	check(is_equal_approx(float(material.get_shader_parameter("base_roughness")),.73),"Authored dry roughness reaches the active material")
	check(is_zero_approx(float(material.get_shader_parameter("wetness"))),"Unspecified weather stays dry")
	check(original.shader==preload("res://shaders/road_surface.gdshader"),"Shared source material is not modified")
	LeoTrackPolish.apply_node(node,world)
	check(node.get_active_material(0)==material,"Reapplying polish is idempotent")
	for expression in ["length(VERTEX)>150.","length(VERTEX)<=150."]:
		var shader:=Shader.new();shader.code=preload("res://shaders/road_surface.gdshader").code.replace("void fragment(){","void fragment(){ if("+expression+")discard;")
		var partition:=road_node(shader);partition.set_meta("polish_applied",true);world.add_child(partition)
		LeoTrackPolish.apply_node(partition,world)
		var upgraded:=partition.get_active_material(0) as ShaderMaterial
		check(int(partition.get_meta("polish_revision",0))==279,"Previously compiled lighting cell receives current revision")
		check(upgraded.shader.code.contains("if("+expression+")discard;"),"Near/far lighting partition survives upgrade: "+expression)
	var city:=road_node(preload("res://shaders/city_road.gdshader"));world.add_child(city);LeoTrackPolish.apply_node(city,world)
	check(city.get_active_material(0).shader==LeoTrackPolish.ROAD_SHADER,"City asphalt shares the same dry treatment")
	var multi:=MultiMeshInstance3D.new();var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.mesh=BoxMesh.new();instances.instance_count=1;multi.multimesh=instances;multi.material_override=original;world.add_child(multi)
	LeoTrackPolish.apply_node(multi,world)
	check(multi.material_override==null and multi.multimesh.mesh.surface_get_material(0).shader==LeoTrackPolish.ROAD_SHADER,"Instanced road override is upgraded on its private mesh")
	check(instances.mesh.surface_get_material(0)==null,"Instanced source mesh remains unmodified")
	var circuit:=LeoCircuit.new()
	LeoTrackPolish.install(world,circuit)
	var streamed:=road_node(preload("res://shaders/road_surface.gdshader"));streamed.set_meta("polish_applied",true);world.add_child(streamed)
	check(streamed.get_active_material(0).shader==LeoTrackPolish.ROAD_SHADER,"Streamed road receives polish when its subtree enters the world")
	var floor_body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var floor_shape:=BoxShape3D.new()
	floor_shape.size=Vector3(2400.,1.,2400.);collider.shape=floor_shape;collider.position.y=-.5;floor_body.add_child(collider);world.add_child(floor_body)
	var collision_count:=world.find_children("*","CollisionObject3D",true,false).size()
	var scenery:=world.get_node("SriLankaRoadside279")
	for frame in 180:
		if scenery.ready_for_review:break
		await physics_frame
	check(scenery.ready_for_review,"Scenery preparation reaches a terminal ready state")
	check(scenery.placements.size()>0 and scenery.placements.size()<=18,"Roadside kit count is bounded and populated")
	for placement in scenery.placements:check(float(placement.clearance)>=3.2,"Garden pocket remains outside the race corridor")
	check(world.find_children("*","CollisionObject3D",true,false).size()==collision_count,"Scenery adds no collision objects")
	for batch in scenery.get_children():
		check(batch is MultiMeshInstance3D and batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Scenery uses shadow-free instanced batches")
	var probe_owner:=Node3D.new();world.add_child(probe_owner)
	var authored_probe:=ReflectionProbe.new();probe_owner.add_child(authored_probe)
	LeoGraphics.apply(world,Environment.new(),0,false)
	check(not authored_probe.visible,"Low quality also disables nested authored world probes")
	LeoGraphics.apply(world,Environment.new(),1,false)
	check(authored_probe.visible,"Medium restores authored local reflections")
	var transition:=LeoRaceEnvironment.new();transition.world=world
	transition.collect(authored_probe)
	check(not authored_probe.visible and transition.probes.has(authored_probe),"Night guard includes unnamed authored daylight captures")
	transition.probes.clear()
	var visual_ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(8.,8.)
	visual_ground.mesh=plane;visual_ground.position=Vector3(1500.,4.,1500.);visual_ground.set_meta("surface_role","terrain_verge");world.add_child(visual_ground)
	scenery.collect_support_meshes()
	var visual_hit: Dictionary=scenery.visual_support(Vector3(1500.,4.,1500.))
	check(not visual_hit.is_empty() and is_equal_approx(float(visual_hit.position.y),4.),"Collision-free elevated scenery reads actual visual support triangles")
	scenery.support_meshes.clear()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"pockets":scenery.placements.size(),"batches":scenery.get_child_count()}
	var output:="res://build/qa279/render-unit"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("render-polish279.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RENDER_POLISH279 ",JSON.stringify(report))
	root.remove_child(world);world.queue_free()
	for frame in 4:await process_frame
	quit(0 if errors.is_empty() else 1)
