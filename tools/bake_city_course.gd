extends SceneTree
const Instances=preload("res://scripts/content/scene_instances.gd")
## Editor-only Road Generator curves become script-free meshes and race data.
var output:="res://assets/tracks/colombo_city"
var course: Node3D
var points:=PackedVector3Array()
var widths: Array=[]
var route: LeoCircuit
func _initialize() -> void:run.call_deferred()
func own(node: Node, parent: Node) -> void:
	parent.add_child(node);node.owner=course
func mesh_node(mesh: Mesh, material: Material, name_text: String) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=name_text;node.mesh=mesh;node.material_override=material;own(node,course);return node
func ribbon(start: int, end: int, side_a: float, side_b: float, height_a: float, height_b: float, material: Material, label: String, collision: bool=false) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(start,end):
		var a:=float(i)*route.step;var b:=float(i+1)*route.step
		var half_a:=route.width_at(a)*.5;var half_b:=route.width_at(b)*.5
		var vertices: Array[Vector3]=[route.sample(a,half_a*side_a)+Vector3.UP*height_a,route.sample(a,half_a*side_b)+Vector3.UP*height_b,route.sample(b,half_b*side_b)+Vector3.UP*height_b,route.sample(b,half_b*side_a)+Vector3.UP*height_a]
		for index in ([0,1,2,0,2,3] if side_a>side_b or (is_equal_approx(side_a,side_b) and side_a<0) else [0,2,1,0,3,2]):surface.set_uv(Vector2(vertices[index].x,vertices[index].z));surface.add_vertex(vertices[index])
	surface.generate_normals();surface.generate_tangents()
	var mesh:=surface.commit();var node:=mesh_node(mesh,material,label)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision:
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=2;own(body,course)
		var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();own(shape,body)
