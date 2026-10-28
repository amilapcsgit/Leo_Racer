class_name LeoRankingsPanel
extends Control
var game: Node3D
var track: OptionButton
var revision: OptionButton
var mode: OptionButton
var performance: OptionButton
var vehicle: OptionButton
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
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",18);margin.add_child(box)
 var title:=Label.new();title.text="Your best races";title.add_theme_font_size_override("font_size",28);box.add_child(title)
 var filters:=HFlowContainer.new();filters.add_theme_constant_override("separation",16);box.add_child(filters)
 track=OptionButton.new()
 for i in game.tracks.size():
  var course: LeoTrackDefinition=game.tracks[i];track.add_item(course.display_name)
  if course.id==game.chosen_track_id:track.select(i)
 filters.add_child(track)
 revision=OptionButton.new();revision.add_item("Current course",0);revision.add_item("Kandy / original course archive",1);filters.add_child(revision)
 mode=OptionButton.new();mode.add_item("1 PLAYER",1);mode.add_item("2 PLAYERS",2);filters.add_child(mode)
 mode.select(game.human_count-1)
 performance=OptionButton.new();performance.add_item("CURRENT VEHICLE BALANCE");performance.add_item("LEGACY / 165 KM/H");performance.add_item("LEGACY / BIGSTER");performance.add_item("LEGACY / DISTINCT V2");performance.add_item("LEGACY / DISTINCT V3");performance.add_item("LEGACY / DISTINCT V4");filters.add_child(performance)
 performance.select(0)
 vehicle=OptionButton.new();vehicle.add_item("ALL VEHICLES")
 for v in game.catalog.vehicles:vehicle.add_item(v.display_name)
 filters.add_child(vehicle)
 metric=OptionButton.new();metric.add_item("RACE TIME");metric.add_item("BEST LAP");filters.add_child(metric)
 extra_filters=[performance,vehicle,metric]
 for control in extra_filters:control.hide()
 var more:=Button.new();more.text="More Filters";more.pressed.connect(func():advanced=not advanced;more.text="Fewer Filters" if advanced else "More Filters";for_filter_visibility());box.add_child(more)
 for filter in [track,revision,mode,performance,vehicle,metric]:filter.item_selected.connect(func(_i):refresh())
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
 entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
 var legacy:=Label.new();legacy.text="Complete three laps without changing rides to set a record.\nEarlier personal best: %s" % (game.format_time(game.legacy_best_time) if game.legacy_best_time>0 else "No record yet");legacy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;legacy.hide();box.add_child(legacy)
 var rules:=Button.new();rules.text="Record Rules";rules.pressed.connect(func():legacy.visible=not legacy.visible);box.add_child(rules)
 var buttons:=HBoxContainer.new();box.add_child(buttons)
 var retry:=Button.new();retry.text="RETRY DATABASE";retry.pressed.connect(func():game.open_rankings();refresh());buttons.add_child(retry)
 retry.name="Retry";retry.text="Try Again";retry.custom_minimum_size=Vector2(220,64)
 var back:=Button.new();back.text="Back";back.custom_minimum_size=Vector2(220,64);back.pressed.connect(func():closed.emit() if embedded else queue_free());buttons.add_child(back);back.grab_focus()
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
 if performance.selected==5:ruleset="distinct_v4"+("+arcade_elevation_v1" if course.elevated() else "")
 if performance.selected==4:ruleset="distinct_v3"+("+arcade_elevation_v1" if course.elevated() else "")
 if performance.selected==3:ruleset="distinct_v2"+("+arcade_elevation_v1" if course.elevated() else "")
 var class_id := LeoRaceRules.CLASS if performance.selected in [0,3,4,5] else ("standard165" if performance.selected==1 else "suv180")
 status.text="Loading your records…"
 if game.ranking_store:rows=await LeoRankingRequests.query(game.ranking_store,get_tree(),mode.get_selected_id(),class_id,selected_vehicle,metric.selected==1,course.id,course_revision,ruleset,func():return is_inside_tree() and generation==query_generation)
 if not is_inside_tree() or generation!=query_generation:return
 status.text="Best time for each racer. Can you beat yours?"
 var failed: bool=not game.ranking_store or not game.ranking_store.get_error().is_empty()
 var retry:=find_child("Retry",true,false) as Button
 if retry:retry.visible=failed
 if not game.ranking_store or not game.ranking_store.get_error().is_empty():
  status.text="We couldn't open your records. You can still race. Your earlier records are safe."
 if rows.is_empty():
  var empty:=Label.new();empty.text="No records yet. Finish a race to set your first time!";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;entries.add_child(empty)
 for i in rows.size():
  var row: Dictionary=rows[i]
  var label:=Label.new();label.text="%02d   %-32s  %s   /   %s" % [i+1,row.name,game.format_time(float(row.lap_ms if metric.selected==1 else row.race_ms)/1000.),vehicle_label(String(row.vehicle))]
  label.add_theme_font_size_override("font_size",24);entries.add_child(label)

func for_filter_visibility() -> void:
 for control in extra_filters:control.visible=advanced

func vehicle_label(key: String) -> String:
 var found: VehicleDefinition=game.catalog.vehicle(StringName(key))
 return found.display_name if found else key
