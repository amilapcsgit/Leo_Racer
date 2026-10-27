class_name LeoCosmeticDamage
extends Node3D
## Conforming triangle copies never modify imported meshes or materials.
const LIMIT := 8
var patches: Array[MeshInstance3D]=[]
var cursor:=0
var kart: LeoKart
var surfaces: Array[Dictionary]=[]
static var manifest: Dictionary={}
static var geometry: Dictionary={}
var triangles:=PackedVector3Array()
var cells: Dictionary={}
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
	kart.contact_reported.connect(on_contact)
func on_contact(event: Dictionary) -> void:
	if event.phase!="impact" or event.normal_speed<3.:return
	var point: Vector3=to_local(event.point)
	var radius:=clampf(.3+event.normal_speed*.012,.35,.7)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	var nearest:=INF;var center:=point
	var candidates: Dictionary={}
	var cell:=Vector3i((point/.75).floor())
	for x in range(-2,3):
		for y in range(-2,3):
			for z in range(-2,3):
				for index in cells.get(cell+Vector3i(x,y,z),PackedInt32Array()):candidates[index]=true
	for index in candidates:
		var middle:=(triangles[index]+triangles[index+1]+triangles[index+2])/3.
		var distance:=middle.distance_to(point)
		if distance<nearest:nearest=distance;center=middle
	if nearest>1.25:return
	for index in candidates:
		var a:=triangles[index];var b:=triangles[index+1];var c:=triangles[index+2]
		if minf(a.distance_to(center),minf(b.distance_to(center),c.distance_to(center)))>radius and ((a+b+c)/3.).distance_to(center)>radius:continue
		var normal:=(b-a).cross(c-a).normalized()
		for vertex in [a,b,c]:vertices.append(vertex+normal*.003);normals.append(normal)
		if vertices.size()>=1536:break
	if vertices.is_empty():return
	var tangents:=PackedFloat32Array()
	for normal in normals:
		var tangent:=normal.cross(Vector3.UP).normalized() if absf(normal.y)<.95 else Vector3.RIGHT
		tangents.append_array([tangent.x,tangent.y,tangent.z,1.])
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=tangents
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var patch: MeshInstance3D
	if patches.size()<LIMIT:
		patch=MeshInstance3D.new();patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(patch);patches.append(patch)
	else:patch=patches[cursor];cursor=(cursor+1)%LIMIT
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/contact_damage.gdshader")
	material.set_shader_parameter("patch_center",center);material.set_shader_parameter("patch_radius",radius)
	patch.mesh=mesh;patch.material_override=material

func build_geometry() -> void:
	if geometry.has(kart.vehicle_key):
		triangles=geometry[kart.vehicle_key].triangles;cells=geometry[kart.vehicle_key].cells;return
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
	geometry[kart.vehicle_key]={"triangles":triangles,"cells":cells}
