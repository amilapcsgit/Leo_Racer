class_name LeoLoadingScreen
extends CanvasLayer
var caption: Label
var detail: Label
var bar: ProgressBar
var spinner: Label
var elapsed := 0.
var retry: Button
var back: Button
func _ready() -> void:
	layer=100;process_mode=Node.PROCESS_MODE_ALWAYS
	var panel:=ColorRect.new();panel.color=Color("091a28");panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(panel)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_child(center)
	var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(600,200);box.add_theme_constant_override("separation",24);center.add_child(box)
	caption=Label.new();caption.text="LEO RACER";caption.add_theme_font_size_override("font_size",44);box.add_child(caption)
	spinner=Label.new();spinner.text="●  ○  ○";spinner.modulate=Color("65d6d0");box.add_child(spinner)
	detail=Label.new();detail.text="Discovering game assets…";detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(detail)
	bar=ProgressBar.new();bar.show_percentage=false;box.add_child(bar)
	var buttons:=HBoxContainer.new();box.add_child(buttons)
	retry=Button.new();retry.text="RETRY";retry.hide();buttons.add_child(retry)
	back=Button.new();back.text="BACK";back.hide();buttons.add_child(back)
func _process(dt: float) -> void:
	elapsed+=dt
	if spinner:spinner.text=["●  ○  ○","○  ●  ○","○  ○  ●"][int(elapsed*4.)%3]
func stage(text: String, progress: float) -> void:
	caption.text="LEO RACER";detail.text=text;bar.value=progress;retry.hide();back.hide();show()
func show_failure(message: String, again: Callable, leave: Callable) -> void:
	for button in [retry,back]:
		for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
	caption.text="ASSETS UNAVAILABLE";detail.text=message
	retry.show();back.show();retry.pressed.connect(again,CONNECT_ONE_SHOT);back.pressed.connect(leave,CONNECT_ONE_SHOT);retry.grab_focus()
