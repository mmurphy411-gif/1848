extends RefCounted
const Calendar = preload("res://scripts/calendar.gd")
# Integer mixing avoids mutable RNG state and is stable across call order.
static func noise(seed: int, day: int, salt := 0) -> float:
	var n := ((seed*374761393+day*668265263+salt*1442695041)&0x7fffffff)
	n=((n^(n>>13))*1274126177)&0x7fffffff
	return float(n^(n>>16))/2147483648.0
static func state(day: int, seed: int) -> String:
	var m := Calendar.month(day)
	var odds := [.65,.33,.02,0.0]
	if m==8: odds=[.60,.35,.05,0.0]
	elif m==9: odds=[.80,.08,.12,0.0]
	elif m==10: odds=[.72,0.0,.28,0.0] if Calendar.day_of_month(day)<=15 else [.60,0.0,.25,.15]
	elif m>=11: odds=[.45,0.0,.15,.40]
	var roll := noise(seed,day,9)
	for i in 4:
		roll-=odds[i]
		if roll<0: return ["clear","hot","rain","frost"][i]
	return "clear"
static func rain_intensity(day: int, seed: int) -> float:
	return lerpf(.3,1.0,noise(seed,day,11)) if state(day,seed)=="rain" else 0.0
