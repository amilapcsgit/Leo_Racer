class_name LeoFrontend
extends Node
var game: Node3D
var hud: LeoHUD
var audio: LeoUIAudio
var setup:=LeoRaceSetupState.new()
var screen := "home"
var modal_back: Callable
var previous_focus: WeakRef
var suspended: Array[Control]=[]
var start_button: Button
var player_status: Array[Label]=[]
var last_focus := {}
var transition: Tween
var starting := false
var pause_open := false
var last_pad := false
var prompt: Label
var modal_title := ""
var focus_graph := ""
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 game.input_router.binding_changed.connect(update_devices)
func label(parent: Node,words: String,fs: int=24,color: Color=Color("f5f7fa")) -> Label:
 var node:=Label.new();node.text=words
 if fs>=40:node.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf"))
 node.add_theme_font_size_override("font_size",fs);node.modulate=color;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 parent.add_child(node);return node
func action(parent: Node,words: String,callback: Callable,primary: bool=false) -> LeoActionButton:
 var node: LeoActionButton=load("res://scenes/ui/ActionButton.tscn").instantiate()
 node.text=words;node.sound_key="back" if words in ["Back","Cancel","Keep Going"] else "select";node.primary=primary;node.contained=hud.modal_root.is_ancestor_of(parent);node.glyph_name={"Garage":"garage","Records":"records","Settings":"settings"}.get(words,"");node.reduced_motion=game.reduced_motion;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;node.pressed.connect(callback);parent.add_child(node)
 node.focus_entered.connect(func():last_focus[screen]=str(node.get_meta("focus_key",words)))
 return node
func card(parent: Node) -> VBoxContainer:
 var panel: PanelContainer=load("res://scenes/ui/PlayerCard.tscn").instantiate();parent.add_child(panel)
 return panel.get_node("Body") as VBoxContainer
func picture(parent: Node,path: String,min_size: Vector2) -> TextureRect:
 var node:=TextureRect.new()
 if path.is_absolute_path() and not path.begins_with("res://"):node.texture=LeoAssets.texture(path)
 elif ResourceLoader.exists(path):node.texture=load(path)
 node.custom_minimum_size=min_size;node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func shell(title: String,subtitle: String="") -> VBoxContainer:
 close_modal(false);pause_open=false;starting=false;player_status.clear()
 game.input_router.gameplay_enabled=false;game.input_router.assignment_locked=false;game.input_router.controls_testing=false;game.input_router.clear_all()
 hud.clear(hud.menu_root);hud.clear(hud.hud_root);hud.hud_root.hide();hud.speed_overlay.hide();hud.menu_root.show()
 hud.menu_root.theme=load("res://assets/ui/theme.tres")
 var art:=picture(hud.menu_root,"res://assets/ui/art/home.png",Vector2.ZERO);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.cover_viewport(art)
 var dim:=ColorRect.new();dim.color=Color(0.025,.04,.07,.35 if screen=="home" else .78);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu_root.add_child(dim);hud.cover_viewport(dim)
 if screen=="home":
  var atmosphere:=LeoBackdropFX.new();atmosphere.art=art;atmosphere.reduced_motion=game.reduced_motion;hud.menu_root.add_child(atmosphere)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right"]:margin.add_theme_constant_override("margin_"+side,48)
 for side in ["top","bottom"]:margin.add_theme_constant_override("margin_"+side,36)
 hud.menu_root.add_child(margin)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",24);margin.add_child(box)
 var header:=HBoxContainer.new();header.custom_minimum_size.y=72;box.add_child(header)
 var heading:=label(header,title,56);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var corner:=action(header,"Back",back_screen) if screen!="home" else action(header,"Quit",func():confirm("Quit Leo Racer?","Your choices are saved.",game.quit_game,show_home))
 corner.custom_minimum_size.x=160;corner.size_flags_horizontal=Control.SIZE_SHRINK_END
 if not subtitle.is_empty():label(box,subtitle,24,Color("b9c7d6"))
 var content:=VBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(content)
 prompt=label(box,"",20,Color("b9c7d6"));prompt.custom_minimum_size.y=52;update_prompt()
 if transition:transition.kill()
 margin.modulate.a=0.
 transition=create_tween().set_parallel(true);transition.tween_property(margin,"modulate:a",1.,.12 if game.reduced_motion else .18)
 if not game.reduced_motion:transition.tween_property(margin,"position",Vector2.ZERO,.18).from(Vector2(16,0))
 return content
