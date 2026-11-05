class_name LeoContactBudget
extends RefCounted
const MAX_MARKS := 256
const MAX_EMITTERS := 16
static var marks: Array[WeakRef]=[]
static var emitters: Array[WeakRef]=[]
static func reserve_mark(mark: Node3D) -> bool:
	marks=marks.filter(func(item):return is_instance_valid(item.get_ref()) and item.get_ref().is_inside_tree())
	if marks.size()>=MAX_MARKS:return false
	marks.append(weakref(mark));return true
static func emit(emitter: GPUParticles3D) -> bool:
	emitters=emitters.filter(func(item):return is_instance_valid(item.get_ref()) and item.get_ref().is_inside_tree() and item.get_ref().emitting)
	for item in emitters:
		if item.get_ref()==emitter:emitter.restart();return true
	if emitters.size()>=MAX_EMITTERS:return false
	emitters.append(weakref(emitter));emitter.restart();return true
