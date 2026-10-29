class_name LeoRankingsPanel
extends Control
var game: Node3D
var track: OptionButton
var revision: OptionButton
var mode: OptionButton
var performance: OptionButton
var vehicle: OptionButton
var lap_count: SpinBox
var champion: HBoxContainer
var metric: OptionButton
var entries: VBoxContainer
var status: Label
signal closed
var embedded := false
var advanced := false
var query_generation := 0
func _exit_tree() -> void:query_generation+=1
var extra_filters: Array[Control]=[]
func _ready() -> void:
 if not embedded:set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=load("res://assets/ui/theme.tres")
 var bg:=ColorRect.new();bg.color=Color("101722");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 if embedded:bg.hide()
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,0 if embedded else 45)
 add_child(margin)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);margin.add_child(box)
 var title:=Label.new();title.text="HALL OF FAME / COLOMBO MOTOR CLUB";title.add_theme_font_size_override("font_size",28);box.add_child(title);title.hide()
 var filters:=HFlowContainer.new();filters.add_theme_constant_override("separation",16);box.add_child(filters)
 track=OptionButton.new()
 for i in game.tracks.size():
  var course: LeoTrackDefinition=game.tracks[i];track.add_item(course.display_name)
  if course.id==game.chosen_track_id:track.select(i)
 track.fit_to_longest_item=false;track.custom_minimum_size=Vector2(280,48);filters.add_child(track)
 revision=OptionButton.new();revision.add_item("Current course",0);revision.add_item("Kandy / original course archive",1);revision.fit_to_longest_item=false;revision.custom_minimum_size=Vector2(200,48);filters.add_child(revision)
 mode=OptionButton.new();mode.add_item("1 PLAYER",1);mode.add_item("2 PLAYERS",2);mode.custom_minimum_size=Vector2(160,48);filters.add_child(mode)
 mode.select(game.human_count-1)
 performance=OptionButton.new();performance.add_item("CURRENT VEHICLE BALANCE");performance.add_item("LEGACY / 165 KM/H");performance.add_item("LEGACY / BIGSTER");performance.add_item("LEGACY / DISTINCT V2");performance.add_item("LEGACY / DISTINCT V3");performance.add_item("LEGACY / DISTINCT V4");filters.add_child(performance)
 performance.add_item("2.6 / STATIC");performance.add_item("2.6 / DUSK TO NIGHT")
 performance.select(0)
 vehicle=OptionButton.new();vehicle.add_item("ALL VEHICLES")
 for v in game.catalog.vehicles:vehicle.add_item(v.display_name)
 filters.add_child(vehicle)
 metric=OptionButton.new();metric.add_item("RACE TIME");metric.add_item("BEST LAP");filters.add_child(metric)
 filters.add_child(Label.new());filters.get_child(-1).text="LAPS"
 lap_count=SpinBox.new();lap_count.min_value=1;lap_count.max_value=10;lap_count.step=1;lap_count.value=game.selected_laps;filters.add_child(lap_count)
 lap_count.value_changed.connect(func(_value):refresh())
 extra_filters=[performance,vehicle]
 for control in extra_filters:control.custom_minimum_size.y=48;control.hide()
 var more:=Button.new();more.text="More Filters";more.custom_minimum_size.y=48;more.pressed.connect(func():advanced=not advanced;more.text="Fewer Filters" if advanced else "More Filters";for_filter_visibility());more.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for filter in [track,revision,mode,performance,vehicle,metric]:filter.item_selected.connect(func(_i):refresh())
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
 champion=HBoxContainer.new();champion.custom_minimum_size.y=110;box.add_child(champion)
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
 entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
 var legacy:=Label.new();legacy.text="Complete the selected number of laps without changing rides to set a record.\nEarlier personal best: %s" % (game.format_time(game.legacy_best_time) if game.legacy_best_time>0 else "No record yet");legacy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;legacy.hide();box.add_child(legacy)
 var rules:=Button.new();rules.text="Record Rules";rules.custom_minimum_size.y=48;rules.pressed.connect(func():legacy.visible=not legacy.visible);rules.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var buttons:=HBoxContainer.new();box.add_child(buttons);buttons.add_child(more);buttons.add_child(rules)
 var retry:=Button.new();retry.text="RETRY DATABASE";retry.pressed.connect(func():game.open_rankings();refresh());buttons.add_child(retry)
 retry.name="Retry";retry.text="Try Again";retry.custom_minimum_size=Vector2(220,64)
 var back:=Button.new();back.text="Back";back.custom_minimum_size=Vector2(220,64);back.pressed.connect(close_panel);buttons.add_child(back);back.grab_focus()
 refresh()
