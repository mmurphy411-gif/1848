extends RefCounted
const LIMIT_LB := 40.0
static func weight(inventory: Dictionary) -> float:
	var total := 0.0
	for amount in inventory.get("goods",{}).values(): total+=float(amount)
	for fish in inventory.get("fish",[]): total+=float(fish.get("weight_lb",0))
	total+=1.5 if inventory.get("rod",false) else 0.0
	total+=float(inventory.get("line_m",0))*.01
	return total
static func add(inventory: Dictionary, item: String, count: int=1) -> Dictionary:
	var next:=inventory.duplicate(true)
	match item:
		"hook": next.hooks=next.get("hooks",0)+count
		"line": next.line_m=next.get("line_m",0)+20.0*count
		"rod": next.rod=true
		_:
			if not next.has("goods"): next.goods={}
			next.goods[item]=next.goods.get(item,0.0)+count
	return next
