extends RefCounted
const LIMIT_LB := 40.0
static func weight(inventory: Dictionary) -> float:
	var total := 0.0
	for amount in inventory.get("goods",{}).values(): total+=float(amount)
	for fish in inventory.get("fish",[]): total+=float(fish.get("weight_lb",0))
	total+=1.5 if inventory.get("rod",false) else 0.0
	total+=float(inventory.get("line_m",0))*.01
	for item in ["crowbar","pick","shovel","spear","rifle"]:
		if inventory.get(item,false): total+=preload("res://scripts/store_stock.gd").entry(item).pounds_per_unit
	total+=float(inventory.get("ammo",0))/20.0
	for hide in inventory.get("hides",[]): total+=float(hide.weight_lb)
	total+=int(inventory.get("pans",0))*1.5+int(inventory.get("bunks",0))*12.0+int(inventory.get("whiskey",0))*3.0
	total+=25.0 if inventory.get("strongbox",false) else 0.0
	# Boots are worn. Rocker lumber is a separate tied bundle left at camp.
	return total
## What the miner carries in the field: catch, hides, rod, line, tools and powder.
## Provisions and outfit gear stay at camp (2.0), so a crew's pantry never blocks a harvest.
static func field_weight(inventory: Dictionary) -> float:
	var total:=weight(inventory)
	for amount in inventory.get("goods",{}).values(): total-=float(amount)
	total-=int(inventory.get("pans",0))*1.5+int(inventory.get("bunks",0))*12.0+int(inventory.get("whiskey",0))*3.0
	total-=25.0 if inventory.get("strongbox",false) else 0.0
	return maxf(0,total)

static func add(inventory: Dictionary, item: String, count: int=1) -> Dictionary:
	var next:=inventory.duplicate(true)
	match item:
		"hook": next.hooks=next.get("hooks",0)+count
		"line": next.line_m=next.get("line_m",0)+20.0*count
		"rod": next.rod=true
		"powder": next.ammo=next.get("ammo",0)+20*count
		"tent","rifle","spear","crowbar","pick","shovel","boots","rocker","strongbox": next[item]=true
		"pan": next.pans=next.get("pans",0)+count
		"bunk": next.bunks=next.get("bunks",0)+count
		"whiskey": next.whiskey=next.get("whiskey",0)+count
		"timber": next.timber=next.get("timber",0)+count
		_:
			if not next.has("goods"): next.goods={}
			next.goods[item]=next.goods.get(item,0.0)+count
	return next