func refresh() -> void:
 query_generation+=1
 var generation:=query_generation
 for child in entries.get_children():entries.remove_child(child);child.queue_free()
 var selected_vehicle: String="" if vehicle.selected==0 else String(game.catalog.vehicles[vehicle.selected-1].id)
 var rows: Array=[]
 var course: LeoTrackDefinition=game.tracks[track.selected]
 var course_revision: int=1 if course.id=="kandy_lake" and revision.selected==1 else course.revision
 revision.visible=course.id=="kandy_lake"
 var ruleset: String = game.current_ruleset(course) if performance.selected==0 else ("balanced_v1+arcade_elevation_v1" if course.elevated() else "balanced_v1")
 if performance.selected in [6,7]:ruleset=("distinct_v5_static" if performance.selected==6 else "distinct_v5_dusk_night")+("+arcade_elevation_v1" if course.elevated() else "")
 if performance.selected==5:ruleset="distinct_v4"+("+arcade_elevation_v1" if course.elevated() else "")
 if performance.selected==4:ruleset="distinct_v3"+("+arcade_elevation_v1" if course.elevated() else "")
 if performance.selected==3:ruleset="distinct_v2"+("+arcade_elevation_v1" if course.elevated() else "")
 var class_id := LeoRaceRules.CLASS if performance.selected in [0,3,4,5,6,7] else ("standard165" if performance.selected==1 else "suv180")
 status.text="Loading your records…"
 if game.ranking_store:rows=await LeoRankingRequests.query(game.ranking_store,get_tree(),mode.get_selected_id(),class_id,selected_vehicle,metric.selected==1,course.id,course_revision,ruleset,func():return is_inside_tree() and generation==query_generation,int(lap_count.value))
 if not is_inside_tree() or generation!=query_generation:return
 status.text="%s · %d LAPS · %s" % [course.display_name.to_upper(),int(lap_count.value),"BEST LAP" if metric.selected==1 else "RACE TIME"]
 update_champion(rows)
 var failed: bool=not game.ranking_store or not game.ranking_store.get_error().is_empty()
 var retry:=find_child("Retry",true,false) as Button
 if retry:retry.visible=failed
 if not game.ranking_store or not game.ranking_store.get_error().is_empty():
  status.text="We couldn't open your records. You can still race. Your earlier records are safe."
 if rows.is_empty():
  var empty:=Label.new();empty.text="No records yet. Finish a race to set your first time!";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;entries.add_child(empty)
 for i in rows.size():
  var row: Dictionary=rows[i]
  var panel:=PanelContainer.new();entries.add_child(panel)
  var style:=StyleBoxFlat.new();style.bg_color=Color("172334b0") if i%2==0 else Color("0c141f80");style.set_content_margin_all(8);style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
  var line:=HBoxContainer.new();line.add_theme_constant_override("separation",16);panel.add_child(line)
  var car:=game.catalog.vehicle(StringName(str(row.vehicle))) as VehicleDefinition
  if car:
   var thumbnail:=TextureRect.new();thumbnail.texture=LeoPreviewArt.texture(car);thumbnail.custom_minimum_size=Vector2(92,54);thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(thumbnail)
  var values: Array[String]=["%02d"%(i+1),str(row.name),game.format_time(float(row.lap_ms if metric.selected==1 else row.race_ms)/1000.),vehicle_label(String(row.vehicle))]
  for column in 4:
   var cell:=Label.new();cell.text=values[column];cell.tooltip_text=values[column];cell.add_theme_font_size_override("font_size",24);cell.custom_minimum_size=Vector2([44,220,160,240][column],48);cell.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;cell.clip_text=true
   if column in [1,3]:cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   line.add_child(cell)

func for_filter_visibility() -> void:
 for control in extra_filters:control.visible=advanced

func vehicle_label(key: String) -> String:
 var found: VehicleDefinition=game.catalog.vehicle(StringName(key))
 return LeoPreviewArt.name_for(found) if found else key

func close_panel() -> void:
 if embedded:closed.emit()
 else:queue_free()

func update_champion(rows: Array) -> void:
 for child in champion.get_children():champion.remove_child(child);child.queue_free()
 var trophy:=TextureRect.new();trophy.texture=load("res://assets/ui/art/ultra/winner.png");trophy.custom_minimum_size=Vector2(110,110);trophy.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;trophy.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;champion.add_child(trophy)
 var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL;champion.add_child(words)
 var heading:=Label.new();heading.text="TRACK CHAMPION" if not rows.is_empty() else "THE NEXT LEGEND COULD BE YOU";heading.add_theme_font_size_override("font_size",22);heading.modulate=Color("67d6db");words.add_child(heading)
 var winner:=Label.new();winner.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf"));winner.add_theme_font_size_override("font_size",38);winner.modulate=Color("ffc857");winner.text=str(rows[0].name) if not rows.is_empty() else "YOUR NAME BELONGS HERE";winner.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;winner.clip_text=true;winner.tooltip_text=winner.text;words.add_child(winner)
 var time:=Label.new();time.text=(game.format_time(float(rows[0].lap_ms if metric.selected==1 else rows[0].race_ms)/1000.)+"  /  "+vehicle_label(str(rows[0].vehicle))) if not rows.is_empty() else "Finish a clean race. Set the pace.";time.add_theme_font_size_override("font_size",24);time.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.add_child(time)
 if not game.reduced_motion and not rows.is_empty():
  var reveal:=champion.create_tween();champion.modulate.a=0.;reveal.tween_property(champion,"modulate:a",1.,.24)
  var sheen:=winner.create_tween().set_loops();sheen.tween_interval(4.);sheen.tween_property(winner,"modulate",Color("fff3cc"),.5);sheen.tween_property(winner,"modulate",Color("ffc857"),.8)
