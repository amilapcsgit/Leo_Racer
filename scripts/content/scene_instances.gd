class_name LeoSceneInstances
extends RefCounted
## Dummy/headless renderers do not retain MultiMesh GPU buffers for serialization.
## Explicit CPU instance data makes offline bakes portable across renderers.
static func store(node: MultiMeshInstance3D, transforms: Array[Transform3D], colors: PackedColorArray = PackedColorArray()) -> void:
	var buffer:=PackedFloat32Array();var bounds:=AABB();var first:=true
	var colored:=node.multimesh.use_colors
	for i in transforms.size():
		var t:=transforms[i];var b:=t.basis;var p:=t.origin
		buffer.append_array(PackedFloat32Array([b.x.x,b.y.x,b.z.x,p.x,b.x.y,b.y.y,b.z.y,p.y,b.x.z,b.y.z,b.z.z,p.z]))
		if colored:
			var c:=colors[i] if i<colors.size() else Color.WHITE
			buffer.append_array(PackedFloat32Array([c.r,c.g,c.b,c.a]))
		var box:=t*node.multimesh.mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	node.set_meta("instance_buffer",buffer);node.set_meta("instance_bounds",bounds)
	node.multimesh.custom_aabb=bounds;node.multimesh.buffer=buffer

static func restore(node: Node) -> void:
	if node is MultiMeshInstance3D and node.multimesh and node.has_meta("instance_buffer"):
		var buffer: PackedFloat32Array=node.get_meta("instance_buffer")
		var stride:=16 if node.multimesh.use_colors else 12
		if buffer.size()==node.multimesh.instance_count*stride:
			node.multimesh=node.multimesh.duplicate();node.multimesh.custom_aabb=node.get_meta("instance_bounds",AABB());node.multimesh.buffer=buffer
		else:push_error("Invalid scenery instance buffer: "+String(node.name))
	for child in node.get_children():restore(child)
