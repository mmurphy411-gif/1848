extends Node
## Retain the claim off-tree: no terrain rebuild, no lost camp work or fish.
const Layout=preload("res://scripts/claim_layout.gd")
var claim: Node3D
var shop: Node3D
var trail := Vector3.ZERO
var departure_hour := 7.0
var travelling := false
var fade := ColorRect.new()
var rim := Camera3D.new()
func _ready() -> void:
	var layer:=CanvasLayer.new();layer.layer=30;add_child(layer);layer.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.color=Color(0,0,0,0)
func configure(node: Node3D) -> void:
	claim=node;trail=claim.get_node("Camp").position+Vector3(0,0,6);trail.y=Layout.height_at(trail.x,trail.z)+.03
func eligible() -> bool:
	if travelling or not is_instance_valid(claim) or is_instance_valid(shop): return false
	return claim.get_node("Daylight/Clock").hour_at(claim.get_node("Daylight/Clock").elapsed)<=9 and claim.get_node("Activities").idle()
func at_trail() -> bool:
	if not is_instance_valid(claim) or not claim.is_inside_tree(): return false
	var walker: Node3D=claim.get_node("Walker")
	var d:=trail-walker.position;d.y=0
	return d.length()<1.5 and (-walker.get_node("Visual").global_basis.z).dot(d.normalized())>0
func prompt() -> String:
	return "Set out for %s's · a day" % preload("res://scripts/store.gd").KEEPER if eligible() else "Too late to be back by dark"
func _input(event: InputEvent) -> void:
	if travelling:
		if event is InputEventKey or event is InputEventMouseButton: get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not event.is_echo() and at_trail() and claim.get_node("Activities").idle():
		get_viewport().set_input_as_handled()
		if eligible(): depart()
func fade_to(alpha: float) -> void:
	await create_tween().tween_property(fade,"color:a",alpha,1.0).finished
func rim_shot(hour: float) -> void:
	claim.get_node("Daylight").apply(hour)
	if rim.get_parent()==null: claim.add_child(rim)
	rim.position=Vector3(12,28,40);rim.look_at(Vector3(0,2,0));rim.fov=44;rim.make_current()
	claim.get_node("Soundscape").trip_bed(true)
	await fade_to(0)
	await get_tree().create_timer(4).timeout
	await fade_to(1)
	claim.get_node("Soundscape").trip_bed(false)
func trail_meal() -> bool:
	var game: Node=get_node("/root/GameState")
	for i in game.inventory.fish.size():
		var food: Dictionary=game.inventory.fish[i]
		if food.state=="smoked" or food.get("cooked",false):
			game.inventory.fish.remove_at(i);game.eat(food.state=="smoked");game.event("Ate on the trail.");return true
	return false
func depart(debug := false) -> void:
	if travelling or is_instance_valid(shop) or not is_instance_valid(claim): return
	if not debug and not eligible(): return
	travelling=true
	var clock: Node=claim.get_node("Daylight/Clock")
	departure_hour=clock.hour_at(clock.elapsed)
	clock.running=false
	claim.get_node("Walker").set_physics_process(false)
	claim.get_node("Walker").velocity=Vector3.ZERO
	if not debug:
		await fade_to(1);await rim_shot(departure_hour)
	trail_meal()
	var game: Node=get_node("/root/GameState")
	game.check_midday(departure_hour+6,false)
	claim.get_node("Soundscape").stop();claim.get_node("Camp").fire_sound.stop();claim.get_node("Rain").sound.stop()
	if get_tree().root.close_requested.is_connected(claim.request_quit): get_tree().root.close_requested.disconnect(claim.request_quit)
	get_tree().root.remove_child(claim)
	game.scene="store";game.start_hour=fposmod(departure_hour+6,24)
	shop=load("res://scenes/store.tscn").instantiate();get_tree().root.add_child(shop);get_tree().current_scene=shop
	if not debug: await fade_to(0)
	travelling=false
func home(debug := false) -> void:
	if travelling or not is_instance_valid(shop): return
	travelling=true
	shop.finish_pour();shop.counter.abandon()
	var game: Node=get_node("/root/GameState")
	game.ledger.append(shop.counter.visit.duplicate(true))
	if not debug: await fade_to(1)
	shop.get_node("Soundscape").stop();shop.get_node("Rain").sound.stop()
	get_tree().root.remove_child(shop);shop.queue_free();shop=null
	get_tree().root.add_child(claim);get_tree().current_scene=claim
	if not get_tree().root.close_requested.is_connected(claim.request_quit): get_tree().root.close_requested.connect(claim.request_quit)
	get_node("/root/Sack").changed.emit(get_node("/root/Sack").ounces)
	game.scene="claim"
	var camp: Node=claim.get_node("Camp")
	# No unattended smoking progress. Travel only burns down fuel and embers.
	camp.fire_hours=maxf(0,camp.fire_hours-12);camp.ember_hours=0;camp.flame.emitting=false;camp.smoke.emitting=false
	camp.flame.restart();camp.smoke.restart()
	var hour:=fposmod(departure_hour+12,24)
	if departure_hour+12>=24: game.end_day()
	game.start_hour=hour
	claim.get_node("Soundscape").start()
	if not debug: await rim_shot(hour)
	claim.get_node("Walker").position=trail-Vector3(0,0,1)
	claim.get_node("Walker").set_physics_process(true)
	claim.get_node("CameraRig/SpringArm3D/Camera3D").make_current()
	claim.get_node("Daylight/Clock").start(hour);camp.last_hour=hour
	if claim.has_node("Crew"): claim.get_node("Crew").settle()
	game.event("Home at dusk.")
	if not debug: await fade_to(0)
	travelling=false
func _exit_tree() -> void:
	if is_instance_valid(claim) and claim.get_parent()==null: claim.free()
	if is_instance_valid(rim) and rim.get_parent()==null: rim.free()