func show_home() -> void:
 game.input_router.assignment_locked=false;game.input_router.resolve_automatic(game.human_count)
 screen="home";hud.scene_mode="menu"
 var body:=shell("LEO RACER","COLOMBO AFTER DARK")
 var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(row)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=480;left.add_theme_constant_override("separation",16);row.add_child(left)
 label(left,"Your coast. Your race.",32)
 label(left,game.track_definition.display_name+"\n"+game.catalog.vehicle(game.local_players[0].vehicle_id).display_name,24,Color("b9c7d6"))
 var go:=action(left,"Go Race   →",func():show_setup(),true)
 var grid:=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16);left.add_child(grid)
 action(grid,"Garage",func():open_garage(0))
 action(grid,"Records",show_records)
 action(grid,"Settings",show_settings)
 action(grid,"How to Play",show_guide)
 action(grid,"Content",game.show_content_manager)
 label(left,"Pick your ride. Hit the road.",24,Color("ffc857"))
 restore(go)
func show_setup(count: int=-1) -> void:
 if count>0:game.human_count=count
 game.state="lobby" if game.human_count==2 else "menu"
 setup.sync(game);screen="setup";hud.scene_mode="lobby"
 game.input_router.assignment_locked=false;game.input_router.resolve_automatic(game.human_count)
 var body:=shell("LET'S RACE","Pick your ride. Hit the road.")
 var top:=HBoxContainer.new();body.add_child(top)
 for n in [1,2]:
  var number: int=n
  action(top,("✓ " if game.human_count==n else "")+("1 Player" if n==1 else "2 Players"),func():show_setup(number)).custom_minimum_size.x=210
 var track_button:=action(top,game.track_definition.display_name+"  ·  Change Track",show_tracks);track_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(row)
 for slot in game.human_count:
  var index: int=slot;var local: LeoLocalPlayer=game.local_players[slot]
  var box:=card(row)
  var header:=HBoxContainer.new();box.add_child(header)
  var portrait:=TextureRect.new();portrait.texture=game.catalog.driver(local.driver_id).portrait;portrait.custom_minimum_size=Vector2(96,96);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;header.add_child(portrait)
  var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(words)
  label(words,"PLAYER %d" % (slot+1),20,Color("43e7ef") if slot==0 else Color("ffc857"))
  label(words,local.player_name if not local.player_name.is_empty() else game.catalog.driver(local.driver_id).display_name,32)
  label(box,game.catalog.vehicle(local.vehicle_id).display_name,28)
  var vehicle_image:=TextureRect.new();vehicle_image.texture=game.catalog.vehicle(local.vehicle_id).thumbnail;vehicle_image.custom_minimum_size=Vector2(160,96);vehicle_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;vehicle_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;header.add_child(vehicle_image)
  var chip: HBoxContainer=load("res://scenes/ui/DeviceChip.tscn").instantiate();box.add_child(chip)
  var status_label:=chip.get_node("Caption") as Label;status_label.add_theme_font_size_override("font_size",24);status_label.custom_minimum_size.y=64;player_status.append(status_label)
  var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(spacer)
  var actions:=HBoxContainer.new();box.add_child(actions)
  action(actions,"Change Ride",func():open_garage(index)).set_meta("focus_key","ride_%d" % slot)
  action(actions,"Controls",func():show_controls(index)).set_meta("focus_key","controls_%d" % slot)
 start_button=action(body,"Start Race   →",start_selected,true);start_button.custom_minimum_size.y=88
 update_devices();restore(start_button)
 if count>0:audio.say("ready")
func update_devices() -> void:
 if game.paused and modal_title=="TAKE A BREATHER":
  show_pause.call_deferred();return
 if screen!="setup" or not is_instance_valid(start_button):return
 var valid:=true
 for slot in mini(player_status.size(),game.human_count):
  var p: LeoPlayerInput=game.input_router.players[slot]
  var description:="Keyboard · "+("WASD" if slot==0 else "Arrows") if p.kind=="keyboard" and game.human_count==2 and game.input_router.players[1-slot].kind=="keyboard" else "Keyboard · WASD / Arrows" if p.kind=="keyboard" else Input.get_joy_name(p.device) if p.device>=0 else "Reconnect your controller"
  var icon:=player_status[slot].get_parent().get_node("Icon") as TextureRect
  icon.texture=load("res://assets/ui/icons/"+("keyboard" if p.kind=="keyboard" else "wheel" if p.kind=="wheel" else "controller")+".svg")
  var problem: String=game.input_router.ready_problem(slot)
  player_status[slot].text=("Auto · " if p.preference=="auto" else "")+description+("\n"+problem if not problem.is_empty() else "\nReady to roll!")
  valid=valid and problem.is_empty()
 start_button.disabled=not valid;start_button.refresh()
