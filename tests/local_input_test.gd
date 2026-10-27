extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool, text: String) -> void:
 checks+=1
 if not ok:failures.append(text);push_error(text)
func axis(id: int,index: int,value: float) -> InputEventJoypadMotion:
 var e:=InputEventJoypadMotion.new();e.device=id;e.axis=index;e.axis_value=value;return e
func key(code: Key, pressed: bool=true) -> InputEventKey:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=pressed;return e
func run() -> void:
 var router:=LeoInputRouter.new();router.settings_path="user://test-local-input.cfg";root.add_child(router);router.active_slots=2
 router.players[0].reset_defaults("keyboard");router.players[1].reset_defaults("gamepad")
 check(router.assign(1,"gamepad",18,false),"Assign second controller")
 router.feed(key(KEY_W));check(router.players[0].value("accelerate")==1. and router.players[1].value("accelerate")==0.,"Keyboard isolation")
 check(router.assign(1,"keyboard",-1,false),"Shared keyboard assignment is allowed")
 router.assign(1,"gamepad",18,false)
 check(router.assign(0,"gamepad",17,false),"First controller assignment")
 check(router.assign(1,"gamepad",17,false) and router.players[0].device!=17,"Occupied device transfers ownership without duplicates")
 router.assign(1,"gamepad",18,false);router.assign(0,"gamepad",17,false)
 router.feed(axis(17,JOY_AXIS_LEFT_X,.9));check(router.players[0].steering()>.8 and router.players[1].steering()==0.,"P1 steering isolation")
 router.feed(axis(18,JOY_AXIS_TRIGGER_RIGHT,.8));check(router.players[1].throttle()>.7 and router.players[0].throttle()==0.,"P2 throttle isolation")
 router.feed(axis(19,JOY_AXIS_TRIGGER_RIGHT,1.));check(router.players[0].throttle()==0.,"Unassigned pad ignored")
 router.feed(key(KEY_W));check(router.players[0].throttle()==0.,"Keyboard cannot drive controller-owned player")
 var p:=router.players[1];p.reset_defaults("wheel");p.device=18
 p.set_axis("left",0,.1,-.8,.03);p.set_axis("right",0,.1,.9,.03)
 p.set_axis("accelerate",2,0.,1.);p.set_axis("brake",2,0.,-1.)
 router.feed(axis(18,0,.1));check(absf(p.steering())<.001,"Wheel centered")
 router.feed(axis(18,0,-.8));check(is_equal_approx(p.steering(),-1.),"Wheel left range")
 router.feed(axis(18,0,.9));check(is_equal_approx(p.steering(),1.),"Wheel right range")
 router.feed(axis(18,2,1.));check(p.throttle()==1.,"Combined throttle")
 router.feed(axis(18,2,-1.));check(p.throttle()==-1.,"Combined brake")
 p.set_axis("accelerate",3,1.,-1.)
 router.feed(axis(18,3,1.));check(p.value("accelerate")==0.,"Inverted pedal rest")
 router.feed(axis(18,3,-1.));check(p.value("accelerate")==1.,"Inverted pedal full")
 check(not p.set_axis("accelerate",3,0.,.01),"Reject zero calibration range")
 var e:=InputEventJoypadButton.new();e.device=18;e.button_index=JOY_BUTTON_X;e.pressed=true
 router.feed(e);check(p.consume("boost") and not p.consume("boost"),"One-shot button")
 router.feed(e);check(not p.consume("boost"),"Held button does not repeat")
 check(router.save_profiles()==OK,"Save profiles")
 var snapshot:=p.serialize();p.reset_defaults("gamepad");router.load_profiles()
 check(router.players[1].serialize()==snapshot,"Bindings persist after reload")
 check(router.players[1].device==-1,"Runtime device IDs are not persisted")
 router.assign(0,"gamepad",17,false);router.feed(axis(17,0,1.));router._connection(17,false)
 check(router.players[0].device==-1 and router.players[0].steering()==0.,"Disconnect clears and unassigns")
 router.players[0].kind="gamepad";router.players[1].kind="gamepad"
 var twin:={"guid":"same-guid","name":"Xbox Controller","serial":""}
 router.players[0].identity=twin;router.players[1].identity=twin
 router.restore_assignments([7],{7:twin})
 check(router.players[0].device==-1 and router.players[1].device==-1,"Lone identical controller requires explicit owner confirmation")
 router.restore_assignments([7,8],{7:twin,8:twin})
 check(router.players[0].device==-1 and router.players[1].device==-1,"Identical controllers never silently exchange players")
 router.players[1].identity={"guid":"wheel","name":"Formula Force EX","serial":"123"}
 router.restore_assignments([7,9],{7:twin,9:router.players[1].identity})
 check(router.players[0].device==7 and router.players[1].device==9,"Distinct saved devices restore independent ownership")
 router.clear_all();check(router.players[1].throttle()==0.,"Clear cannot leave pedal held")
 router.players[0].reset_defaults("keyboard");router.players[0].device=-1
 router.start_capture(0,"horn");router._capture(key(KEY_J))
 check(router.players[0].bindings.horn[0].index==KEY_J and router.capture_slot==-1,"Keyboard remap captures the actual key")
 router.feed(key(KEY_H));check(not router.players[0].consume("horn"),"Old binding is no longer active")
 router.feed(key(KEY_J));check(router.players[0].consume("horn"),"New binding activates the action")
 router.players[1].reset_defaults("wheel");router.players[1].device=18
 router.start_capture(1,"accelerate");router._capture(axis(17,5,-.9))
 check(router.capture_slot==1,"Wrong device cannot bind another player's action")
 router._capture(axis(18,5,-.9))
 check(router.players[1].bindings.accelerate[0].index==5 and router.players[1].bindings.accelerate[0].pressed<-.8,"Wheel learns actual pedal axis and direction")
 router.start_capture(1,"brake");router._capture(key(KEY_ESCAPE))
 check(router.capture_slot==-1 and router.players[1].value("accelerate")==0.,"Escape cancels capture and clears held inputs")
 var panel:=LeoControlsPanel.new();panel.router=router;root.add_child(panel);await process_frame
 check(panel.live.size()==LeoPlayerInput.ACTIONS.size(),"Controls expose every driving action")
 panel.slot=1;panel.refresh();check(panel.live.size()==LeoPlayerInput.ACTIONS.size(),"Second-player controls are editable")
 panel.free()
 var report:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"errors":failures,"physical_wheel":"unverified / hardware unavailable"}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa-ui"))
 FileAccess.open("res://build/qa-ui/input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LOCAL_INPUT_TEST ",report)
 router.free();quit(0 if failures.is_empty() else 1)
