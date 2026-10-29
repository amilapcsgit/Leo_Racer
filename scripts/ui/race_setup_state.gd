class_name LeoRaceSetupState
extends RefCounted
var player_count := 1
var lap_count := 3
var track_id := ""
var return_focus := "start"
var players: Array[LeoLocalPlayer]=[]
func sync(game: Node) -> void:
 lap_count=game.selected_laps;player_count=game.human_count;track_id=game.chosen_track_id;players=game.local_players