func start_selected() -> void:
 if starting:return
 for slot in game.human_count:
  if not game.input_router.ready_problem(slot).is_empty():show_setup();audio.cue("unavailable");return
 starting=true;audio.say("race");setup.sync(game)
 game.save_settings()
 await game.start_race()
 starting=false
func open_garage(slot: int) -> void:
 setup.return_focus="Change Ride";game.selected_player_slot=slot
 game.input_router.gameplay_enabled=false;game.input_router.clear_all()
 hud.show_garage("setup" if screen=="setup" else "home")
func restore(default_control: Control) -> void:
 var wanted: String=last_focus.get(screen,"")
 for button in hud.menu_root.find_children("*","Button",true,false):
  if str(button.get_meta("focus_key",button.text))==wanted:button.grab_focus();return
 default_control.grab_focus()
func back_screen() -> void:
 if screen=="setup":game.return_menu()
 else:show_home()
func suspend_controls() -> void:
 suspended.clear()
 for parent in [hud.menu_root,hud.modal_root]:
  for control in parent.find_children("*","Control",true,false):
   if control.focus_mode!=Control.FOCUS_NONE:
    control.set_meta("ui_focus_mode",control.focus_mode);control.focus_mode=Control.FOCUS_NONE;suspended.append(control)
func resume_controls() -> void:
 for control in suspended:
  if is_instance_valid(control):control.focus_mode=int(control.get_meta("ui_focus_mode",Control.FOCUS_ALL))
 suspended.clear()
func dialog(title: String,subtitle: String,leave: Callable,width: float=760.) -> VBoxContainer:
 if hud.modal_root.get_child_count()==0:
  var focused:=get_viewport().gui_get_focus_owner()
  if focused:previous_focus=weakref(focused)
  suspend_controls()
 else:hud.clear(hud.modal_root)
 modal_back=leave;game.input_router.clear_all()
 audio.cue("open")
 modal_title=title
 hud.modal_root.theme=load("res://assets/ui/theme.tres")
 var shield:=Control.new();shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shield.mouse_filter=Control.MOUSE_FILTER_STOP;hud.modal_root.add_child(shield);hud.cover_viewport(shield)
 if RenderingServer.get_current_rendering_method()!="gl_compatibility":
  var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;shield.add_child(copy)
  var blur:=ColorRect.new();blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);var material:=ShaderMaterial.new();material.shader=load("res://shaders/ui_frost.gdshader");blur.material=material;blur.mouse_filter=Control.MOUSE_FILTER_IGNORE;shield.add_child(blur)
 var dim:=ColorRect.new();dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0.025,.04,.07,.65 if RenderingServer.get_current_rendering_method()!="gl_compatibility" else .93);dim.mouse_filter=Control.MOUSE_FILTER_IGNORE;shield.add_child(dim)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shield.add_child(center)
 var panel: PanelContainer=load("res://scenes/ui/ConfirmationDialog.tscn").instantiate();panel.custom_minimum_size.x=width;center.add_child(panel)
 var body:=panel.get_node("Scroll/Body") as VBoxContainer
 label(body,title,44)
 if not subtitle.is_empty():label(body,subtitle,24,Color("b9c7d6")).custom_minimum_size.x=width-48
 return body
func close_modal(restore_focus: bool=true) -> void:
 if not hud:return
 hud.clear(hud.modal_root);modal_back=Callable();modal_title="";game.input_router.controls_testing=false;game.input_router.cancel_capture()
 resume_controls()
 if restore_focus and previous_focus:
  var focused=previous_focus.get_ref()
  if is_instance_valid(focused):focused.grab_focus()
 update_devices()
func confirm(title: String,subtitle: String,yes: Callable,no: Callable) -> void:
 var box:=dialog(title,subtitle,no)
 action(box,"Keep Going" if game.paused else "Cancel",no).grab_focus()
 action(box,"Yes, "+("Restart" if title.contains("Restart") else "Leave" if title.contains("Leave") else "Quit"),func():close_modal(false);yes.call(),true)
