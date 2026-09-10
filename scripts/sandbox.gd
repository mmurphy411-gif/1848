extends CanvasLayer
const Calendar=preload("res://scripts/calendar.gd")
var opened := false
var panel := PanelContainer.new()
var fields: Dictionary={}
var weather := OptionButton.new()
var fire := CheckButton.new()
var date_label := Label.new()
var price_label := Label.new()
var rod := CheckButton.new()
var river_auto := CheckButton.new()
@onready var game: Node=get_node("/root/GameState")
@onready var claim: Node3D=get_parent()
func _ready() -> void:
	if not OS.is_debug_build(): set_process_input(false);return
	layer=10;add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left=-380;panel.offset_right=-16;panel.offset_top=20;panel.offset_bottom=-20
	var scroll := ScrollContainer.new();panel.add_child(scroll)
	var column := VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	var title := Label.new();title.text="SEASON SANDBOX  ·  F4";column.add_child(title);column.add_child(date_label)
	for key in ["seed","day","hour","dollars","gold","condition","hooks","line","firewood","bait.grasshopper","bait.hellgrammite","bait.worm","bait.pork","fish.fresh","fish.smoked","goods.flour","goods.beans","goods.pork","goods.coffee","goods.salt","crowbar","pick","shovel","boots","rocker","river"]:
		var row := HBoxContainer.new();column.add_child(row)
		var label := Label.new();label.text=key;label.custom_minimum_size.x=170;row.add_child(label)
		var value := SpinBox.new();value.min_value=0;value.max_value=2147483647 if key=="seed" else 132 if key=="day" else 24 if key=="hour" else 100000
		value.step=.01 if key.begins_with("goods.") else .25 if key in ["hour","gold","dollars","condition","line"] else 1
		if key in preload("res://scripts/mining_model.gd").TOOLS: value.max_value=1
		if key=="river": value.min_value=-.75;value.max_value=.14;value.step=.01
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(value);fields[key]=value
	for name in ["auto","clear","hot","rain","frost"]: weather.add_item(name)
	column.add_child(weather);fire.text="Fire lit";column.add_child(fire)
	rod.text="Willow rod";column.add_child(rod);column.add_child(price_label)
	river_auto.text="Seasonal river level";column.add_child(river_auto)
	for name in ["Apply","Dawn","Dusk","Next day","Sleep","Refresh fish","Crevice","Rocker bank","Watch bear","Watch deer","Watch squirrel","Watch quail","Watch jay","Go to store","Home"]:
		var button := Button.new();button.text=name;button.pressed.connect(command.bind(name));column.add_child(button)
	panel.hide()
func refresh_fields() -> void:
	var values := {"seed":game.seed,"day":game.day,"hour":claim.get_node("Daylight/Clock").hour_at(claim.get_node("Daylight/Clock").elapsed),"dollars":game.dollars,"gold":get_node("/root/Sack").ounces,"condition":game.condition,"hooks":game.inventory.hooks,"line":game.inventory.line_m,"firewood":game.inventory.firewood}
	for bait in game.inventory.bait: values["bait."+bait]=game.inventory.bait[bait]
	for item in game.inventory.goods: values["goods."+item]=game.inventory.goods[item]
	for kind in ["fresh","smoked"]: values["fish."+kind]=game.inventory.fish.filter(func(f):return f.state==kind).size()
	for tool in preload("res://scripts/mining_model.gd").TOOLS: values[tool]=1 if game.inventory.get(tool,false) else 0
	values.river=game.water_level();river_auto.button_pressed=is_inf(game.river_override)
	for key in fields: fields[key].value=values[key]
	date_label.text=Calendar.date_string(game.day)
	weather.select(["auto","clear","hot","rain","frost"].find(game.weather_override));fire.button_pressed=claim.has_node("Camp") and claim.get_node("Camp").burning()
	rod.button_pressed=game.inventory.rod
	var prices=preload("res://scripts/prices.gd")
	price_label.text="Gold $%.2f · Flour $%.2f" % [prices.gold_price(game.day,game.seed),prices.price("flour",game.day,game.seed)]
func command(name: String) -> void:
	var clock: Node=claim.get_node("Daylight/Clock")
	if name=="Go to store":
		close_panel();get_node("/root/Trip").depart(true);return
	if name=="Home":
		close_panel();get_node("/root/Trip").home(true);return
	if game.scene=="store":
		if name=="Apply" and not claim.busy:
			var args: Dictionary={"rod":"1" if rod.button_pressed else "0","weather":weather.get_item_text(weather.selected)}
			for key in fields:
				if key!="gold": args[key]=str(fields[key].value)
			if river_auto.button_pressed: args.river="auto"
			game.apply_scenario(args);get_node("/root/Sack").ounces=fields.gold.value;get_node("/root/Sack").changed.emit(fields.gold.value)
			clock.start(game.start_hour);claim.get_node("Daylight").apply(game.start_hour)
			claim.counter.abandon();claim.counter.begin_visit();claim.board.refresh();claim.refresh()
		refresh_fields();return
	match name:
		"Apply":
			if claim.get_node("Activities").busy: return
			claim.get_node("Walker/Fisher").cancel()
			claim.get_node("Walker/Panner")._reset()
			var args: Dictionary={}
			for key in fields:
				if key!="gold": args[key]=str(fields[key].value)
			args.weather=weather.get_item_text(weather.selected)
			args.rod="1" if rod.button_pressed else "0"
			if river_auto.button_pressed: args.river="auto"
			game.apply_scenario(args)
			get_node("/root/Sack").ounces=fields.gold.value;get_node("/root/Sack").changed.emit(fields.gold.value)
			clock.start(game.start_hour)
			claim.get_node("Camp").last_hour=game.start_hour
			claim.get_node("Camp").fire_hours=2.0 if fire.button_pressed else 0.0
			claim.get_node("BaitSources").reset()
		"Dawn": clock.start(clock.DAWN)
		"Dusk": clock.start(19)
		"Next day": clock.end_day()
		"Sleep":
			close_panel()
			claim.get_node("Activities").sleep()
		"Crevice","Rocker bank":
			if claim.get_node("Activities").busy: return
			close_panel();claim.get_node("Mining").focus_site("crevice" if name=="Crevice" else "rocker")
		"Watch bear","Watch deer","Watch squirrel","Watch quail","Watch jay":
			if claim.get_node("Activities").busy: return
			close_panel();claim.get_node("Wildlife").focus(name.trim_prefix("Watch "))
	claim.get_node("FishSchool").refresh()
	claim.get_node("Wildlife").refresh()
	refresh_fields()
func close_panel() -> void:
	opened=false;panel.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_sandbox"):
		if opened: close_panel()
		else:
			claim.get_node("Ledger").close_book()
			opened=true;refresh_fields();panel.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif opened:
		if event.is_action_pressed("ui_cancel"): close_panel();get_viewport().set_input_as_handled()
		elif event is InputEventKey and not (get_viewport().gui_get_focus_owner() is LineEdit):
			if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_E,KEY_F,KEY_G]: get_viewport().set_input_as_handled()
