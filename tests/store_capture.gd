extends SceneTree
const Guard=preload("res://tests/composition_guard.gd")
var store: Node3D
var camera: Camera3D
var results: Dictionary={}
const Probes=preload("res://tests/store_probes.gd")
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func shot(name: String,point: Vector3,look: Vector3,fov: float) -> void:
	camera.position=point;camera.look_at(look);camera.fov=fov;camera.make_current()
	for i in 60: await process_frame
	await physics_frame;await RenderingServer.frame_post_draw
	results[name]={"guard":Guard.check(self,name),"camera":str(point)}
	root.get_texture().get_image().save_png("res://artifacts/milestone-10-"+name+".png")
	if name=="board":
		results[name].text=Probes.text_ink(self,store.Layout.BOARD,Vector2(1.05,1.85))
		if results[name].text.minimum<22 or results[name].text.contrast<4: failures.append("board reading probe")
	if name=="counter":
		results[name].text=Probes.text_ink(self,store.Layout.SLATE,Vector2(.98,.68))
		if results[name].text.minimum<20: failures.append("slate reading probe")
	if name in ["weighing","lambert"]:
		results[name].coverage=await Probes.coverage(self,store,name=="lambert")
		var required:=.06 if name=="lambert" else .12
		if results[name].coverage.subject<required or results[name].coverage.counter>.5: failures.append(name+" coverage")
func run() -> void:
	root.size=Vector2i(1920,1080)
	var game: Node=root.get_node("GameState");game.apply_scenario({"day":30,"hour":13,"dollars":10})
	store=load("res://scenes/store.tscn").instantiate();root.add_child(store)
	store.set_physics_process(false);store.walker.set_physics_process(false)
	camera=Camera3D.new();var mount:=Node3D.new();root.add_child(mount);mount.add_child(camera);camera.attributes=store.get_node("Daylight").camera_attributes
	await shot("arrival",Vector3(6.4,2.15,10.8),Vector3(0,1.35,-.1),48)
	store.walker.position=Vector3(-.6,0,1)
	await shot("board",Vector3(-3.25,1.78,4.8),store.Layout.BOARD,32)
	root.get_node("Sack").ounces=3;store.interact("scale")
	store.scale_model.advance(2);store._physics_process(0)
	await shot("weighing",Vector3(-2.25,2.35,-.7),Vector3(-1.05,1.35,.15),42)
	store.finish_pour();store.walker.position=Vector3(0,0,3)
	await shot("lambert",Vector3(-.5,2.9,.4),Vector3(.15,1.44,-.5),21.7)
	store.walker.position=Vector3(3,0,3)
	game.day=0;store.refresh()
	await shot("shelves-june",Vector3(-.65,2.8,2.5),Vector3(0,1.45,-1.3),49)
	game.day=110
	var june_objects: int=store.shelves.display.get_child_count()
	var history:=FileAccess.open("res://artifacts/season-spendthrift.csv",FileAccess.READ)
	if history:
		while not history.eof_reached():
			var row:=history.get_csv_line()
			if row.size()>7 and row[4]=="buy" and int(row[0])<=110: game.purchases.append({"day":int(row[0]),"item":row[6],"count":int(float(row[7]))})
	store.refresh()
	results.stock={"june_objects":june_objects,"october_objects":store.shelves.display.get_child_count(),"source":"season-spendthrift.csv"}
	if june_objects-store.shelves.display.get_child_count()<6: failures.append("specified stock does not thin by six objects")
	await shot("shelves-october",Vector3(-.65,2.8,2.5),Vector3(0,1.45,-1.3),49)
	game.day=30;game.purchases.clear();store.counter.select("flour");store.counter.select("hook");store.counter.select("line")
	await shot("counter",Vector3(.15,2.65,2.7),Vector3(.5,1.12,.1),36)
	game.weather_override="rain";store.get_node("Rain").current=.8;store.get_node("Daylight").overcast=.8;store.get_node("Daylight").apply(13)
	await shot("rain-store",Vector3(2,2,4.5),Vector3(0,1.4,-.5),55)
	game.weather_override="clear";store.get_node("Rain").current=0;store.get_node("Daylight").apply(13)
	game.dollars=0;root.get_node("Sack").ounces=0;store.counter.abandon();store.counter.select("flour");store.counter.settle()
	await shot("short",Vector3(1.2,1.48,3.1),store.Layout.SLATE,20)
	game.day=0;game.purchases.assign([{"day":0,"item":"line","count":6}]);store.refresh()
	await shot("empty-peg",Vector3(-.1,1.9,1.3),store.Layout.item_position("line"),32)
	FileAccess.open("res://artifacts/store-probes.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("STORE PROBES ",failures)
	store.get_node("Soundscape").stop();store.get_node("Rain").sound.stop()
	quit(1 if Guard.failed or not failures.is_empty() else 0)
