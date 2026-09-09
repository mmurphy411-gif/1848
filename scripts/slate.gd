extends Label3D
var counter: Node
func _ready() -> void:
	font=preload("res://assets/fonts/Cedarville-Cursive.ttf")
	font_size=46;pixel_size=.0018;outline_size=0;modulate=Color(.94,.90,.76)
func refresh() -> void:
	text=""
	if counter==null: return
	var game: Node=get_node("/root/GameState")
	var counts: Dictionary={}
	for item in counter.pile: counts[item]=counts.get(item,0)+1
	for item in counts: text+="%s ×%d  $%.2f\n" % [item.capitalize(),counts[item],counter.Prices.price(item,game.day,game.seed)*counts[item]]
	if not counter.fish_offer.is_empty(): text+="Fish -$%.2f\n" % counter.fish_credit()
	if not text.is_empty(): text+="TOTAL $%.2f\nPACK %.0f lb" % [counter.total()-counter.fish_credit(),counter.Pack.weight(counter.projected_inventory())]
	if counter.shortfall>0: text+="\nSHORT $%.2f" % counter.shortfall
	# Fit the font's real ascender/descender metrics inside the physical slate.
	var lines:=maxi(1,text.count("\n")+1)
	font_size=mini(46,floori(.58/(pixel_size*lines*(font.get_height(100)/100.0))))
