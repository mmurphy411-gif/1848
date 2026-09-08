extends RefCounted
const RECIPES := {"fried":{"hours":1.0/3.0,"fire":true},"smoked":{"hours":4.0,"fire":true}}
static func portions(weight: float) -> int: return 2 if weight>=2 else 1
static func spoiled(fish: Dictionary, ending_day: int) -> bool:
	return fish.state=="fresh" and (int(fish.day)<ending_day or fish.get("cooked",false))
static func fresh(species: String, weight: float, day: int) -> Dictionary:
	return {"species":species,"weight_lb":weight,"day":day,"state":"fresh"}
