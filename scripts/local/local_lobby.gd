class_name LeoLocalLobby
extends PanelContainer
var game: Node3D
var ready_flags: Array[bool]=[false,false]
var ready_buttons: Array[Button]=[]
var summaries: Array[Label]=[]
var start_button: Button
var status: Label
var cards: Array[VBoxContainer]=[]
func _ready() -> void:
 theme=load("res://assets/config/local_ui_theme.tres")
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",45);margin.add_theme_constant_override("margin_right",45);margin.add_theme_constant_override("margin_top",30);margin.add_theme_constant_override("margin_bottom",30);add_child(margin)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",18);margin.add_child(body)
 var title:=Label.new();title.text="LOCAL TWO PLAYER / COLOMBO GRAND PRIX";title.add_theme_font_size_override("font_size",32);body.add_child(title)
 var subtitle:=Label.new();subtitle.text="P1 LEFT / P2 RIGHT   |   4 AI OPPONENTS   |   3 LAPS";subtitle.add_theme_font_size_override("font_size",22);body.add_child(subtitle)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",30);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(row)
 for slot in 2:
  var index:=slot;var local: LeoLocalPlayer=game.local_players[slot]
  var card:=VBoxContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_constant_override("separation",14);var backing:=PanelContainer.new();backing.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(backing);var style:=StyleBoxFlat.new();style.bg_color=Color(.045,.075,.10,1.);style.border_color=Color("67d6db") if slot==0 else Color("e8b976");style.set_border_width_all(1);style.set_content_margin_all(16.);style.set_corner_radius_all(8);backing.add_theme_stylebox_override("panel",style);backing.add_child(card);cards.append(card)
  var heading:=Label.new();heading.text="PLAYER %d" % (slot+1);heading.add_theme_font_size_override("font_size",30);card.add_child(heading)
  var name_field:=LineEdit.new();name_field.max_length=32;name_field.text=local.player_name if not local.player_name.is_empty() else game.catalog.driver(local.driver_id).display_name;name_field.placeholder_text="Player name";name_field.custom_minimum_size.y=48;card.add_child(name_field)
  name_field.text_changed.connect(func(value: String):game.selected_player_slot=index;game.apply_garage_selection(local.driver_id,local.vehicle_id,value);ready_flags[index]=false)
  var summary:=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.custom_minimum_size.y=160;summary.add_theme_font_size_override("font_size",22);card.add_child(summary);summaries.append(summary)
  add_button(card,"CAR & RACER / Y",func():game.selected_player_slot=index;game.hud.show_garage("lobby"))
  add_button(card,"DEVICE & CONTROLS / X",func():game.hud.show_controls(index))
  var ready_button:=add_button(card,"READY / A",func():toggle_ready(index));ready_buttons.append(ready_button)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",20);body.add_child(status)
 var bottom:=HBoxContainer.new();body.add_child(bottom)
 start_button=add_button(bottom,"START TWO-PLAYER RACE / START",func():game.try_start_local_race())
 add_button(bottom,"MAIN MENU",game.return_menu)
 game.input_router.binding_changed.connect(clear_ready)
func add_button(parent: Node,text: String,callback: Callable) -> Button:
 var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(0,55);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",20);button.pressed.connect(callback);parent.add_child(button);return button
func clear_ready() -> void:ready_flags=[false,false]
func toggle_ready(slot: int) -> void:
 var problem: String=game.input_router.ready_problem(slot)
 if not problem.is_empty():status.text=problem;return
 ready_flags[slot]=not ready_flags[slot]
func _process(_dt: float) -> void:
 for slot in 2:
  var local: LeoLocalPlayer=game.local_players[slot]
  var profile: LeoPlayerInput=game.input_router.players[slot]
  var device_name: String="KEYBOARD" if profile.kind=="keyboard" else Input.get_joy_name(profile.device) if profile.device in Input.get_connected_joypads() else "SELECT CONTROLLER / WHEEL"
  summaries[slot].text="%s\n%s\n\n%s" % [game.catalog.driver(local.driver_id).display_name,game.catalog.vehicle(local.vehicle_id).display_name,device_name]
  ready_buttons[slot].text="READY / PRESS A TO UNREADY" if ready_flags[slot] else "READY / A"
 start_button.disabled=not (ready_flags[0] and ready_flags[1])
func _input(event: InputEvent) -> void:
 if not is_visible_in_tree() or game.hud.modal_root.get_child_count()>0:return
 if event is InputEventJoypadButton and event.pressed:
  var owner: int=-1
  for i in 2:
   if game.input_router.players[i].kind!="keyboard" and game.input_router.players[i].device==event.device:owner=i
  if owner>=0:
   match event.button_index:
    JOY_BUTTON_A:toggle_ready(owner)
    JOY_BUTTON_Y:game.selected_player_slot=owner;game.hud.show_garage("lobby")
    JOY_BUTTON_X:game.hud.show_controls(owner)
    JOY_BUTTON_START:
     if not start_button.disabled:game.try_start_local_race()
    JOY_BUTTON_B:game.return_menu()
  get_viewport().set_input_as_handled()
func _exit_tree() -> void:
 if game.input_router.binding_changed.is_connected(clear_ready):game.input_router.binding_changed.disconnect(clear_ready)
