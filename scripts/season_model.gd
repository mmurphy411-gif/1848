extends RefCounted
const LAST_DAY:=132
static func closes(day: int) -> bool: return day>=LAST_DAY
static func summary(inventory: Dictionary,purchases: Array,ledger: Array,expedition: Dictionary,coin: float,gold: float,condition: float,seed: int,crew: Dictionary={}) -> Dictionary:
	var spent:=0.0
	for purchase in purchases: spent+=purchase.count*preload("res://scripts/prices.gd").price(purchase.item,purchase.day,seed)
	var food_lb:=0.0
	for f in inventory.fish+inventory.cache: food_lb+=float(f.weight_lb)
	for item in ["flour","beans","pork"]: food_lb+=float(inventory.get("goods",{}).get(item,0))
	var tools: Array[String]=[]
	for tool in ["rod","crowbar","pick","shovel","boots","rocker","spear","rifle","tent"]:
		if inventory.get(tool,false): tools.append(tool.capitalize())
	var hands: Array=crew.get("hands",[])
	var worth:=coin+gold*16.0
	return {"crew_hands":hands.size(),"crew_names":hands.map(func(h): return h.name),"crew_take":float(crew.get("take_total",0.0)),
		"wages":float(crew.get("wages_paid",0.0)),"bar_name":str(crew.get("bar_name","")),"worth":worth,
		"title":preload("res://scripts/crew_model.gd").title(worth,hands.size()),"coin":coin,"gold":gold,"condition":condition,"spent":spent,"food_lb":food_lb,"tools":tools,"catches":inventory.catches.duplicate(true),"hides_sold":expedition.hides_sold,"shots":expedition.shots,"deer":expedition.deer_dead.size(),"bear":1 if expedition.bear_dead else 0,"visits":ledger.size()}