func show_pause() -> void:
 pause_open=true;game.input_router.gameplay_enabled=false;game.input_router.clear_all()
 var box:=dialog("TAKE A BREATHER","Your race is right here.",func():game.toggle_pause())
 var keep:=action(box,"Keep Racing",func():game.toggle_pause(),true)
 keep.grab_focus()
 if not game.disconnect_message.is_empty():
  var connected:=true
  for slot in game.human_count:
   if not game.input_router.ready_problem(slot).is_empty():connected=false
  label(box,"All controls are connected. Choose Keep Racing." if connected else "Controller disconnected. Reconnect it or choose Controls.",24,Color("ffc857"))
  for slot in game.human_count:
   var index: int=slot
   if not game.input_router.ready_problem(slot).is_empty():
    action(box,"Player %d · Reconnect / Controls" % (slot+1),func():show_controls(index))
    action(box,"Retire Player %d" % (slot+1),func():confirm("Leave this race?","The other racer can keep going.",func():close_modal(false);game.retire_player(index);show_pause() if game.paused else close_modal(),show_pause))
 action(box,"Restart",func():confirm("Restart this race?","This race's progress will be lost.",func():await game.start_race(),show_pause))
 var row:=HBoxContainer.new();box.add_child(row)
 for slot in game.human_count:
  var index: int=slot
  action(row,"Change Ride"+(" · P%d" % (slot+1) if game.human_count==2 else ""),func():game.selected_player_slot=index;close_modal(false);hud.show_garage("pause"))
 action(box,"Settings",show_settings)
 action(box,"How to Play",show_guide)
 action(box,"Leave Race",func():confirm("Leave this race?","This race's progress will be lost.",game.return_menu,show_pause))
func show_settings() -> void:
 var leave: Callable=show_pause if game.paused else close_modal
 var box:=dialog("SETTINGS","Make it feel right.",leave,960)
 var scroll:=ScrollContainer.new();scroll.follow_focus=true;scroll.custom_minimum_size.y=420;box.add_child(scroll)
 var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
 add_slider(content,"Master volume",game.master_volume,game.set_volume)
 for bus in ["Music","Effects","UI","Voice"]:
  var name: String=bus
  add_slider(content,bus+" volume",float(audio.levels[bus]),func(value):audio.set_level(name,value))
 add_toggle(content,"Spoken cheers",audio.voice_enabled,audio.set_voice)
 add_toggle(content,"Fullscreen",DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,game.set_fullscreen)
 add_toggle(content,"Music",game.music_enabled,game.set_music)
 add_toggle(content,"Reduced Motion",game.reduced_motion,game.set_reduced_motion)
 action(box,"Back",leave).grab_focus()
func add_slider(parent: Node,words: String,value: float,changed: Callable) -> void:
 var row:=HBoxContainer.new();parent.add_child(row);label(row,words).custom_minimum_size.x=260
 var slider:=HSlider.new();slider.max_value=1.;slider.step=.01;slider.value=value;slider.custom_minimum_size=Vector2(400,42);slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(slider);slider.value_changed.connect(changed)
func add_toggle(parent: Node,words: String,value: bool,changed: Callable) -> void:
 var toggle:=CheckButton.new();toggle.text=words;toggle.button_pressed=value;toggle.custom_minimum_size.y=52;parent.add_child(toggle);toggle.toggled.connect(changed)
func show_guide() -> void:
 var leave: Callable=show_pause if game.paused else close_modal
 var box:=dialog("HOW TO PLAY","A little sideways. A lot faster.",leave,960)
 for item in [["Drive","Accelerate, brake, and steer."],["Drift","Hold Drift and steer. Release after the sparks for a boost."],["Nitro","Fill the meter, then press Nitro for a burst of speed."],["Recover","Stuck? Recover puts you back on the road."]]:
  label(box,item[0],28,Color("ffc857"));label(box,item[1],24)
 for slot in game.human_count:
  var p: LeoPlayerInput=game.input_router.players[slot]
  label(box,"P%d · Drift %s   ·   Nitro %s   ·   Recover %s" % [slot+1,p.describe("drift"),p.describe("boost"),p.describe("recover")],22,Color("43e7ef"))
 action(box,"Got It",leave,true).grab_focus()
func show_controls(slot: int=0) -> void:
 var leave: Callable=show_pause if game.paused else close_modal
 var box:=dialog("CONTROLS","Press a button. See it light up.",leave,1300)
 var panel:=LeoControlsPanel.new();panel.router=game.input_router;panel.slot=slot;panel.embedded=true;panel.custom_minimum_size=Vector2(1200,570);box.add_child(panel)
 panel.closed.connect(leave)
 game.input_router.controls_testing=true
