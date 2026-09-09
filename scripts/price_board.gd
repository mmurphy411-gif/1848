extends Label3D
const Prices=preload("res://scripts/prices.gd")
const Stock=preload("res://scripts/store_stock.gd")
const Calendar=preload("res://scripts/calendar.gd")
func _ready() -> void:
	font=preload("res://assets/fonts/PatrickHand-Regular.ttf");font_size=52;pixel_size=.0018;outline_size=0
	modulate=Color(.94,.90,.74);shaded=false;no_depth_test=false
	refresh()
func refresh() -> void:
	var game: Node=get_node("/root/GameState")
	text=preload("res://scripts/store.gd").KEEPER.to_upper()+"\n"+Calendar.date_string(game.day)+"\nGOLD $%.2f / oz\n"
	text=text % Prices.gold_price(game.day,game.seed)
	for good in Stock.catalogue():
		if good.for_sale: text+="%s $%.2f / %s\n" % [good.item.capitalize(),Prices.price(good.item,game.day,game.seed),"coil" if good.item=="line" else "each" if good.item=="rod" else good.unit]
