extends RefCounted
static func eat(value: float, smoked := false) -> float: return clampf(value+(15 if smoked else 20),5,100)
static func missed(value: float) -> float: return maxf(5,value-15)
static func speed(value: float) -> float: return lerpf(.77,1.0,smoothstep(40,70,value))
static func wade_speed(value: float) -> float: return lerpf(.8,1.05,smoothstep(40,70,value))
static func demote(tier: int, value: float, roll: float) -> int:
	return maxi(0,tier-1) if value<40 and roll<.25 else tier
