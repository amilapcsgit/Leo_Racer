extends VBoxContainer
## Shared by the in-game Workshop; edits portable data, never the source model.
var host: LeoVehicleSetup
var nodes: Array[String] = []
var materials: Dictionary = {}
var animations: Dictionary = {}
var lamp_index := 0
var selected_node := ""
var selected_material := ""

func configure(setup: LeoVehicleSetup) -> void:
	host=setup
	var model := host.source_scene.instantiate() as Node3D
	for child in model.find_children("*","Node",true,false):
		var path := String(model.get_path_to(child))
		if child is Node3D:nodes.append(path)
		if child is MeshInstance3D and child.mesh:
			materials[path]=[]
			for i in child.mesh.get_surface_count():
				var material: Material=child.get_active_material(i)
				if material:materials[path].append(material.resource_name)
		if child is AnimationPlayer:animations[path]=Array(child.get_animation_list())
	model.free();build()

func choose(parent: Node,values: Array,current: String,changed: Callable) -> OptionButton:
	var select := OptionButton.new();select.fit_to_longest_item=false;select.clip_text=true;select.custom_minimum_size.x=300;select.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(select)
	for value in values:select.add_item(String(value))
	var index := values.find(current)
	if index>=0:select.select(index)
	select.item_selected.connect(func(i):changed.call(String(values[i])))
	return select

func commit(rebuild: bool=false) -> void:
	host.data.core.min="2.3.2";host.changed()
	if rebuild:build.call_deferred()

func preview_lamps(brake: bool,reverse: bool) -> void:
	if not is_instance_valid(host.preview):return
	var feature := host.preview.chassis.get_node_or_null("VehicleLighting")
	if feature:
		feature.update_state(brake,reverse)
		host.status.text="Lamp preview · "+("; ".join(feature.diagnostics) if not feature.diagnostics.is_empty() else "targets resolved")