func show_tracks() -> void:
 var box:=dialog("CHOOSE YOUR TRACK","Find your next favourite corner.",close_modal,1200)
 var scroll:=ScrollContainer.new();scroll.follow_focus=true;scroll.custom_minimum_size=Vector2(1100,440);box.add_child(scroll)
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
 for track in game.tracks:
  var course: LeoTrackDefinition=track
  var row: HBoxContainer=load("res://scenes/ui/TrackCard.tscn").instantiate();list.add_child(row)
  var path:="res://assets/ui/art/"+course.id+".png"
  if not ResourceLoader.exists(path):path="res://assets/ui/art/home.png"
  if course.metadata.has("preview") and LeoVehicleLibrary.safe_relative(String(course.metadata.preview)) and FileAccess.file_exists(course.folder.path_join(String(course.metadata.preview))):path=ProjectSettings.globalize_path(course.folder.path_join(String(course.metadata.preview)))
  picture(row,path,Vector2(260,145))
  var route:=LeoTrackHologram.new();route.reduced_motion=game.reduced_motion;var route_path:="res://assets/ui/icons/track_"+course.id+".svg"
  if ResourceLoader.exists(route_path):route.texture=load(route_path)
  elif FileAccess.file_exists(course.folder.path_join("route.svg")):route.texture=LeoAssets.texture(ProjectSettings.globalize_path(course.folder.path_join("route.svg")))
  route.custom_minimum_size=Vector2(140,130);route.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;route.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(route)
  var details:=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(details)
  action(details,("✓ " if course.id==game.chosen_track_id else "")+course.display_name,func():choose_track(course))
  label(details,"%.1f km · 3 laps · 6 racers" % (float(course.route.get("length",0.))/1000.),22,Color("b9c7d6"))
 label(box,"Map reference: © OpenStreetMap contributors / ODbL",20,Color("b9c7d6"))
 action(box,"Back",close_modal).grab_focus()
func choose_track(track: LeoTrackDefinition) -> void:
 if starting:return
 starting=true
 var was_setup:=screen=="setup"
 var count: int=game.human_count
 if await game.select_track(track.id):
  game.human_count=count
  if was_setup:show_setup()
  else:show_home()
 starting=false
func show_records() -> void:
 var box:=dialog("RECORDS","Your best races, all on this PC.",close_modal,1300)
 var panel:=LeoRankingsPanel.new();panel.game=game;panel.embedded=true;panel.custom_minimum_size=Vector2(1200,540);box.add_child(panel)
 panel.closed.connect(close_modal)
func show_results() -> void:
 close_modal(false);game.input_router.gameplay_enabled=false;screen="results";hud.scene_mode="results"
 audio.say("finish")
 var box:=shell("WHAT A RIDE!","Great race!");hud.scene_mode="results"
 for slot in game.human_count:
  var local: LeoLocalPlayer=game.local_players[slot];var kart:=local.kart
  label(box,"P%d · %s     %s     %s" % [slot+1,kart.racer_name,("#%d" % game.player_place(slot)) if kart.finished else "Didn't finish",game.format_time(kart.finish_time) if kart.finished else ""],36,Color("ffc857") if game.player_place(slot)==1 else Color("f5f7fa"))
  label(box,"Best lap · "+(game.format_time(local.best_lap) if local.best_lap<99999 else "—"),24)
 label(box,game.ranking_message.replace("OFFLINE RANKINGS","Records").replace("MODIFIED RACE / RECORDS NOT SAVED","Modded race · official records aren't saved."),22,Color("b9c7d6"))
 var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(spacer)
 action(box,"Race Again   →",start_selected,true).grab_focus()
 var row:=HBoxContainer.new();box.add_child(row);action(row,"Change Race",func():show_setup());action(row,"Home",game.return_menu)
func update_prompt() -> void:
 if is_instance_valid(prompt):prompt.text="D-pad / Stick   Move     A   Select     B   Back" if last_pad else "Arrows   Move     Enter   Select     Esc   Back"

