extends PanelContainer
@onready var scroll: ScrollContainer=$Scroll
@onready var body: VBoxContainer=$Scroll/Body
func _process(_dt: float) -> void:
 scroll.custom_minimum_size.y=minf(740.,body.get_combined_minimum_size().y)
