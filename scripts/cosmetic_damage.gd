class_name LeoCosmeticDamage
extends Node3D
## Conforming triangle copies never modify imported meshes or materials.
const LIMIT := 8
var patches: Array[MeshInstance3D]=[]
var available: Array[MeshInstance3D]=[]
var cursor:=0
var kart: LeoKart
var surfaces: Array[Dictionary]=[]
static var manifest: Dictionary={}
static var geometry: Dictionary={}
var triangles:=PackedVector3Array()
var cells: Dictionary={}
var centers:=PackedVector3Array()
var triangle_extents:=PackedFloat32Array()
var offset_vertices:=PackedVector3Array()
var patch_normals:=PackedVector3Array()
var patch_tangents:=PackedFloat32Array()
var last_contact_ms:=0.
func setup(owner_kart: LeoKart) -> void:
	kart=owner_kart
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/vehicle-damage-v1.json"))
	var allowed: Array=manifest.get(kart.vehicle_key,[])
	for node in kart.chassis.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if material and String(material.resource_name) in allowed:surfaces.append({"node":node,"surface":surface})
	build_geometry()
	for i in LIMIT:
		var patch:=MeshInstance3D.new();patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://shaders/contact_damage.gdshader")
		patch.material_override=material;patch.visible=false;add_child(patch);available.append(patch)
	kart.contact_reported.connect(on_contact)
func on_contact(event: Dictionary) -> void:
	if event.phase!="impact" or event.normal_speed<3.:return
	var began:=Time.get_ticks_usec()
	var point: Vector3=to_local(event.point)
	var radius:=clampf(.3+event.normal_speed*.012,.35,.7)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	var nearest:=INF;var center:=point
	var candidates:=PackedInt32Array()
	var cell:=Vector3i((point/.75).floor())
	for x in range(-2,3):
		for y in range(-2,3):
			for z in range(-2,3):
				# Each triangle belongs to exactly one centroid cell; no deduplication is needed.
				var key:=cell+Vector3i(x,y,z)
				if cells.has(key):candidates.append_array(cells[key])
	for index in candidates:
		var middle:=centers[index/3]
		var distance:=middle.distance_squared_to(point)
		if distance<nearest:nearest=distance;center=middle
	if nearest>1.5625:return
	var radius_squared:=radius*radius
	var tangents:=PackedFloat32Array()
	for index in candidates:
		# Conservative bound: a triangle outside this sphere cannot pass the
		# original vertex-or-centroid test, including long body-panel triangles.
		var triangle:=index/3;var extent:=radius+triangle_extents[triangle]+.00001
		if centers[triangle].distance_squared_to(center)>extent*extent:continue
		var a:=triangles[index];var b:=triangles[index+1];var c:=triangles[index+2]
		if minf(a.distance_squared_to(center),minf(b.distance_squared_to(center),c.distance_squared_to(center)))>radius_squared and centers[index/3].distance_squared_to(center)>radius_squared:continue
		vertices.append_array(offset_vertices.slice(index,index+3));normals.append_array(patch_normals.slice(index,index+3));tangents.append_array(patch_tangents.slice(index*4,(index+3)*4))
		if vertices.size()>=1536:break
	if vertices.is_empty():return
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var patch: MeshInstance3D
	if patches.size()<LIMIT:
		patch=available.pop_back();patches.append(patch)
	else:patch=patches[cursor];cursor=(cursor+1)%LIMIT
	var material:=patch.material_override as ShaderMaterial
	material.set_shader_parameter("patch_center",center);material.set_shader_parameter("patch_radius",radius)
	patch.mesh=mesh;patch.visible=true
	last_contact_ms=(Time.get_ticks_usec()-began)/1000.

func build_geometry() -> void:
	if geometry.has(kart.vehicle_key):
		var cached: Dictionary=geometry[kart.vehicle_key]
		triangles=cached.triangles;cells=cached.cells;centers=cached.centers;triangle_extents=cached.extents;offset_vertices=cached.offset_vertices;patch_normals=cached.normals;patch_tangents=cached.tangents;return
	for entry in surfaces:
		var node: MeshInstance3D=entry.node
		var arrays: Array=node.mesh.surface_get_arrays(int(entry.surface))
		if arrays.is_empty():continue
		var source: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var transform:=global_transform.affine_inverse()*node.global_transform
		var count:=indices.size() if not indices.is_empty() else source.size()
		for i in range(0,count-2,3):
			var a:=transform*source[indices[i] if not indices.is_empty() else i]
			var b:=transform*source[indices[i+1] if not indices.is_empty() else i+1]
			var c:=transform*source[indices[i+2] if not indices.is_empty() else i+2]
			var key:=Vector3i((((a+b+c)/3.)/.75).floor())
			if not cells.has(key):cells[key]=PackedInt32Array()
			cells[key].append(triangles.size());triangles.append(a);triangles.append(b);triangles.append(c)
	for i in range(0,triangles.size(),3):
		var a:=triangles[i];var b:=triangles[i+1];var c:=triangles[i+2]
		var normal:=(b-a).cross(c-a).normalized();var tangent:=normal.cross(Vector3.UP).normalized() if absf(normal.y)<.95 else Vector3.RIGHT
		var center:=(a+b+c)/3.;centers.append(center);triangle_extents.append(maxf(center.distance_to(a),maxf(center.distance_to(b),center.distance_to(c))))
		offset_vertices.append_array(PackedVector3Array([a+normal*.003,b+normal*.003,c+normal*.003]))
		patch_normals.append_array(PackedVector3Array([normal,normal,normal]))
		for vertex in 3:patch_tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,1.]))
	geometry[kart.vehicle_key]={"triangles":triangles,"cells":cells,"centers":centers,"extents":triangle_extents,"offset_vertices":offset_vertices,"normals":patch_normals,"tangents":patch_tangents}
