class_name LeoLoadingScreen
extends CanvasLayer
var artwork: TextureRect
var operation_id: String="boot"
var race_loading:=false
var backdrop_path: String=""
var caption: Label
var detail: Label
var bar: ProgressBar
var spinner: Label
var elapsed:=0.
var retry: Button
var back: Button
var summary: Label
var race_summary:="Your next race is nearly ready."
var reduced_motion:=false
var panel: Control
var design: Control
var diagram: LeoControllerDiagram
var player_badge: Label
var percentage: Label
var layout_extent:=Vector2.ZERO
func words(parent: Node,at: Vector2,extent: Vector2,text: String,font_size: int,color: Color=Color.WHITE) -> Label:
 var label:=Label.new();label.position=at;label.size=extent;label.text=text;label.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf"))
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label
func _ready() -> void:
 layer=100;process_mode=Node.PROCESS_MODE_ALWAYS
 panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=load("res://assets/ui/theme.tres");add_child(panel)
 var saved:=ConfigFile.new();saved.load("user://leo_racer.cfg");reduced_motion=bool(saved.get_value("display","reduced_motion",false))
 backdrop_path=LeoLoadingBackdrops.begin_load(operation_id,String(saved.get_value("game","track_id","colombo_city")))
 artwork=TextureRect.new();artwork.texture=load(backdrop_path);artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(artwork)
 design=Control.new();design.size=Vector2(1600,900);design.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(design)
 var lion:=TextureRect.new();lion.texture=load("res://assets/art/neon_lion.svg");lion.position=Vector2(64,35);lion.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lion.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;design.add_child(lion);lion.size=Vector2(128,128);lion.scale=Vector2.ONE*.45;lion.name="LoadingBrandMark"
 words(design,Vector2(136,34),Vector2(420,58),"LEO RACER",40)
 caption=words(design,Vector2(64,112),Vector2(1000,68),"GETTING READY",52)
 summary=words(design,Vector2(66,181),Vector2(1430,36),"Learn the controls while your race loads.",25,Color("daeaf1"))
 player_badge=words(design,Vector2(1040,61),Vector2(500,48),"YOUR ACTIVE CONTROLS",24,Color("00e5ed"));player_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 diagram=LeoControllerDiagram.new();diagram.game=get_parent();diagram.reduced_motion=reduced_motion;diagram.position=Vector2(40,450);diagram.size=Vector2(875,292);design.add_child(diagram);diagram.add_to_group("loading_controller_diagrams");diagram.hide();player_badge.hide()
 detail=words(design,Vector2(64,757),Vector2(1330,34),"Discovering game assets…",25)
 percentage=words(design,Vector2(1430,784),Vector2(106,44),"0%",32,Color.WHITE);percentage.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 bar=ProgressBar.new();bar.position=Vector2(64,803);bar.size=Vector2(1334,6);bar.show_percentage=false;bar.add_theme_font_size_override("font_size",1)
 var track:=StyleBoxFlat.new();track.bg_color=Color("152535");track.set_border_width_all(1);track.border_color=Color("647e8c");track.set_corner_radius_all(2);track.content_margin_top=0;track.content_margin_bottom=0;bar.add_theme_stylebox_override("background",track)
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("00dce8");fill.set_corner_radius_all(2);fill.content_margin_top=0;fill.content_margin_bottom=0;bar.add_theme_stylebox_override("fill",fill);design.add_child(bar);bar.size=Vector2(1334,6)
 spinner=words(design,Vector2(64,844),Vector2(900,28),"",18,Color("b0c5d2"))
 retry=Button.new();retry.text="Try Again";retry.position=Vector2(960,839);retry.size=Vector2(270,48);retry.hide();design.add_child(retry)
 back=Button.new();back.text="Choose Another Track";back.position=Vector2(1246,839);back.size=Vector2(290,48);back.hide();design.add_child(back)
 visibility_changed.connect(reset_hidden_context)
func reset_hidden_context() -> void:
 if not visible:
  race_loading=false
  if diagram:diagram.hide();player_badge.hide()
func _process(dt: float) -> void:
 elapsed+=dt
 if not visible:return
 var extent:=get_viewport().get_visible_rect().size
 if extent!=layout_extent:
  layout_extent=extent;var fit:=minf(extent.x/1600.,extent.y/900.);design.scale=Vector2.ONE*fit;design.position=(extent-Vector2(1600,900)*fit)*.5
 if diagram and diagram.fallback:
  var target_width:=1520. if diagram.player_count()==2 else 875.
  if diagram.size.x!=target_width:diagram.size=Vector2(target_width,292.)
  player_badge.text="%d PLAYER%s · YOUR CONTROLS"%[diagram.player_count(),"S" if diagram.player_count()==2 else ""]
 percentage.text="%d%%"%int(bar.value)
func stage(text: String,progress: float) -> void:
 caption.text="GETTING READY";summary.text="Learn the controls while your race loads." if race_loading else "Preparing Leo Racer...";diagram.visible=race_loading;player_badge.visible=race_loading;spinner.text="";detail.text=text;bar.show();percentage.show();bar.value=progress;retry.hide();back.hide();show()
func show_failure(message: String,again: Callable,leave: Callable) -> void:
 for button in [retry,back]:
  for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
 diagram.hide();player_badge.hide();spinner.text="A / ENTER Confirm     B / ESC Back"
 caption.text="LET'S TRY THAT AGAIN";summary.text=message;summary.clip_text=true;detail.text="Choose an option to continue.";bar.hide();percentage.hide()
 retry.show();back.show();retry.pressed.connect(again,CONNECT_ONE_SHOT);back.pressed.connect(leave,CONNECT_ONE_SHOT);retry.grab_focus()
func begin_load(id: String,track_id: String="",preview: String="",context: String="general") -> void:
 race_loading=context=="race"
 if diagram:diagram.visible=race_loading;player_badge.visible=race_loading
 if spinner:spinner.text=""
 operation_id=id;backdrop_path=LeoLoadingBackdrops.begin_load(id,track_id,preview)
 if artwork:artwork.texture=load(backdrop_path) if backdrop_path.begins_with("res://") else LeoAssets.texture(backdrop_path)
func _input(event: InputEvent) -> void:
 if not visible or not back.visible:return
 if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):back.pressed.emit();get_viewport().set_input_as_handled()
