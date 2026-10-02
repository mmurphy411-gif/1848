extends SceneTree
const Pack=preload("res://scripts/pack.gd")
const Prices=preload("res://scripts/prices.gd")
const Stock=preload("res://scripts/store_stock.gd")
const Cooking=preload("res://scripts/cooking.gd")
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: errors.append(message);push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node=root.get_node("GameState");var sack: Node=root.get_node("Sack");var trip: Node=root.get_node("Trip")
	check(game.inventory.goods.salt==2,"starting salt")
	check(is_equal_approx(Pack.weight({"goods":{"flour":20},"rod":true,"line_m":40,"hooks":6}),21.9),"pack accounting")
	game.apply_scenario({"day":30,"hour":7,"goods.flour":20,"rod":1,"scene":"claim"})
	check(game.inventory.goods.flour==20 and game.inventory.rod,"goods and rod scenario")
	game.inventory.goods.flour=0;game.inventory.rod=false;game.dollars=0;sack.ounces=3
	game.inventory.fish=[{"species":"trout","state":"smoked","weight_lb":1.0,"day":30}]
	var claim: Node=load("res://scenes/claim.tscn").instantiate();root.add_child(claim);current_scene=claim
	await process_frame;await process_frame
	var clock: Node=claim.get_node("Daylight/Clock")
	clock.start(8.983);check(trip.eligible(),"08:59 eligible")
	clock.start(9.017);check(not trip.eligible(),"09:01 too late")
	clock.start(7)
	claim.get_node("Activities").busy=true;check(not trip.eligible(),"busy camp blocks trip");claim.get_node("Activities").busy=false
	claim.get_node("Walker/Panner").state=1;check(not trip.eligible(),"panning blocks trip");claim.get_node("Walker/Panner").state=0
	claim.get_node("Walker/Fisher").state=1;check(not trip.eligible(),"fishing stance blocks trip");claim.get_node("Walker/Fisher").state=0
	await trip.depart(true)
	var store: Node=trip.shop;store.set_physics_process(false)
	check(game.scene=="store" and store.get_node("Daylight/Clock").running==false,"store paused")
	check(is_equal_approx(store.get_node("Daylight").current_hour,13),"arrival light 13")
	check(game.inventory.meals_today==1 and game.inventory.fish.is_empty(),"trail meal consumed")
	check(game.inventory.journal.any(func(e):return e.text=="Ate on the trail."),"trail journal")
	check(sack.ounces==3 and game.dollars==0,"sack and coin survive swap")
	check(store.board.text.contains("GOLD") and store.board.text.contains("$%.2f" % Prices.price("flour",30,game.seed)),"board exact prices")
	check(store.slate.text=="","arrival slate empty")
	store.interact("scale");store.scale_model.advance(2)
	check(store.keeper.state=="weigh","keeper weighs")
	store.finish_pour()
	check(is_equal_approx(sack.ounces,2.5),"two second pour")
	check(is_equal_approx(game.dollars,.46*Prices.gold_price(30,game.seed)),"thumb credit")
	check(is_equal_approx(store.counter.visit.sold_oz,.5) and is_equal_approx(store.counter.visit.weighed_oz,.46),"visit pour record")
	var after: float=sack.ounces;store.scale_model.advance(1);check(sack.ounces==after,"release stops pour")
	var counter: Node=store.counter
	check(counter.select("flour")=="" and counter.pile.size()==1,"select flour")
	check(is_equal_approx(counter.total(),Prices.price("flour",30,game.seed)),"pile total")
	check(counter.select("sluice")=="Not this trip" and counter.pile.size()==1,"later milestone display refuses sale")
	counter.return_last();check(counter.pile.is_empty(),"return restores reservation")
	game.purchases.append({"day":30,"item":"line","count":Stock.stock("line",30,game.seed,[])})
	check(counter.select("line")=="Sold out","empty peg refuses selection")
	game.purchases.clear();game.inventory.goods.flour=38
	# 2.0 rule change: stores already at camp stay at camp; the limit is today's carry.
	check(counter.select("flour")=="","goods at camp do not count against the carry");counter.return_last()
	for i in 40: counter.select("flour")
	check(counter.pile.size()==40 and counter.select("flour")=="Too heavy","pack limit is one man's carry home")
	while not counter.pile.is_empty(): counter.return_last()
	game.inventory.goods.flour=0;game.dollars=0;sack.ounces=0;counter.select("flour")
	check(not counter.settle() and counter.pile.is_empty() and counter.shortfall>0,"SHORT returns last item without awarding goods")
	game.dollars=.1;sack.ounces=1;counter.select("flour");counter.select("hook")
	var cost: float=counter.total();var need: float=(cost-.1)/(Prices.gold_price(30,game.seed)*.92)
	check(counter.settle(),"coin then dust settles")
	check(is_zero_approx(game.dollars) and is_equal_approx(sack.ounces,1-need),"coin first exact dust shortfall")
	check(game.inventory.goods.flour==1 and game.purchases.size()==2,"goods and dated stock rows")
	game.inventory.fish=[]
	for i in 3: game.inventory.fish.append({"species":"trout","state":"smoked","weight_lb":1.25,"day":30})
	counter.toggle_fish();check(is_equal_approx(counter.fish_credit(),3.75*Prices.fish_price(30,game.seed)),"fish weight credit")
	counter.toggle_fish();check(game.inventory.fish.size()==3,"fish offer reversible")
	counter.toggle_fish();check(counter.settle() and game.inventory.fish.is_empty(),"fish settle removes offered fish")
	var before_inventory: Dictionary=game.inventory.duplicate(true);var before_gold: float=sack.ounces
	await trip.home(true)
	check(game.scene=="claim" and clock.running and is_equal_approx(clock.hour_at(clock.elapsed),19),"home 19 running")
	for key in ["goods","rod","hooks","line_m","bait","fish","firewood"]: check(game.inventory[key]==before_inventory[key],"return inventory unchanged: "+key)
	check(sack.ounces==before_gold,"return sack unchanged")
	check(game.ledger.size()==1,"one visit appended")
	var ledger: Node=claim.get_node("Ledger");ledger.open_book()
	check(ledger.left.text.contains("Walked to Lambert's.") and ledger.left.text.contains("He called it"),"visit prose")
	var second: Dictionary=game.ledger[0].duplicate(true);second.day=65
	for item in second.prices: second.prices[item]=Prices.price(item,65,game.seed)
	second.gold_price=Prices.gold_price(65,game.seed);game.ledger.append(second);ledger.refresh()
	check(ledger.right.text.contains("was $") and ledger.right.text.contains("Gold $"),"previous visit margin")
	ledger.close_book()
	var camp: Node=claim.get_node("Camp");clock.running=false;game.condition=40;game.inventory.meals_today=0
	game.inventory.goods={"flour":1.0,"salt":.5,"beans":1.0,"pork":1.0,"coffee":.2};camp.fire_hours=4
	check(camp.start_recipe("biscuits"),"start biscuits");camp.advance(.25)
	check(game.condition==60 and is_equal_approx(game.inventory.goods.flour,.5) and is_equal_approx(game.inventory.goods.salt,.48),"biscuit meal")
	check(camp.start_recipe("beans"),"start beans");camp.advance(2)
	check(game.inventory.fish.size()==2,"beans leave two portions")
	check(camp.start_recipe("pork"),"start pork");camp.advance(1.0/6)
	clock.start(8);clock.running=false;check(camp.start_recipe("coffee"),"morning coffee");camp.advance(1.0/6)
	check(not camp.start_recipe("coffee"),"coffee once daily")
	camp.coffee_day=-1;clock.start(10.017);clock.running=false;check(not camp.start_recipe("coffee"),"coffee too late")
	check(camp.cut_bait() and game.inventory.bait.pork==4,"pork bait")
	game.inventory.goods.pork=.1;check(not camp.cut_bait(),"too little pork")
	game.inventory.fish=[Cooking.fresh("trout",1,30)];game.inventory.goods.salt=0
	check(not camp.hang(),"smoke requires salt");game.inventory.goods.salt=.5
	check(camp.hang() and is_equal_approx(game.inventory.goods.salt,.4),"smoke consumes salt")
	var fighter=preload("res://scripts/fisher.gd")
	var fight:=preload("res://scripts/fight_model.gd").begin(1,12,7);fight.run_at=0;fight.tension=.35
	var break_time:=0.0
	while not fight.broken and break_time<1:
		fight=fighter.step_with_rod(fight,.01,true,true);break_time+=.01
	check(break_time>=.68,"rod release window")
	var aim_camera:=Camera3D.new();claim.add_child(aim_camera)
	claim.get_node("Walker").position=Vector3(0,.1,-5)
	aim_camera.position=Vector3(0,2,-5);aim_camera.look_at(Vector3(0,0,-30));aim_camera.make_current()
	for rod in [false,true]:
		game.inventory.rod=rod
		var aim: Vector3=claim.get_node("Walker/Fisher").aim()
		check(is_equal_approx(Vector2(aim.x,aim.z+5).length(),12 if rod else 8),"aim range "+str(rod))
	claim.get_node("CameraRig/SpringArm3D/Camera3D").make_current();aim_camera.queue_free()
	var guided:=Vector3(14.9,0,1)
	for i in 600: guided+=preload("res://scripts/store_layout.gd").guide_motion(guided,Vector3(2.4,0,0))/60
	check(guided.x<18 and guided.x>15,"clearing guide resists outward walking without a hard wall")
	var visual: Node=claim.get_node("Walker/Visual");game.inventory.rod=true;visual.play_activity("fish_idle");visual._physics_process(.01)
	check(visual.rod_visual.visible and not visual.handline.visible,"rod held in stance")
	visual.stop_activity();visual._physics_process(.01);check(not visual.rod_visual.visible,"rod hidden idle")
	game.inventory.rod=false;game.inventory.fish=[];game.inventory.line_m=0
	for pair in [[4,0],[6,1],[15,2],[30,3]]:
		game.inventory.goods={"flour":pair[0]};visual._physics_process(.01);check(visual.pack_stage==pair[1],"pack silhouette "+str(pair[0]))
	game.inventory.goods={"flour":0.0,"beans":0.0,"pork":0.0,"coffee":0.0,"salt":2.0}
	clock.start(15);await trip.depart(true);store=trip.shop
	check(is_equal_approx(store.get_node("Daylight").current_hour,21),"sandbox bypasses late departure")
	store.set_physics_process(false);store.camera_rig.set_process(false)
	store.walker.position=Vector3(-1.5,0,.7);store.camera_rig.camera.position=Vector3(-1.5,2.0,2.8);store.camera_rig.camera.look_at(store.Layout.item_position("flour"))
	check(store.target()=="flour","aiming selects reachable flour")
	var key:=InputEventKey.new();key.physical_keycode=KEY_G;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
	check(store.counter.pile.size()==1,"G moves aimed item to pile")
	for i in 100: await physics_frame
	check(not store.busy,"take finishes and unlocks movement")
	store.counter.abandon();game.dollars=0;sack.ounces=1;store.counter.select("flour")
	var auto_cost: float=store.counter.total();var flour_before: float=game.inventory.goods.flour
	store.set_physics_process(true);store.interact("slate")
	for i in 240: await physics_frame
	check(not store.busy and not store.settling,"automatic pour and hand-over finish")
	check(is_equal_approx(sack.ounces,1-auto_cost/(store.counter.visit.gold_price*.92)),"automatic pour removes exact shortfall")
	check(game.inventory.goods.flour==flour_before+1,"automatic settlement delivers goods once")
	key=InputEventKey.new();key.physical_keycode=KEY_G;key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	store.get_node("Sandbox").refresh_fields();store.get_node("Sandbox").fields["goods.flour"].value=12
	store.get_node("Sandbox").command("Apply");check(game.inventory.goods.flour==12,"store sandbox goods apply")
	await trip.home(true)
	for i in 3: await process_frame
	print("MILESTONE 10 ","PASS" if errors.is_empty() else errors)
	claim.get_node("Soundscape").stop();claim.get_node("Camp").fire_sound.stop();claim.get_node("Rain").sound.stop()
	quit(0 if errors.is_empty() else 1)
