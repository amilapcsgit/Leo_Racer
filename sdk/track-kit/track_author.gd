@tool
extends Node3D
## Editor helpers stay here. Only script-free baked content is distributed.
@export var track_id := "community_example"
@export var display_name := "Community Example Circuit"
@export var content_version := "1.0.0"
@export_range(1,1000) var course_revision := 1
@export_range(12.,40.) var road_width := 18.
@export var attribution := "Example geometry: Leo Racer contributors. Replace with your author/license details."
@export var sun_angles := Vector3(-55,-145,0)
@export var sun_color := Color("fff0d8")
@export_range(.1,8.) var sun_energy := 1.4
@export_range(.1,2.) var ambient_energy := .6
@export var sky_top := Color("3a8ec7")
@export var sky_horizon := Color("c9e4ed")
@export_dir var export_folder := "res://exported"
@export_tool_button("Refresh grid, checkpoints and recovery helpers") var helpers_action: Callable=helpers
@export_tool_button("Validate and export track folder") var export_action: Callable=export_from_editor
var last_error := ""
var points: PackedVector3Array
var length := 0.

func _ready() -> void:
	if not $Route.curve or $Route.curve.point_count<4:
		$Route.curve=Curve3D.new();$Route.curve.closed=true
		for i in 8:
			var angle:=TAU*float(i)/8.;var tangent:=Vector3(-sin(angle),0,cos(angle))*31.826
			$Route.curve.add_point(Vector3(cos(angle)*120.,0,sin(angle)*120.),-tangent,tangent)
	helpers()

func sample(distance: float,lane: float=0.) -> Vector3:
	var curve: Curve3D=$Route.curve;var s:=fposmod(distance,length)
	var point: Vector3=curve.sample_baked(s,true);point.y=0
	var direction: Vector3=(curve.sample_baked(fposmod(s+1.,length),true)-curve.sample_baked(fposmod(s-1.,length),true)).normalized()
	return point+Vector3(-direction.z,0,direction.x)*lane

func bake_route() -> bool:
	last_error="";var curve: Curve3D=$Route.curve
	if not $Route.transform.is_equal_approx(Transform3D.IDENTITY):last_error="Keep Route's node transform at identity; edit its curve points instead";return false
	if not curve or not curve.closed or curve.point_count<4:last_error="Use a closed Path3D with at least four control points";return false
	for i in curve.point_count:
		if absf(curve.get_point_position(i).y)>.05 or absf(curve.get_point_in(i).y)>.05 or absf(curve.get_point_out(i).y)>.05:last_error="Track API 2 initially supports flat race routes at Y=0";return false
	length=curve.get_baked_length()
	if length<150:last_error="Circuit must be at least 150 m";return false
	points=PackedVector3Array();var count:=maxi(32,int(ceil(length/4.)))
	for i in count:points.append(sample(float(i)*length/count))
	# The runtime uses equal-distance samples; reject near self-crossings and
	# sharp cusps that would make guidance or recovery ambiguous.
	for i in points.size():
		var tangent: Vector3=(points[(i+1)%points.size()]-points[i]).normalized()
		var next: Vector3=(points[(i+2)%points.size()]-points[(i+1)%points.size()]).normalized()
		if tangent.dot(next)<.8:last_error="Soften a sharp route corner";return false
		for j in range(i+1,points.size()):
			var gap:=mini(abs(i-j),points.size()-abs(i-j))
			if gap>int(ceil(road_width/4.))+2 and points[i].distance_to(points[j])<road_width+2.:last_error="Race corridors overlap; separate this section";return false
	return true

func marker(parent: Node,words: String,position_at: Vector3) -> void:
	var node:=Marker3D.new();node.name=words;node.position=position_at;node.gizmo_extents=3.;parent.add_child(node);node.owner=self