func verify_preview() -> void:
 var errors: Array[String]=[]
 var results: Array[String]=[]
 for name in ["home","garage","astra_coast","colombo_city"]:
  if not ResourceLoader.exists("res://assets/ui/art/"+name+".png"):errors.append("Missing artwork: "+name)
 for path in [LeoLoadingBackdrops.DAY,LeoLoadingBackdrops.NIGHT]:
  if not ResourceLoader.exists(path):errors.append("Missing loading backdrop: "+path)
 for name in ["race","ready","choice","finish"]:
  if not ResourceLoader.exists("res://assets/audio/ui/voice_"+name+".wav"):errors.append("Missing voice: "+name)
 show_setup(2)
 await get_tree().process_frame
 if start_button.disabled:errors.append("Automatic two-player setup unavailable")
 results.append("Home and automatic two-player setup")
 show_settings();await get_tree().process_frame;close_modal()
 show_controls(1);await get_tree().process_frame;close_modal()
 show_tracks();await get_tree().process_frame;close_modal()
 results.append("Settings, controls and track picker")
 await start_selected()
 if not game.split_view.visible:errors.append("Split view unavailable")
 game.toggle_pause()
 if not game.paused:errors.append("Pause failed")
 game.toggle_pause()
 if game.paused:errors.append("Resume failed")
 results.append("Split race, pause and resume")
 game.return_menu();show_setup(1);await start_selected()
 if not is_instance_valid(hud.unified_hud):errors.append("Solo HUD unavailable")
 results.append("Solo race and unified HUD")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"checks":results,"version":"2.0.0"}
 var destination: String=game.diagnostic_path("ui-smoke.json")
 FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UI_PACKAGE_SMOKE ",JSON.stringify(report))
 await game.quit_game(0 if errors.is_empty() else 1)
func _input(event: InputEvent) -> void:
 if is_instance_valid(game.loading) and game.loading.visible:return
 if event is InputEventJoypadButton or event is InputEventJoypadMotion:last_pad=true;update_prompt()
 elif event is InputEventKey or event is InputEventMouseMotion:last_pad=false;update_prompt()
 if not game.input_router.pending_binding.is_empty():
  if event.is_action_pressed("ui_cancel"):
   game.input_router.resolve_conflict("cancel")
   var controls:=hud.modal_root.find_children("*","LeoControlsPanel",true,false)
   for panel in controls:panel.refresh()
   get_viewport().set_input_as_handled()
  return
 if game.input_router.capture_slot>=0:return
 if modal_title=="TAKE A BREATHER" and ((event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_P) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)):
  game.toggle_pause();get_viewport().set_input_as_handled();return
 if hud.scene_mode=="garage":return
 var active:=hud.menu_root.visible or hud.modal_root.get_child_count()>0
 if not active:return
 if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START and screen=="setup" and hud.modal_root.get_child_count()==0:
  if is_instance_valid(start_button) and not start_button.disabled:start_selected()
  get_viewport().set_input_as_handled();return
 if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE):
  if modal_back.is_valid():audio.cue("back");modal_back.call()
  elif screen!="home":audio.cue("back");back_screen()
  get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
 if hud.scene_mode=="garage" or (is_instance_valid(game.loading) and game.loading.visible):return
 var root: Control=hud.modal_root if hud.modal_root.get_child_count()>0 else hud.menu_root
 if not root.is_visible_in_tree():return
 var controls: Array[Control]=[]
 for candidate in root.find_children("*","Control",true,false):
  if candidate.is_visible_in_tree() and candidate.focus_mode==Control.FOCUS_ALL and not (candidate is BaseButton and candidate.disabled):controls.append(candidate)
 if controls.is_empty():return
 var signature:=""
 for control in controls:signature+=str(control.get_instance_id())+":"+str(control.get_global_rect())+";"
 if signature!=focus_graph:
  focus_graph=signature
  for i in controls.size():
   var control:=controls[i]
   var before:=controls[posmod(i-1,controls.size())];var after:=controls[(i+1)%controls.size()]
   control.focus_next=control.get_path_to(after);control.focus_previous=control.get_path_to(before)
   for direction in ["top","bottom","left","right"]:
    var best: Control=null;var score:=INF
    var origin:=control.get_global_rect().get_center()
    for candidate in controls:
     if candidate==control:continue
     var delta:=candidate.get_global_rect().get_center()-origin
     var along:=delta.x if direction=="right" else -delta.x if direction=="left" else delta.y if direction=="bottom" else -delta.y
     var across:=absf(delta.y) if direction in ["left","right"] else absf(delta.x)
     if along>1 and along+across*3<score:score=along+across*3;best=candidate
    control.set("focus_neighbor_"+direction,control.get_path_to(best if best else control))
 var focused:=get_viewport().gui_get_focus_owner()
 if not is_instance_valid(focused) or not root.is_ancestor_of(focused):controls[0].grab_focus()
