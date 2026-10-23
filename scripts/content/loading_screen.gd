class_name LeoLoadingScreen
extends CanvasLayer
var caption: Label
var detail: Label
var bar: ProgressBar
var spinner: Label
var elapsed := 0.
var retry: Button
var back: Button
var summary: Label
var race_summary := "Your next race is nearly ready."
var reduced_motion := false
func _ready() -> void:
	layer=100;process_mode=Node.PROCESS_MODE_ALWAYS
	var panel:=ColorRect.new();panel.color=Color("091a28");panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(panel)
	var art:=TextureRect.new();art.texture=load("res://assets/ui/boot/loading.png");art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(art)
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.02,.035,.06,.4);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(shade)
	var cfg:=ConfigFile.new();cfg.load("user://leo_racer.cfg");reduced_motion=bool(cfg.get_value("display","reduced_motion",false))
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_child(center)
	var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(600,200);box.add_theme_constant_override("separation",24);center.add_child(box)
	caption=Label.new();caption.text="LEO RACER";caption.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf"));caption.add_theme_font_size_override("font_size",64);box.add_child(caption)
	summary=Label.new();summary.text=race_summary;summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.add_theme_font_size_override("font_size",24);summary.modulate=Color("ffc857");box.add_child(summary)
	spinner=Label.new();spinner.text="●  ○  ○";spinner.modulate=Color("65d6d0");box.add_child(spinner)
	detail=Label.new();detail.text="Discovering game assets…";detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(detail)
	bar=ProgressBar.new();bar.show_percentage=false;box.add_child(bar)
	var buttons:=HBoxContainer.new();box.add_child(buttons)
	retry=Button.new();retry.text="Try Again";retry.custom_minimum_size=Vector2(240,64);retry.hide();buttons.add_child(retry)
	back=Button.new();back.text="Choose Another Track";back.custom_minimum_size=Vector2(240,64);back.hide();buttons.add_child(back)
func _process(dt: float) -> void:
	elapsed+=dt
	if spinner and not reduced_motion:spinner.text=["●  ○  ○","○  ●  ○","○  ○  ●"][int(elapsed*4.)%3]
func stage(text: String, progress: float) -> void:
	caption.text="GETTING READY";summary.text=race_summary;detail.text=text;bar.show();bar.value=progress;retry.hide();back.hide();show()
func show_failure(message: String, again: Callable, leave: Callable) -> void:
	for button in [retry,back]:
		for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
	caption.text="LET'S TRY THAT AGAIN";detail.text=message;bar.hide()
	retry.show();back.show();retry.pressed.connect(again,CONNECT_ONE_SHOT);back.pressed.connect(leave,CONNECT_ONE_SHOT);retry.grab_focus()
