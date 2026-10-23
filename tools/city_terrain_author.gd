extends RefCounted
## Bounded offline adaptation of bsubard's MIT Chunk.gd (pin in source_assets).
## Uses world-coordinate FastNoiseLite and seeded MultiMesh grass. No demo player,
## infinite generator, collision creation or runtime height generation is shipped.
var noise:=FastNoiseLite.new()
func _init() -> void:
	noise.seed=35;noise.frequency=.027
func height_at(x:float,z:float) -> float:
	var shore:float=-853.-4.*sin(z*.003)
	if x<shore:return lerpf(-3.,0.,smoothstep(shore-44.,shore,x))
	var delta:=Vector2(x-300.,z-25.)
	var radius:=125.+3.*sin(atan2(delta.y,delta.x)*3.)
	if delta.length()<radius+2.:return lerpf(-1.4,0.,smoothstep(-12.,2.,delta.length()-radius))
	var park:=smoothstep(-840.,-828.,x)*(1.-smoothstep(-650.,-640.,x))*smoothstep(-515.,-495.,z)*(1.-smoothstep(545.,565.,z))
	return noise.get_noise_2d(x,z)*.35*park
func normal_at(x:float,z:float) -> Vector3:
	return Vector3(height_at(x-.5,z)-height_at(x+.5,z),1.,height_at(x,z-.5)-height_at(x,z+.5)).normalized()
func tile(x0:float,z0:float,width:float,depth:float) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx:=int(width/5.);var nz:=int(depth/5.)
	for z in nz+1:
		for x in nx+1:
			var wx:=x0+x*5.;var wz:=z0+z*5.
			st.set_normal(normal_at(wx,wz));st.set_uv(Vector2(wx,wz)*.1)
			st.add_vertex(Vector3(wx,height_at(wx,wz)-.045,wz))
	for z in nz:
		for x in nx:
			var a:=z*(nx+1)+x;var b:=a+1;var c:=a+nx+1;var d:=c+1
			# Godot front faces are clockwise; supplied normals alone cannot fix culling.
			for index in [a,b,c,b,d,c]:st.add_index(index)
	st.generate_tangents();return st.commit()
func grass(parent:Node3D,center:Vector3,key:Vector2i,material:Material) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=35+key.x*73856093+key.y*19349663
	var mesh:=QuadMesh.new();mesh.size=Vector2(.26,.28);mesh.material=material
	var transforms:Array[Transform3D]=[]
	for i in 650:
		var x:=center.x+rng.randf_range(-100.,100.);var z:=center.z+rng.randf_range(-100.,100.)
		if x< -837. or x> -638. or z< -510. or z>555.:continue
		# Paths remain clear and foundations remain on the approved plane.
		if fmod(z+510.,135.)<7. or absf(x+732.)<2.:continue
		var pose:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(x,height_at(x,z)+.12,z)-center)
		transforms.append(pose)
	if transforms.is_empty():return
	var mm:=MultiMesh.new();mm.mesh=mesh;mm.transform_format=MultiMesh.TRANSFORM_3D;mm.instance_count=transforms.size()
	var node:=MultiMeshInstance3D.new();node.name="CoastalGrass";node.multimesh=mm
	load("res://scripts/content/scene_instances.gd").store(node,transforms)
	node.visibility_range_end=85.;node.visibility_range_end_margin=20.;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node);node.owner=parent
