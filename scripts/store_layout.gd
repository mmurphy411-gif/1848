extends RefCounted
const TRAIL := [Vector3(8,0,14),Vector3(7,0,10),Vector3(4.1,0,7.2),Vector3(1,0,3),Vector3(0,0,1)]
const BOARD := Vector3(-3.25,1.78,1.1)
const SCALE := Vector3(-1.25,1.1,.0)
const SLATE := Vector3(1.2,1.36,.22)
const PILE := Vector3(.2,1.09,.32)
const BARREL := Vector3(2.45,1.0,.6)
const KEEPER_SCALE := Vector3(-1.1,0,-.70)
const KEEPER_SLATE := Vector3(1.2,0,-.70)
static func height_at(x: float,z: float) -> float: return .035*sin(x*.3)*sin(z*.24)
static func guide_motion(point: Vector3,motion: Vector3) -> Vector3:
	var normal:=Vector3(point.x,0,point.z-1)
	var d:=normal.length();normal=normal.normalized()
	var push:=smoothstep(15,18,d)
	return motion-normal*maxf(0,motion.dot(normal))*push-normal*push*2.4
static func item_position(item: String) -> Vector3:
	var ids: Array=["flour","beans","pork","coffee","salt","hook","line","rod","crowbar","pick","shovel","boots","rocker","spear","rifle","powder","tent"]
	var outfit := {"pan":Vector3(-5.3,.36,2.7),"whiskey":Vector3(-4.5,.36,3.1),"strongbox":Vector3(-3.75,0,3.55),"bunk":Vector3(-6.3,0,2.2),"timber":Vector3(-6.0,0,4.1)}
	if outfit.has(item): return outfit[item]
	var i:=ids.find(item)
	if i<5: return Vector3(-1.5+i*.73,.48,-1.4)
	if i<8: return Vector3(-1.35+(i-5)*1.2,1.4,-1.4)
	return Vector3(-1.8+(i-8)*.44,2.12,-1.6)
