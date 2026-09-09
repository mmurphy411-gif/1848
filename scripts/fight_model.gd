extends RefCounted
const RUN_TENSION_RATE := 1.1
const SLACK_TENSION_RATE := 1.6
const WORKING_TENSION := .35
static func begin(weight: float, distance: float, seed: int) -> Dictionary:
	return {"stamina":4+3*weight,"distance":distance,"elapsed":0.0,"run_at":2.0+float(posmod(seed,200))/100.0,"running":false,"tension":.15,"broken":false,"landed":false}
static func step(old: Dictionary, delta: float, pull: bool) -> Dictionary:
	var f := old.duplicate()
	if f.broken or f.landed: return f
	f.elapsed+=delta
	f.running=f.elapsed>=f.run_at and f.elapsed<f.run_at+.8
	if f.elapsed>=f.run_at+.8: f.run_at+=3.6
	if f.running and pull:
		f.tension=minf(1.0,f.tension+RUN_TENSION_RATE*delta)
	elif pull:
		f.tension=move_toward(f.tension,WORKING_TENSION,.45*delta)
	else:
		f.tension=maxf(0.0,f.tension-SLACK_TENSION_RATE*delta)
	if f.tension>=1.0:
		f.broken=true
		return f
	# 1.4 resolves the brief's conflicting 7 stamina / 3–8 s trout target:
	# mandatory .8 s releases otherwise make a 1 lb fish take 10.38 s.
	f.stamina=maxf(0,f.stamina+(-1.4 if pull else .4)*delta)
	f.distance=clampf(f.distance+(-1.2 if pull else .5)*delta,.65,8.0)
	f.landed=f.stamina<=0 and f.distance<=1.0
	return f
