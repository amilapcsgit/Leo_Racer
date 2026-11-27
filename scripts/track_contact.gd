class_name LeoTrackContact
extends RefCounted
## Route-following static rails make the visible road edge the physical boundary.
static func mark_drivable_surface(resident: Node, track_id: String) -> void:
	if track_id != "wennappuwa":return
	# The 1.0.1 road deck is one concave floor. Its internal triangle edges can
	# produce a lateral contact normal even on the continuous asphalt.
	var road := resident.get_node_or_null("_StaticBody3D_6382") as StaticBody3D
	if not road or road.get_child_count()!=1:return
	var collision := road.get_child(0) as CollisionShape3D
	if collision and collision.shape is ConcavePolygonShape3D and collision.shape.resource_path.get_file()=="240e458e2626f89ce13aa4462b22fc23069e24ffb436e6544a5e33888d54999d.res":
		road.set_meta("continuous_road_deck",true)

static func install(world: Node3D, circuit: LeoCircuit) -> void:
	if world.has_node("ContinuousRoadEdges"):return
	var root:=Node3D.new();root.name="ContinuousRoadEdges";world.add_child(root)
	var count:=ceili(circuit.length/8.)
	var mesh:=BoxMesh.new();mesh.size=Vector3(.28,.72,1.)
	var material:=StandardMaterial3D.new();material.albedo_color=Color("b7b8ac");material.roughness=.88;mesh.material=material
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=count*2
	var visible:=MultiMeshInstance3D.new();visible.multimesh=multi;root.add_child(visible)
	var curb_mesh:=BoxMesh.new();curb_mesh.size=Vector3(.55,.045,1.)
	var curb_material:=StandardMaterial3D.new();curb_material.vertex_color_use_as_albedo=true;curb_material.roughness=.86;curb_mesh.material=curb_material
	var curbs:=MultiMesh.new();curbs.transform_format=MultiMesh.TRANSFORM_3D;curbs.use_colors=true;curbs.mesh=curb_mesh;curbs.instance_count=count*2
	var curb_view:=MultiMeshInstance3D.new();curb_view.multimesh=curbs;root.add_child(curb_view)
	for i in count:
		var s:=circuit.length*float(i)/count;var end:=circuit.length*float(i+1)/count
		for side_index in 2:
			var side:=-1. if side_index==0 else 1.
			var a:=circuit.sample(s,side*(circuit.width_at(s)*.5+.55+.14))
			var b:=circuit.sample(end,side*(circuit.width_at(end)*.5+.55+.14))
			var delta:=b-a;var up:=circuit.frame_at((s+end)*.5).y if circuit.elevated else Vector3.UP
			var basis:=Basis.looking_at(delta.normalized(),up)
			var body:=StaticBody3D.new();body.set_meta("contact_surface","concrete");body.collision_layer=1
			body.transform=Transform3D(basis,(a+b)*.5+up*.36)
			var shape:=BoxShape3D.new();shape.size=Vector3(.28,.72,delta.length()+.12)
			var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);root.add_child(body)
			multi.set_instance_transform(i*2+side_index,Transform3D(basis*Basis.from_scale(Vector3(1,1,delta.length()+.12)),body.position))
			curbs.set_instance_transform(i*2+side_index,Transform3D(basis*Basis.from_scale(Vector3(1,1,delta.length()+.12)),(a+b)*.5-basis.x*side*.415+up*.025))
			curbs.set_instance_color(i*2+side_index,Color("bd5146") if i%2==0 else Color("ddd8c5"))
