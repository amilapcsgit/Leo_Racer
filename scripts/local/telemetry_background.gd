extends Control
var instruments: Control
var game: Node3D:
	get:return instruments.game
var heading_font: Font:
	get:return instruments.heading_font
var display_speed:=0.
var ready_flash:=0.
var time:=0.
var map_projection: Transform2D:
	get:return instruments.map_projection
func instrument_kart() -> LeoKart:return instruments.instrument_kart()
func _draw() -> void:
	if is_instance_valid(instruments):LeoTelemetry.draw(self,true)