func run() -> void:
	var authored: Node3D=load("res://blender/colombo-road-authoring.tscn").instantiate();root.add_child(authored)
	await process_frame;await process_frame;await process_frame
	var container: Node3D=authored.get_node("Course");container.rebuild_segments(true)
	await process_frame;await process_frame
	var controls: Array=[]
	for child in container.get_children():
		if String(child.name).begins_with("P"):controls.append(child)
	controls.sort_custom(func(a,b):return String(a.name)<String(b.name))
	var segments: Array=[];var lengths: Array[float]=[];var total:=0.
	for point in controls:
		var segment=point.next_seg
		if not segment or not segment.curve:push_error("Road Generator did not create a connected segment");quit(1);return
		segments.append(segment);lengths.append(float(segment.curve.get_baked_length()));total+=lengths[-1]
	var count:=roundi(total/2.);var spacing:=total/count;var index:=0;var beginning:=0.
	for i in count:
		var distance:=float(i)*spacing
		while index<segments.size()-1 and distance>=beginning+lengths[index]:beginning+=lengths[index];index+=1
		var segment=segments[index];var local_distance:=distance-beginning;var fraction:=local_distance/lengths[index]
		points.append(segment.to_global(segment.curve.sample_baked(local_distance,false)))
		widths.append(lerpf(float(controls[index].lane_width)*4.,float(controls[(index+1)%controls.size()].lane_width)*4.,fraction))
	DirAccess.make_dir_recursive_absolute(output)
	var coordinates: Array=[]
	for point in points:coordinates.append([point.x,0,point.z])
	var sectors:=[{"fraction":0.,"name":"GALLE FACE WATERFRONT"},{"fraction":.22,"name":"FORT QUARTER"},{"fraction":.37,"name":"CITY COMMERCE"},{"fraction":.51,"name":"LOTUS / BEIRA"},{"fraction":.69,"name":"LAKE GARDENS"},{"fraction":.85,"name":"COASTAL RETURN"}]
	var data:={"name":"Colombo City Grand Prix","version":1,"length":total,"width":18.,"points":coordinates,"widths":widths,"boosts":[.075,.205,.335,.465,.61,.755,.895],"sectors":sectors,"features":{"lake_center":[300,0,25],"lake_radius":[125,125],"coast_x":-850,"grid":{"start":-8,"lanes":[-3.2,3.2]},"recovery_spacing":10.}}
	FileAccess.open(output+"/route.json",FileAccess.WRITE).store_string(JSON.stringify(data))
	var definition:=LeoTrackDefinition.new();definition.route=data;route=LeoCircuit.new(definition)
	course=Node3D.new();course.name="BakedColomboCourse";root.add_child(course)
	var asphalt:=LeoColomboWorld.pbr_material("res://shaders/city_road.gdshader","Asphalt023S")
	var paving:=LeoColomboWorld.pbr_material("res://shaders/paving_pbr.gdshader","PavingStones001")
	var paint:=LeoRaceVisuals.flat_material(Color("e4e0ca"));paint.roughness=.8
	var barrier:=LeoRaceVisuals.flat_material(Color("c9c7bc"));barrier.roughness=.88
	for start in range(0,count,100):
		var end:=mini(count,start+100)
		ribbon(start,end,-1.,1.,.045,.045,asphalt,"Asphalt_%d"%start,true)
		for side in [-1.,1.]:
			ribbon(start,end,side*1.005,side*1.58,.07,.07,paving,"Sidewalk_%d"%start)
			ribbon(start,end,side*.965,side*.985,.055,.055,paint,"Edge_%d"%start)
			ribbon(start,end,side*1.025,side*1.025,.05,.78,barrier,"ContinuousBarrier_%d"%start,true)
			ribbon(start,end,side*1.025,side*1.07,.78,.78,barrier,"BarrierCap_%d"%start)
		await process_frame
	var dashes:=MultiMesh.new();dashes.transform_format=MultiMesh.TRANSFORM_3D
	var dash_mesh:=BoxMesh.new();dash_mesh.size=Vector3(.16,.012,4.);dash_mesh.material=paint;dashes.mesh=dash_mesh;dashes.instance_count=int(total/12.)
	var dash_transforms: Array[Transform3D]=[]
	for i in dashes.instance_count:
		var s:=float(i)*12.;var t:=route.direction(s);dash_transforms.append(Transform3D(Basis(Vector3.UP,atan2(t.x,t.z)),route.sample(s)+Vector3.UP*.058))
	var dash_node:=MultiMeshInstance3D.new();dash_node.multimesh=dashes;Instances.store(dash_node,dash_transforms);dash_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;own(dash_node,course)
	var checker:=ShaderMaterial.new();checker.shader=load("res://shaders/astra_checkers.gdshader")
	var finish:=SurfaceTool.new();finish.begin(Mesh.PRIMITIVE_TRIANGLES)
	var finish_vertices: Array[Vector3]=[route.sample(-3.,-9.),route.sample(-3.,9.),route.sample(3.,9.),route.sample(3.,-9.)]
	var uvs:=[Vector2(0,0),Vector2(9,0),Vector2(9,3),Vector2(0,3)]
	for i in [0,2,1,0,3,2]:finish.set_uv(uvs[i]);finish.set_normal(Vector3.UP);finish.add_vertex(finish_vertices[i]+Vector3.UP*.064)
	mesh_node(finish.commit(),checker,"StartFinish")
	var gate:=Node3D.new();gate.position=route.sample(6);var direction:=route.direction(6);gate.rotation.y=atan2(-direction.x,-direction.z);own(gate,course)
	var metal:=LeoRaceVisuals.flat_material(Color("20323b"),.25)
	for x in [-10.6,10.6]:
		var post:=LeoRaceVisuals.mesh_box(gate,Vector3(.7,9.,.8),Vector3(x,4.5,0),metal);post.owner=course
	var beam:=LeoRaceVisuals.mesh_box(gate,Vector3(22,1.5,.8),Vector3(0,8.12,0),metal);beam.owner=course
	var packed:=PackedScene.new();packed.pack(course)
	if ResourceSaver.save(packed,output+"/course.scn")!=OK:quit(1);return
	var manifest:={"format":1,"asset_api":1,"id":"colombo_city","name":"Colombo City Grand Prix","course_revision":1,"route":"route.json","world_kind":"city","scene":"res://assets/tracks/colombo_city/course.scn","lighting":"res://assets/config/colombo-city.tres","description":"5.5 km through Galle Face, Fort, commercial streets and Lotus / Beira gardens.","packs":[],"authoring":{"plugin":"Road Generator","version":"0.9.5","road_points":controls.size()},"exclusions":[{"name":"Galle Face Green","polygon":[[-840,-520],[-615,-520],[-615,570],[-840,570]]},{"name":"Lake","polygon":[[170,-110],[430,-110],[430,160],[170,160]]},{"name":"Custom architecture garden","polygon":[[-300,140],[140,140],[140,590],[-300,590]]}],"landmarks":[{"id":"lotus_tower","position":[32,.07,-58]},{"id":"galle_face_green","position":[-730,0,25]},{"id":"custom_architecture","position":[-110,0,330]}]}
	FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	FileAccess.open(output+"/cells.json",FileAccess.WRITE).store_string(JSON.stringify({"cells":[]}))
	print("CITY_COURSE_BAKED | length=",total," | samples=",count," | authored_segments=",segments.size()," | scene_bytes=",FileAccess.get_file_as_bytes(output+"/course.scn").size())
	authored.queue_free();course.queue_free();await process_frame;quit()
