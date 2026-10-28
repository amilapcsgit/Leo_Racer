class_name LeoPreparationBudget
extends RefCounted
const LIMIT_USEC:=4000
static var frame: int=-1
static var used:=0
static var largest_slice:=0
static func checkpoint(tree: SceneTree) -> void:
	if frame!=Engine.get_process_frames():frame=Engine.get_process_frames();used=0
	if used>=LIMIT_USEC:
		await tree.process_frame
		frame=Engine.get_process_frames();used=0
static func record(began: int) -> void:
	if frame!=Engine.get_process_frames():frame=Engine.get_process_frames();used=0
	var elapsed:=Time.get_ticks_usec()-began;used+=elapsed;largest_slice=maxi(largest_slice,elapsed)
