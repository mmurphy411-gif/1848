extends RefCounted
## A finite, replayable shelf history. Seed is reserved: specified shipments
## have exact counts, so no invented random resupply or off-screen customers.
const ROWS := [
	["hook",.25,"each",0.0,24,24,112,true],
	["line",1.0,"20 m coil",.2,6,4,112,true],
	["rod",3.0,"willow rod",1.5,1,1,36,true],
	["flour",.10,"lb",1.0,200,150,119,true],
	["beans",.08,"lb",1.0,120,80,119,true],
	["pork",.20,"lb",1.0,80,60,119,true],
	["coffee",.25,"lb",1.0,20,15,105,true],
	["salt",.10,"lb",1.0,40,30,119,true],
	["crowbar",6.0,"each",5.0,2,1,98,false],
	["pick",8.0,"each",7.0,2,1,98,false],
	["shovel",8.0,"each",5.0,2,1,98,false],
	["boots",12.0,"pair",3.0,2,1,84,false],
	["rocker",25.0,"lumber and iron",40.0,1,1,84,false],
	["spear",6.0,"each",2.0,1,1,91,false],
	["rifle",60.0,"each",9.0,1,0,-1,false],
	["powder",4.0,"20 shots",1.0,3,2,112,false],
	["tent",20.0,"canvas tent",18.0,1,1,84,false],
]

static func catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for row in ROWS:
		result.append({"item":row[0],"base_price":row[1],"unit":row[2],
			"pounds_per_unit":row[3],"opening":row[4],"restock":row[5],
			"last_restock":row[6],"for_sale":row[7]})
	return result

static func entry(item: String) -> Dictionary:
	for good in catalogue():
		if good.item==item: return good
	return {}

static func stock(item: String, day: int, _seed: int=1848, purchases: Array=[]) -> int:
	var good:=entry(item)
	if good.is_empty() or day<0: return 0
	var count: int=good.opening
	if item=="rod":
		if day>=36: count+=1
	else:
		for delivery in range(3,mini(day,good.last_restock)+1,7): count+=int(good.restock)
	for purchase in purchases:
		if purchase.item==item and purchase.day<=day: count-=int(purchase.count)
	return maxi(0,count)