func helpers() -> void:
	if not is_inside_tree() or not bake_route():return
	for key in ["Checkpoints","Grid","Recoveries"]:
		var old:=get_node_or_null(key)
		if old:old.free()
		var node:=Node3D.new();node.name=key;add_child(node);node.owner=self
	for i in 8:
		marker($Checkpoints,"Gate%02d"%i,sample(length*i/8.))
		marker($Recoveries,"Recovery%02d"%i,sample(length*i/8.+2.))
	for i in 6:marker($Grid,"Racer%d"%(i+1),sample(-8.-floori(i/2.)*8.,-3.2 if i%2==0 else 3.2))
	var old_preview:=get_node_or_null("RoadPreview")
	if old_preview:old_preview.free()
	var preview:=Node3D.new();preview.name="RoadPreview";add_child(preview);road_mesh(preview)

func export_from_editor() -> void:
	var result:=export_track(ProjectSettings.globalize_path(export_folder))
	if result:print("TRACK_EXPORTED ",track_id)
	else:push_error(last_error)

func reject_scripts(node: Node,decorative: bool=false) -> bool:
	if node.get_script()!=null:last_error="Remove gameplay scripts from exported scenery: "+String(node.name);return false
	if decorative and node is CollisionObject3D:last_error="Move decorative collision into resident Scenery: "+String(node.name);return false
	for child in node.get_children():
		if not reject_scripts(child,decorative):return false
	return true

func own(node: Node,root: Node) -> void:
	for child in node.get_children():child.owner=root;own(child,root)
func packed(node: Node,path: String) -> bool:
	own(node,node);var scene:=PackedScene.new()
	return scene.pack(node)==OK and ResourceSaver.save(scene,path,ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK

func barrier(root: Node3D,a: Vector3,b: Vector3) -> void:
	var body:=StaticBody3D.new();body.position=(a+b)*.5+Vector3.UP*.45;body.rotation.y=atan2((b-a).x,(b-a).z)
	var box:=BoxMesh.new();box.size=Vector3(.4,.9,a.distance_to(b)+.25)
	var visual:=MeshInstance3D.new();visual.mesh=box;var material:=StandardMaterial3D.new();material.albedo_color=Color("b3c9ce");visual.material_override=material;body.add_child(visual)
	var shape:=CollisionShape3D.new();var collision:=BoxShape3D.new();collision.size=box.size;shape.shape=collision;body.add_child(shape);root.add_child(body)

func road_mesh(root: Node3D) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var s:=float(i)*length/points.size();var next:=float(i+1)*length/points.size()
		var a:=sample(s,-road_width*.5);var b:=sample(s,road_width*.5);var c:=sample(next,-road_width*.5);var d:=sample(next,road_width*.5)
		for vertex in [a,c,b,b,c,d]:surface.set_normal(Vector3.UP);surface.add_vertex(vertex+Vector3.UP*.02)
		for side in [-1.,1.]:barrier(root,sample(s,side*(road_width*.5+.3)),sample(next,side*(road_width*.5+.3)))
	var mesh:=surface.commit();var material:=StandardMaterial3D.new();material.albedo_color=Color("30393c");material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=material;root.add_child(instance)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);root.add_child(body)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();var box:=AABB(points[0],Vector3.ZERO)
	for point in points:box=box.expand(point)
	plane.size=Vector2(box.size.x+250.,box.size.z+250.);ground.mesh=plane;ground.position=box.get_center()-Vector3.UP*.04
	var green:=StandardMaterial3D.new();green.albedo_color=Color("58754e");ground.material_override=green;root.add_child(ground)

