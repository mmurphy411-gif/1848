extends CanvasLayer
const Calendar=preload("res://scripts/calendar.gd")
var opened := false
var book := PanelContainer.new()
var left := RichTextLabel.new()
var right := RichTextLabel.new()
@onready var game: Node=get_node("/root/GameState")
func _ready() -> void:
	layer=8
	add_child(book);book.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	book.offset_left=-540;book.offset_right=540;book.offset_top=-324;book.offset_bottom=324
	var style := StyleBoxTexture.new();style.texture=preload("res://assets/camp/camp_atlas.png")
	style.content_margin_left=48;style.content_margin_right=48;style.content_margin_top=30;style.content_margin_bottom=30
	book.add_theme_stylebox_override("panel",style)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",60);book.add_child(row)
	for page in [left,right]:
		page.custom_minimum_size=Vector2(460,575);page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		page.add_theme_font_override("normal_font",preload("res://assets/fonts/Cedarville-Cursive.ttf"))
		page.add_theme_font_size_override("normal_font_size",22)
		page.add_theme_color_override("default_color",Color(.15,.12,.075));page.scroll_active=true
		page.bbcode_enabled=true
		row.add_child(page)
	game.changed.connect(refresh)
	book.hide()
func refresh() -> void:
	if not opened: return
	if game.season_ended:
		var result: Dictionary=game.final_ledger
		left.text="November 5, 1848\nFirst snow\n\n[font_size=30]%s[/font_size]\n\n" % result.get("title","")+"The season on the North Yuba is over.\n\n$%.2f in coin\n%.3f ounces of gold\n%.1f lb of food remaining\n\nCondition: %.0f / 100\n\nSpent this season: $%.2f\n%d store visits\n" % [result.coin,result.gold,result.food_lb,result.condition,result.spent,result.visits]
		right.text="The season's account\nSince June 26\n\n"
		for species in result.catches: right.text+="%d %s taken\n" % [result.catches[species],species]
		right.text+="%d deer taken · %d bear taken\n%d hides sold · %d rifle shots\n\nEquipment brought out\n%s\n" % [result.deer,result.bear,result.hides_sold,result.shots,", ".join(result.tools)]
		if result.get("crew_hands",0)>0 or result.get("crew_take",0.0)>0:
			right.text+="\n%s\nThe outfit washed %.2f oz · wages $%.2f\n%s\n" % [result.bar_name,result.crew_take,result.wages,", ".join(result.crew_names)]
		right.text+="\nG / X closes or reopens the book."
		return
	var condition := "Fit" if game.condition>=70 else "Tired" if game.condition>=40 else "Weak"
	left.text=Calendar.date_string(game.day)+"\n"+Calendar.weekday(game.day)+" — "+game.weather().capitalize()+"\n\n"+condition+".  %d meals today.\n\n" % game.inventory.meals_today
	left.text+="%d hooks and %.0f yards of line.\n" % [game.inventory.hooks,game.inventory.line_m*1.094]
	for bait in game.inventory.bait:
		if game.inventory.bait[bait]>0: left.text+="%s: %d\n" % [bait.capitalize(),game.inventory.bait[bait]]
	left.text+="\n"
	for entry in game.inventory.journal:
		if entry.day>=game.day-1: left.text+=entry.text+"\n"
	right.text="Season on the North Yuba\nSince June 26, 1848\nDay %d\n\n" % game.day
	for species in game.inventory.catches: right.text+="%d %s taken\n" % [game.inventory.catches[species],species]
	var smoked := 0
	for f in game.inventory.fish+game.inventory.cache:
		if f.state=="smoked": smoked+=1
	right.text+="\n%d smoked fish in store\n%d fish in the cache\n%.2f ounces of gold\n$%.2f in coin\n%d hooks lost\n\nPrices\n____________________\n____________________" % [smoked,game.inventory.cache.size(),get_node("/root/Sack").ounces,game.dollars,game.inventory.hooks_lost]
	if not game.ledger.is_empty():
		var visit: Dictionary=game.ledger.back()
		left.text=Calendar.date_string(visit.day)+"\n\nWalked to %s's.\n" % preload("res://scripts/store.gd").KEEPER
		if visit.sold_oz>0: left.text+="Sold %.2f oz at $%.2f.\nHe called it %.2f.\n" % [visit.sold_oz,visit.gold_price,visit.weighed_oz]
		for bought in visit.bought: left.text+="Bought %d %s at $%.2f.\n" % [bought.count,bought.item,bought.price]
		left.text+="$%.2f in coin.\nHome at dusk." % game.dollars
		right.text="Prices at %s's\n" % preload("res://scripts/store.gd").KEEPER+Calendar.date_string(visit.day)+"\n"
		var previous: Dictionary=game.ledger[-2] if game.ledger.size()>1 else {}
		for item in ["Gold","Flour","Beans","Pork","Hooks"]:
			var key: String=item.to_lower().trim_suffix("s") if item=="Hooks" else item.to_lower()
			var price: float=visit.gold_price if key=="gold" else visit.prices[key]
			right.text+="%s $%.2f" % [item,price]
			if not previous.is_empty(): right.text+="  [font_size=16](was $%.2f, %s)[/font_size]" % [previous.gold_price if key=="gold" else previous.prices[key],Calendar.date_string(previous.day)]
			right.text+="\n"
		var spent:=0.0;var sold:=0.0
		for entry in game.ledger:
			sold+=entry.sold_oz
			for bought in entry.bought: spent+=bought.price*bought.count
		right.text+="\nSpent this season $%.2f\nSold this season %.2f oz\n\nPack\n" % [spent,sold]
		for item in game.inventory.goods:
			if game.inventory.goods[item]>0: right.text+="%s %.2f lb\n" % [item.capitalize(),game.inventory.goods[item]]
		right.text+="%d hooks · %.0f yards\n%s" % [game.inventory.hooks,game.inventory.line_m*1.094,"Willow rod" if game.inventory.rod else "Hand line"]
	right.text+="\n\nTools\n"
	for item in preload("res://scripts/mining_model.gd").TOOLS+["spear","rifle","tent"]:
		if game.inventory.get(item,false): right.text+=("Crowbar and horn spoon" if item=="crowbar" else item.capitalize())+"\n"
	right.text+="%d shots of powder and ball\n%d hides carried\n" % [game.inventory.get("ammo",0),game.inventory.get("hides",[]).size()]
	right.text+="Crevice gold: %.3f oz\nCradle loads: %d\n" % [game.mining.taken[0]+game.mining.taken[1],game.mining.rocker_actions]
	if not game.crew.hands.is_empty():
		right.text+="\nThe outfit · %s\n%d hands · washed %.2f oz this season\nWages paid $%.2f · C opens the roll book\n" % [game.crew.bar_name,game.crew.hands.size(),game.crew.take_total,game.crew.wages_paid]
func open_book() -> void:
	opened=true;book.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;refresh()
func close_book() -> void:
	opened=false;book.hide();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _input(event: InputEvent) -> void:
	if not opened: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"): close_book()
	# Consume gameplay keys, while leaving mouse/scroll input to the book.
	if event is InputEventKey or event is InputEventJoypadButton: get_viewport().set_input_as_handled()
