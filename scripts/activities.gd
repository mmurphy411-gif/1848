extends Node
var busy := false
var timer := 0.0
var action := ""
var item := ""
var cooking_menu := false
var sleep_phase := 0
var work_from := Vector3.ZERO
var work_elapsed := 0.0
var fade := ColorRect.new()
@onready var walker: CharacterBody3D=get_parent().get_node("Walker")
@onready var camp: Node3D=get_parent().get_node("Camp")
@onready var bait: Node=get_parent().get_node("BaitSources")
@onready var hud: CanvasLayer=get_parent().get_node("HUD")
@onready var clock: Node=get_parent().get_node("Daylight/Clock")
func _ready() -> void:
	var layer := CanvasLayer.new();layer.layer=20;add_child(layer);layer.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.color=Color(0,0,0,0)
func ui_open() -> bool:
	for name in ["Ledger","Sandbox"]:
		var ui := get_parent().get_node_or_null(name)
		if ui and ui.opened: return true
	return false
func idle() -> bool: return not busy and walker.panner.state==0 and walker.get_node("Fisher").state==0 and not ui_open()
func _unhandled_input(event: InputEvent) -> void:
	if cooking_menu and event.is_action_pressed("ui_cancel"):
		cooking_menu=false;hud.notify("",0);get_viewport().set_input_as_handled();return
	if cooking_menu and event.is_action_pressed("fish"):
		cooking_menu=false
		if camp.fry(): start("cook","cook",999)
		get_viewport().set_input_as_handled();return
	if not event.is_action_pressed("interact") or event.is_echo() or not idle(): return
	var target: String=camp.target(walker)
	match target:
		"FireRing":
			if get_node("/root/GameState").inventory.firewood<(1 if camp.burning() else 3): hud.notify("Need 3 driftwood")
			else: start("fire","tend_fire",2)
		"Skillet":
			if camp.eat_stored(): start("eat","eat",3)
			elif camp.burning() and camp.fresh_index()>=0: cooking_menu=true;hud.notify("Fry fish   ·   F / Y",30)
			else: hud.notify("No fresh fish" if camp.fresh_index()<0 else "Light the fire first")
		"Rack": hud.notify("Fish hung" if camp.hang() else "Need fresh fish and a burning fire")
		"Cache": camp.swap_cache()
		"Bedroll": sleep()
		"Crate": get_parent().get_node("Ledger").open_book()
		_:
			if camp.eat_stored(): start("eat","eat",3)
			else:
				item=bait.eligible(walker.position,clock.hour_at(clock.elapsed))
				if item!="": start("gather","gather",2)
	get_viewport().set_input_as_handled()
func start(kind: String,clip: String,seconds: float) -> void:
	if action=="eat": camp.restore_skillet()
	busy=true;action=kind;timer=seconds
	hud.notify("",0)
	if kind=="eat":
		camp.props.Skillet.hide();camp.props.Skillet.collision_layer=0
	if kind in ["cook","fire"]:
		work_from=walker.global_position;work_elapsed=0
		walker.velocity=Vector3.ZERO
		walker.get_node("Visual").turn_to(PI)
	walker.get_node("Visual").play_activity(clip)
func holds_at_fire() -> bool: return busy and action in ["cook","fire"]
func _physics_process(delta: float) -> void:
	if not holds_at_fire(): return
	work_elapsed+=delta
	walker.global_position=work_from.lerp(camp.work_position(),smoothstep(0, .45,work_elapsed))
	walker.velocity=Vector3.ZERO
func sleep() -> void:
	if not idle(): return
	sleep_phase=0
	start("sleep","lie_down",1.5)
func finish_cooking() -> void:
	if action=="cook": start("eat","eat",3)
func _process(delta: float) -> void:
	if not busy: return
	timer-=delta
	if action=="sleep": fade.color.a=clampf(1-timer/1.5,0,1) if sleep_phase==0 else clampf(timer/1.5,0,1)
	if timer>0: return
	if action=="sleep" and sleep_phase==0:
		clock.end_day()
		walker.global_position=camp.wake_position()
		walker.velocity=Vector3.ZERO
		sleep_phase=1;timer=1.5
		walker.get_node("Visual").stop_activity()
		return
	if action=="fire": camp.light_fire()
	elif action=="gather": hud.notify("Gathered "+item if bait.gather(item) else "Nothing this time")
	elif action=="eat": camp.restore_skillet()
	fade.color.a=0;busy=false;action=""
	walker.get_node("Visual").stop_activity()
