class_name LeoOpponentAudio
extends Node3D
## Two nearby voices per human, four maximum. No global unbounded engine mix.
var voices: Array[AudioStreamPlayer] = []
var panners: Array[AudioEffectPanner] = []
var buses: Array[String] = []
var elapsed := 0.0
func _ready() -> void:
	for i in 4:
		var bus := "Nearby_"+str(get_instance_id())+"_"+str(i)
		AudioServer.add_bus();var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,bus);AudioServer.set_bus_send(index,"Effects");buses.append(bus)
		var panner := AudioEffectPanner.new();AudioServer.add_bus_effect(index,panner);panners.append(panner)
		var voice := AudioStreamPlayer.new();voice.bus=bus;voice.volume_db=-70.
		add_child(voice);voices.append(voice)

func update(game: Node3D, dt: float) -> void:
	elapsed-=dt
	if elapsed>0.:return
	elapsed=.1
	for voice in voices:voice.volume_db=-70.
	for slot in game.human_count:
		var local: LeoLocalPlayer=game.local_players[slot]
		if not is_instance_valid(local.kart):continue
		var nearby: Array=[]
		for other: LeoKart in game.karts:
			if other.is_player or not other.active:continue
			if other.position.distance_to(local.kart.position)<55.:nearby.append(other)
		nearby.sort_custom(func(a,b):return a.position.distance_squared_to(local.kart.position)<b.position.distance_squared_to(local.kart.position))
		for i in mini(2,nearby.size()):
			var other: LeoKart=nearby[i]
			var voice := voices[slot*2+i]
			var stream := LeoVehicleAudio.loop(LeoVehicleAudio.profile(other.definition),1)
			if voice.stream!=stream:voice.stream=stream;voice.play()
			if not voice.playing:voice.play()
			voice.pitch_scale=.8+absf(other.wheel_motion_speed)/maxf(1.,other.max_speed)*.7
			panners[slot*2+i].pan=clampf(local.kart.global_basis.x.dot((other.position-local.kart.position).normalized())*.75,-.75,.75)
			voice.volume_db=-31.-local.kart.position.distance_to(other.position)*.45-(3. if game.human_count==2 else 0.)

func stop() -> void:
	for voice in voices:voice.stop()

func _exit_tree() -> void:
	for bus in buses:
		var index := AudioServer.get_bus_index(bus)
		if index>0:AudioServer.remove_bus(index)