func export_track(destination: String) -> bool:
	var pattern:=RegEx.new();pattern.compile("^[a-z0-9][a-z0-9_.-]{0,63}$")
	if not pattern.search(track_id):last_error="Use a lowercase stable track ID";return false
	if not bake_route() or not reject_scripts($Scenery) or not reject_scripts($Details,true):return false
	for group in [$Scenery,$Details]:
		for mesh in group.find_children("*","MeshInstance3D",true,false):
			var box: AABB=global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
			if box.position.y>3.5 or box.end.y<.15:continue
			for point in points:
				var closest:=Vector2(clampf(point.x,box.position.x,box.end.x),clampf(point.z,box.position.z,box.end.z))
				if Vector2(point.x,point.z).distance_to(closest)<road_width*.5+1.:last_error="Scenery intrudes into the protected race corridor: "+String(mesh.name);return false
	var folder:=destination.path_join(track_id)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:last_error="Export directory is not writable";return false
	var resident:=Node3D.new();resident.name="ResidentCourse";road_mesh(resident)
	for child in $Scenery.get_children():resident.add_child(child.duplicate())
	var file:=folder.path_join("resident.scn")
	if not packed(resident,file):resident.free();last_error="Could not bake resident scene";return false
	resident.free()
	var namespace_path:="res://mods/tracks/"+track_id+"/";var files: Dictionary={namespace_path+"resident.scn":file}
	var groups: Dictionary={}
	for child in $Details.get_children():
		var key:=Vector2i(floori(child.position.x/200.),floori(child.position.z/200.))
		if not groups.has(key):groups[key]=[]
		groups[key].append(child)
	var cells: Array=[]
	for key in groups:
		var root:=Node3D.new();var id:="cell_%d_%d"%[key.x,key.y]
		for child in groups[key]:root.add_child(child.duplicate())
		var path:=folder.path_join(id+".scn")
		if not packed(root,path):root.free();last_error="Could not bake detail cell";return false
		root.free();files[namespace_path+id+".scn"]=path
		cells.append({"id":id,"center":[key.x*200.+100.,key.y*200.+100.],"scene":namespace_path+id+".scn"})
	var pack:=PCKPacker.new();var package:=folder.path_join("scenery.pck")
	if pack.pck_start(package)!=OK:last_error="Could not create scenery pack";return false
	for virtual_path in files:
		if pack.add_file(virtual_path,files[virtual_path])!=OK:last_error="Could not add baked resource";return false
	if pack.flush()!=OK:last_error="Could not finish scenery pack";return false
	for raw in files.values():DirAccess.remove_absolute(raw)
	var measured:=0.;var route_points: Array=[]
	for i in points.size():measured+=points[i].distance_to(points[(i+1)%points.size()]);route_points.append([points[i].x,0,points[i].z])
	var recoveries: Array=[]
	for i in 8:recoveries.append({"distance":measured*float(i)/8.+2.})
	var route:={"length":measured,"points":route_points,"width":road_width,"features":{"grid":{"start":-8.,"lanes":[-3.2,3.2]},"recoveries":recoveries}}
	var manifest:={"format":1,"asset_api":2,"id":track_id,"name":display_name,"version":content_version,"core":{"min":"2.2.0","max_major":2},"course_revision":course_revision,"world_kind":"external","route":"route.json","scene":namespace_path+"resident.scn","dependencies":[],"packs":[{"file":"scenery.pck","sha256":FileAccess.get_sha256(package)}]}
	manifest.lighting={"sun_angles":[sun_angles.x,sun_angles.y,sun_angles.z],"sun_color":"#"+sun_color.to_html(),"sun_energy":sun_energy,"ambient_energy":ambient_energy,"sky_top":"#"+sky_top.to_html(),"sky_horizon":"#"+sky_horizon.to_html()}
	var box:=AABB(points[0],Vector3.ZERO)
	for point in points:box=box.expand(point)
	var outline: Array[String]=[];var extent:=maxf(box.size.x,box.size.z)
	for point in points:outline.append("%.2f,%.2f"%[12.+(point.x-box.position.x)*232./extent,12.+(point.z-box.position.z)*232./extent])
	FileAccess.open(folder.path_join("route.svg"),FileAccess.WRITE).store_string('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" fill="#102733"/><polygon points="'+" ".join(outline)+'" fill="none" stroke="#43e7ef" stroke-width="4"/></svg>')
	manifest.preview="route.svg"
	for name in ["route.json","manifest.json","cells.json"]:
		var data: Dictionary=route if name=="route.json" else manifest if name=="manifest.json" else {"format":1,"cells":cells}
		FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
	FileAccess.open(folder.path_join("LICENSE.txt"),FileAccess.WRITE).store_string(attribution+"\n")
	print("TRACK_KIT_EXPORT ",JSON.stringify({"id":track_id,"length_m":measured,"cells":cells.size(),"road_samples":points.size(),"game_executable_rebuilt":false}));return true
