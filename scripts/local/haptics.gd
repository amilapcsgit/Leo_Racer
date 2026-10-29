class_name LeoHaptics
extends Node
## One bounded envelope lane per physical controller. Output/clock are injectable.
var enabled := true
var intensity := 1.
var channels: Dictionary = {}
var output: Callable
var clock: Callable
const SHAPES={"bump":Vector3(.22,.12,.065),"landing":Vector3(.35,.85,.22),"crash":Vector3(.65,1.,.30),"scrape":Vector3(.28,.18,.08),"identify":Vector3(.55,.75,.26)}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("haptics")
	Input.joy_connection_changed.connect(func(device: int,connected: bool):
		if not connected:stop_device(device))
func now() -> float:return float(clock.call()) if clock.is_valid() else Time.get_ticks_msec()/1000.
func send(device: int,weak: float,strong: float,duration: float) -> void:
	if output.is_valid():output.call(device,weak,strong,duration)
	elif device in Input.get_connected_joypads():
		if weak<=0. and strong<=0.:Input.stop_joy_vibration(device)
		else:Input.start_joy_vibration(device,weak,strong,duration)
func play(device: int,kind: String,strength: float=1.) -> void:
	if device<0 or not enabled or intensity<=0.:return
	var shape: Vector3=SHAPES.get(kind,SHAPES.bump)
	var gain:=clampf(strength,0.,1.)*clampf(intensity,0.,1.)
	if gain<=0.:return
	var t:=now()
	if not channels.has(device):channels[device]=[]
	var lane: Array=channels[device]
	# Refreshing scrape must not accumulate an unbounded queue or override a crash.
	for i in range(lane.size()-1,-1,-1):
		if lane[i].kind==kind:lane.remove_at(i)
	lane.append({"kind":kind,"start":t,"end":t+shape.z,"weak":shape.x*gain,"strong":shape.y*gain})
	while lane.size()>5:lane.pop_front()
	tick()
func tick() -> void:
	if not enabled:stop_all();return
	var t:=now()
	for device in channels.keys():
		var lane: Array=channels[device]
		var weak:=0.;var strong:=0.;var remaining:=0.
		for i in range(lane.size()-1,-1,-1):
			var event: Dictionary=lane[i]
			if t>=float(event.end):lane.remove_at(i);continue
			var envelope:=clampf((float(event.end)-t)/(float(event.end)-float(event.start)),0.,1.)
			weak=maxf(weak,float(event.weak)*envelope);strong=maxf(strong,float(event.strong)*envelope)
			remaining=maxf(remaining,float(event.end)-t)
		if lane.is_empty():stop_device(device)
		else:send(device,weak,strong,remaining)
func stop_device(device: int) -> void:
	channels.erase(device)
	if device>=0:send(device,0.,0.,0.)
func stop_all() -> void:
	for device in channels.keys():stop_device(device)
func _process(_dt: float) -> void:tick()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:stop_all()
func _exit_tree() -> void:stop_all()
