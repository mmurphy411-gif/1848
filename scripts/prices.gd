extends RefCounted
const Weather = preload("res://scripts/weather.gd")
const Stock = preload("res://scripts/store_stock.gd")
const CHECKPOINTS := [[0,1.0],[36,1.5],[67,2.5],[97,4.0],[128,6.0]]

static func gold_price(day: int, seed: int) -> float:
	var d:=maxi(0,day)
	var bucket:=int(d/5)
	# Five-day linear interpolation caps wander steps at .6. Daily amplitude
	# .06 adds at most .12, keeping the whole daily move below .75 dollars.
	var wander:=lerpf(2*Weather.noise(seed,bucket,421)-1,
		2*Weather.noise(seed,bucket+1,421)-1,float(d%5)/5)*1.5
	var daily: float=.06*(2*Weather.noise(seed,d,422)-1)
	return clampf(lerpf(16,14,clampf(float(d)/132,0,1))+wander+daily,12,18)

static func index(day: int, seed: int, item: String) -> float:
	var base:=1.0
	for i in range(1,CHECKPOINTS.size()):
		var a: Array=CHECKPOINTS[i-1]; var b: Array=CHECKPOINTS[i]
		base=lerpf(a[1],b[1],clampf(float(day-int(a[0]))/float(b[0]-a[0]),0,1))
		if day<=b[0]: break
	return base*(1+.08*(2*Weather.noise(seed,day,hash(item))-1))

static func price(item: String, day: int, seed: int) -> float:
	var good:=Stock.entry(item)
	if good.is_empty(): return 0.0
	return roundf(float(good.base_price)*index(day,seed,item)*100)/100

static func credit(ounces: float, day: int, seed: int) -> Dictionary:
	var weighed:=maxf(0,ounces)*.92
	return {"weighed":weighed,"dollars":weighed*gold_price(day,seed)}

static func fish_price(day: int, seed: int) -> float:
	return .12*index(day,seed,"smoked_fish")
