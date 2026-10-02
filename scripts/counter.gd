extends Node3D
## Pending items are reservations; only settlement changes owned stock.
const Prices=preload("res://scripts/prices.gd")
const Stock=preload("res://scripts/store_stock.gd")
const Pack=preload("res://scripts/pack.gd")
signal changed
var pile: Array[String]=[]
var fish_offer: Array=[]
var hide_offer: Array=[]
var visit: Dictionary={}
var shortfall := 0.0
@onready var game: Node=get_node("/root/GameState")
@onready var sack: Node=get_node("/root/Sack")
func _ready() -> void: begin_visit()
func begin_visit() -> void:
	visit={"day":game.day,"gold_price":Prices.gold_price(game.day,game.seed),"sold_oz":0.0,"weighed_oz":0.0,"dollars_in":0.0,"fish_lb":0.0,"bought":[],"prices":{}}
	for item in ["flour","beans","pork","hook"]: visit.prices[item]=Prices.price(item,game.day,game.seed)
func available(item: String) -> int: return Stock.stock(item,game.day,game.seed,game.purchases)-pile.count(item)
func projected_inventory() -> Dictionary:
	var inventory: Dictionary=game.inventory.duplicate(true)
	# Offered fish remain owned until settlement, but leave in this same exchange.
	for fish in fish_offer: inventory.fish.erase(fish)
	for hide in hide_offer: inventory.hides.erase(hide)
	for item in pile: inventory=Pack.add(inventory,item)
	return inventory
func select(item: String) -> String:
	var good:=Stock.entry(item)
	if good.is_empty() or not good.for_sale: return "Not this trip"
	if available(item)<=0: return "Sold out"
	if item in ["spear","rifle","tent","strongbox"] and (game.inventory.get(item,false) or pile.has(item)): return "Already owned"
	if item=="rod" and (game.inventory.rod or pile.has("rod")): return "Already have a rod"
	if item in preload("res://scripts/mining_model.gd").TOOLS and (game.inventory.get(item,false) or pile.has(item)): return "Already owned"
	# 2.0: the limit is what one man carries home today; stores at camp stay at camp.
	if carried(item)>Pack.LIMIT_LB+.00001: return "Too heavy"
	pile.append(item);shortfall=0;changed.emit();return ""
## Pounds of today's purchases, optionally with one more item.
func carried(extra := "") -> float:
	var empty := {"goods":{},"hooks":0,"line_m":0.0}
	var bought := empty
	for item in pile: bought=Pack.add(bought,item)
	# Earlier settlements today are already on his back.
	for line in visit.get("bought",[]): bought=Pack.add(bought,line.item,int(line.count))
	if extra!="": bought=Pack.add(bought,extra)
	return Pack.weight(bought)
func return_last() -> String:
	if pile.is_empty(): return ""
	var item: String=pile.pop_back();changed.emit();return item
func total() -> float:
	var sum := 0.0
	for item in pile: sum+=Prices.price(item,game.day,game.seed)
	return snappedf(sum,.01)
func fish_weight() -> float:
	var sum := 0.0
	for fish in fish_offer: sum+=float(fish.weight_lb)
	return sum
func fish_credit() -> float: return fish_weight()*Prices.fish_price(game.day,game.seed)
func hide_credit() -> float:
	var value:=0.0
	for hide in hide_offer: value+=(5.0 if hide.species=="bear" else 2.0)*Prices.index(game.day,game.seed,"hide")
	return value
func trade_credit() -> float: return fish_credit()+hide_credit()
func toggle_fish() -> void:
	if not fish_offer.is_empty() or not hide_offer.is_empty(): fish_offer.clear();hide_offer.clear()
	else:
		fish_offer=game.inventory.fish.filter(func(f):return f.state=="smoked")
		hide_offer=game.inventory.get("hides",[]).duplicate(true)
	changed.emit()
func credit_pour(ounces: float) -> void:
	if ounces<=0: return
	var credit:=Prices.credit(ounces,game.day,game.seed)
	game.dollars+=credit.dollars
	visit.sold_oz+=ounces;visit.weighed_oz+=credit.weighed;visit.dollars_in+=credit.dollars
	game.changed.emit();changed.emit()
func settle() -> bool:
	if pile.is_empty() and fish_offer.is_empty() and hide_offer.is_empty(): return false
	var cost:=total()
	var rate: float=visit.gold_price*.92
	var funds: float=game.dollars+trade_credit()+sack.ounces*rate
	if funds+.000001<cost:
		shortfall=cost-funds
		return_last();changed.emit();return false
	var fish_lb:=fish_weight()
	var fish_dollars:=trade_credit()
	var hides_count:=hide_offer.size()
	var dust: float=maxf(0,cost-game.dollars-fish_dollars)/rate
	# No partial mutation until the complete exchange is known to be affordable.
	var inventory:=projected_inventory()
	sack.ounces=maxf(0,sack.ounces-dust);sack.changed.emit(sack.ounces)
	game.dollars=maxf(0,game.dollars+fish_dollars+ dust*rate-cost)
	game.inventory=inventory
	game.expedition.hides_sold+=hides_count
	visit["hides"]=visit.get("hides",0)+hides_count
	visit.sold_oz+=dust;visit.weighed_oz+=dust*.92;visit.dollars_in+=dust*rate+fish_dollars;visit.fish_lb+=fish_lb
	var counts: Dictionary={}
	for item in pile: counts[item]=counts.get(item,0)+1
	for item in counts:
		game.purchases.append({"day":game.day,"item":item,"count":counts[item]})
		visit.bought.append({"item":item,"count":counts[item],"price":Prices.price(item,game.day,game.seed)})
	pile.clear();fish_offer.clear();hide_offer.clear();shortfall=0;game.changed.emit();changed.emit();return true
func abandon() -> void: pile.clear();fish_offer.clear();hide_offer.clear();changed.emit()
