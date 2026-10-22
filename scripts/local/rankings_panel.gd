class_name LeoRankingsPanel
extends Control
var game: Node3D
var mode: OptionButton
var performance: OptionButton
var vehicle: OptionButton
var metric: OptionButton
var entries: VBoxContainer
var status: Label
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=load("res://assets/config/local_ui_theme.tres")
 var bg:=ColorRect.new();bg.color=Color("091423");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,45)
 add_child(margin)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",18);margin.add_child(box)
 var title:=Label.new();title.text="OFFLINE RANKINGS / COLOMBO COAST";title.add_theme_font_size_override("font_size",36);box.add_child(title)
 var filters:=HBoxContainer.new();filters.add_theme_constant_override("separation",16);box.add_child(filters)
 mode=OptionButton.new();mode.add_item("1 PLAYER",1);mode.add_item("2 PLAYERS",2);filters.add_child(mode)
 performance=OptionButton.new();performance.add_item("165 KM/H CLASS");performance.add_item("BIGSTER / 180 KM/H");filters.add_child(performance)
 vehicle=OptionButton.new();vehicle.add_item("ALL VEHICLES")
 for v in game.catalog.vehicles:vehicle.add_item(v.display_name)
 filters.add_child(vehicle)
 metric=OptionButton.new();metric.add_item("RACE TIME");metric.add_item("BEST LAP");filters.add_child(metric)
 for filter in [mode,performance,vehicle,metric]:filter.item_selected.connect(func(_i):refresh())
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
 entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
 var legacy:=Label.new();legacy.text="LEGACY v1.6 / PERSONAL BEST  %s  (previous rules; separate from these rankings)" % (game.format_time(game.legacy_best_time) if game.legacy_best_time>0 else "NO RECORD");box.add_child(legacy)
 var buttons:=HBoxContainer.new();box.add_child(buttons)
 var retry:=Button.new();retry.text="RETRY DATABASE";retry.pressed.connect(func():game.open_rankings();refresh());buttons.add_child(retry)
 var back:=Button.new();back.text="BACK";back.pressed.connect(queue_free);buttons.add_child(back);back.grab_focus()
 refresh()
func refresh() -> void:
 for child in entries.get_children():entries.remove_child(child);child.queue_free()
 var selected_vehicle: String="" if vehicle.selected==0 else String(game.catalog.vehicles[vehicle.selected-1].id)
 var rows: Array=[]
 if game.ranking_store:rows=game.ranking_store.best_times(mode.get_selected_id(),"standard165" if performance.selected==0 else "suv180",selected_vehicle,metric.selected==1)
 status.text="Best eligible result per player / balanced_v1 / three laps. DNF and car swaps excluded."
 if not game.ranking_store or not game.ranking_store.get_error().is_empty():
  status.text="Rankings unavailable. Racing remains available; existing data is retained. Use RETRY DATABASE."
 if rows.is_empty():
  var empty:=Label.new();empty.text="NO ELIGIBLE RESULTS FOR THESE FILTERS";entries.add_child(empty)
 for i in rows.size():
  var row: Dictionary=rows[i]
  var label:=Label.new();label.text="%02d   %-32s  %s   /   %s" % [i+1,row.name,game.format_time(float(row.lap_ms if metric.selected==1 else row.race_ms)/1000.),game.catalog.vehicle(StringName(row.vehicle)).display_name]
  label.add_theme_font_size_override("font_size",24);entries.add_child(label)
