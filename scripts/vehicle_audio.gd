class_name LeoVehicleAudio
extends Node
## Original generated loop layers; no external recordings or runtime dependencies.
static var streams: Dictionary = {}
var kart: LeoKart
var layers: Array[AudioStreamPlayer] = []
var rpm := 900.0
var gear := 1
var load_gain := 0.0
var shift_time := 0.0
var throttle := 0.0
var bus_name := ""
var reverb: AudioEffectReverb
var panner: AudioEffectPanner
var room_gain := 0.0
var cover_gain := 0.0
var cover_timer := 0.0

static func profile(vehicle: VehicleDefinition) -> String:
	var key := String(vehicle.id)
	if key in ["bigster","duster"]:return "suv"
	if vehicle.electric_boost or key=="hover" or "byd" in key or "concept" in key or "future" in key or "h2_speed" in key:return "electric"
	if key=="race_bus":return "bus"
	if key in ["bigster","duster"] or LeoRaceRules.balance().imports.get(key,"") in ["duster","utility"]:return "suv"
	var group: String=LeoRaceRules.balance().imports.get(key,"")
	if key in ["race_tuk","colombo_tuk","pony","aqua","pink","blue"] or group=="compact" or (group.is_empty() and not LeoRaceRules.balance().vehicles.has(key)):return "small"
	return "sport"

static func loop(kind: String, layer: int) -> AudioStreamWAV:
	var key := kind+str(layer)
	if streams.has(key):return streams[key]
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=11025
	var bytes := PackedByteArray();bytes.resize(22050)
	# Multiples of four make every harmonic/layer periodic over the half-second loop.
	var base: float={"electric":112.,"bus":44.,"suv":60.,"small":88.,"sport":96.}.get(kind,60.)
	var rng := RandomNumberGenerator.new();rng.seed=1234+layer
	var filtered := 0.0
	for i in 11025:
		var time := float(i)/22050.
		var value := 0.0
		if layer>=3:
			filtered=lerpf(filtered,rng.randf_range(-1.,1.),.16 if layer==3 else .4)
			value=filtered*.45
		else:
			var phase := TAU*base*(1.+float(layer)*.5)*time
			value=(sin(phase)+sin(phase*2.)*.3+sin(phase*4.)*.12)*.28
			if kind=="electric":value=sin(phase)*.22+sin(phase*3.)*.06
		bytes.encode_s16(i*2,int(clampf(value,-1.,1.)*28000.))
	stream.data=bytes;streams[key]=stream
	return stream

func setup(owner_kart: LeoKart) -> void:
	kart=owner_kart
	bus_name="Vehicle_"+str(get_instance_id())
	AudioServer.add_bus();var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name);AudioServer.set_bus_send(index,"Effects")
	reverb=AudioEffectReverb.new();reverb.wet=0.;reverb.dry=1.;reverb.room_size=.65
	AudioServer.add_bus_effect(index,reverb)
	panner=AudioEffectPanner.new();AudioServer.add_bus_effect(index,panner)
	for i in 5:
		var player := AudioStreamPlayer.new();player.bus=bus_name
		player.stream=loop(profile(kart.definition),i);player.volume_db=-70.
		add_child(player);layers.append(player);player.play()
	if kart.engine:kart.engine.stop()

func stop() -> void:
	for player in layers:player.stop()

func update(dt: float) -> void:
	if not is_instance_valid(kart):return
	var ratio := clampf(absf(kart.wheel_motion_speed)/kart.max_speed,0.,1.3)
	var desired_gear := clampi(int(ratio*5.)+1,1,6)
	# Hysteresis prevents repeated shifts near a boundary.
	if desired_gear>gear and ratio>float(gear)*.2+.015:gear=desired_gear;shift_time=.12
	elif desired_gear<gear and ratio<float(gear-1)*.2-.025:gear=desired_gear;shift_time=.12
	shift_time=maxf(0.,shift_time-dt)
	var desired_rpm := 900.+clampf((ratio-float(gear-1)*.2)/.2,0.,1.)*5300.
	rpm=lerpf(rpm,desired_rpm,1.-exp(-dt*10.))
	load_gain=lerpf(load_gain,(absf(throttle) if kart.speed<-.5 else maxf(0.,throttle)) if kart.active else 0.,1.-exp(-dt*6.))
	var rev := clampf((rpm-900.)/5300.,0.,1.)
	var mix := [1.-smoothstep(.05,.35,ratio),1.-absf(rev-.45),smoothstep(.35,.95,rev)]
	var split_gain := .7 if kart.get_parent().get("human_count")==2 else 1.
	panner.pan=(-.25 if kart.local_slot==0 else .25) if split_gain<1. else 0.
	for i in 3:
		var gain: float=mix[i]*(.35+.65*load_gain)*split_gain*(.65 if shift_time>0. else 1.)
		layers[i].volume_db=linear_to_db(maxf(.0001,gain)) - 24.
		layers[i].pitch_scale=.75+rev*.85
	layers[3].volume_db=linear_to_db(maxf(.0001,ratio*ratio*split_gain))-23.
	layers[4].volume_db=linear_to_db(maxf(.0001,ratio*(.8 if kart.drifting else .12)*split_gain))-25.
	# Authored Area3D volumes are presentation-only and independent per player.
	var room := 0.0
	cover_timer-=dt
	if cover_timer<=0.:
		cover_timer=.2
		var point := kart.global_position+Vector3.UP*1.4
		var ceiling := PhysicsRayQueryParameters3D.create(point,point+Vector3.UP*7.,1,[kart.get_rid()])
		cover_gain=.3 if not kart.get_world_3d().direct_space_state.intersect_ray(ceiling).is_empty() else 0.
	room=cover_gain
	for zone in get_tree().get_nodes_in_group("race_audio_zones"):
		if zone is Area3D and zone.overlaps_body(kart):room=maxf(room,float(zone.get_meta("reverb",.4)))
	room_gain=lerpf(room_gain,room,1.-exp(-dt*4.));reverb.wet=room_gain

func _exit_tree() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index>0:AudioServer.remove_bus(index)