func build() -> void:
	for child in get_children():remove_child(child);child.queue_free()
	if not host.data.has("lighting"):host.data.lighting=[]
	if not host.data.has("actions"):host.data.actions=[]
	host.label(self,"LIGHTS AND VEHICLE ACTIONS").add_theme_font_size_override("font_size",24)
	var row := HBoxContainer.new();add_child(row)
	host.button(row,"Brake preview",func():preview_lamps(true,false))
	host.button(row,"Reverse preview",func():preview_lamps(false,true))
	host.button(self,"Toggle headlamps",func():
		if is_instance_valid(host.preview):
			var feature := host.preview.chassis.get_node_or_null("VehicleLighting")
			if feature:feature.toggle_headlights())
	var labels: Array=[]
	for i in host.data.lighting.size():labels.append("%d · %s" % [i+1,host.data.lighting[i].role])
	if not labels.is_empty():choose(self,labels,String(labels[clampi(lamp_index,0,labels.size()-1)]),func(value):lamp_index=labels.find(value);build())
	row=HBoxContainer.new();add_child(row)
	host.button(row,"Add lamp group",func():
		if host.data.lighting.size()>=16:return
		host.data.lighting.append({"role":"brake","targets":[]});lamp_index=host.data.lighting.size()-1;commit(true))
	host.button(row,"Remove lamp",func():
		if host.data.lighting.is_empty():return
		host.data.lighting.remove_at(clampi(lamp_index,0,host.data.lighting.size()-1));lamp_index=0;commit(true))
	if not host.data.lighting.is_empty():
		lamp_index=clampi(lamp_index,0,host.data.lighting.size()-1)
		var lamp: Dictionary=host.data.lighting[lamp_index]
		choose(self,["head","tail","brake","reverse"],lamp.role,func(value):lamp.role=value;commit())
		host.label(self,"Lamp surfaces: "+JSON.stringify(lamp.get("targets",[])))
		var mesh_paths: Array=materials.keys()
		if not mesh_paths.is_empty():
			if not materials.has(selected_node):selected_node=String(mesh_paths[0])
			choose(self,mesh_paths,selected_node,func(value):selected_node=value;selected_material="";build())
			var names: Array=materials[selected_node]
			if not names.is_empty():
				if selected_material not in names:selected_material=String(names[0])
				choose(self,names,selected_material,func(value):selected_material=value)
				host.button(self,"Bind this surface",func():
					var target:={"node":selected_node,"material":selected_material}
					if not target in lamp.targets:lamp.targets.append(target)
					commit(true))
			host.button(self,"Clear surface bindings",func():lamp.targets=[];commit(true))
		var projected := CheckButton.new();projected.text="Projected lamp / glow";projected.button_pressed=lamp.has("anchor");add_child(projected)
		projected.toggled.connect(func(on):
			if on:lamp.anchor=[0,1,0]
			else:lamp.erase("anchor")
			commit(true))
		if lamp.has("anchor"):
			host.vector_field(self,"Anchor in model space",lamp.anchor,func(value):lamp.anchor=value;commit())
			if lamp.role=="head":host.vector_field(self,"Beam rotation degrees",lamp.get("rotation",[-5,0,0]),func(value):lamp.rotation=value;commit())
			host.label(self,"Range (m) / energy")
			host.number(self,float(lamp.get("range",2)),func(value):lamp.range=value;commit(),.1,40)
			host.number(self,float(lamp.get("energy",.8)),func(value):lamp.energy=value;commit(),0,8)
	for slot in [1,2]:
		var action: Dictionary={}
		for entry in host.data.actions:
			if int(entry.slot)==slot:action=entry
		host.label(self,"Vehicle Action %d" % slot).add_theme_font_size_override("font_size",22)
		if action.is_empty():
			var action_slot: int=slot
			host.button(self,"Assign Action %d" % slot,func():
				if nodes.is_empty():return
				host.data.actions.append({"slot":action_slot,"name":"Vehicle feature","type":"transform","duration":1.2,"targets":[{"node":nodes[0],"open_position":[0,0,0]}]});commit(true))
			continue
		var current: Dictionary=action
		var name_edit := LineEdit.new();name_edit.text=current.name;add_child(name_edit)
		name_edit.text_changed.connect(func(value):current.name=value;commit())
		host.button(self,"Remove action",func():host.data.actions.erase(current);commit(true))
		choose(self,["transform","animation"],current.get("type","transform"),func(value):
			current.type=value
			if value=="transform" and not current.has("targets"):current.targets=[{"node":nodes[0],"open_position":[0,0,0]}]
			if value=="animation":current.player="";current.clip=""
			commit(true))
		host.label(self,"Transition duration (seconds)");host.number(self,float(current.get("duration",1.2)),func(value):current.duration=value;commit(),.1,10)
		if current.get("type","transform")=="animation":
			if animations.is_empty():host.label(self,"This model contains no AnimationPlayer clips.");continue
			var players: Array=animations.keys()
			if not animations.has(current.get("player","")):current.player=players[0]
			choose(self,players,current.player,func(value):current.player=value;current.clip="";commit(true))
			var clips: Array=animations[current.player]
			if not clips.is_empty():
				if current.get("clip","") not in clips:current.clip=clips[0]
				choose(self,clips,current.clip,func(value):current.clip=value;commit())
		else:
			for target in current.targets:
				var pose: Dictionary=target
				choose(self,nodes,pose.node,func(value):pose.node=value;commit())
				for key in ["closed_position","open_position","closed_rotation","open_rotation"]:
					var field: String=key
					host.vector_field(self,key.replace("_"," "),pose.get(key,[0,0,0]),func(value):pose[field]=value;commit())
		var preview_slot: int=slot
		host.button(self,"Preview open / close",func():
			if is_instance_valid(host.preview):
				var feature := host.preview.chassis.get_node_or_null("VehicleLighting")
				if feature:feature.trigger(preview_slot))
