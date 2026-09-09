extends Node3D
const RATE := .25
var pouring := false
var poured := 0.0
var last_pour := 0.0
var weights := 0
var angle := 0.0
var counter: Node
func begin() -> void:
	if pouring: return
	pouring=true;poured=0
func advance(delta: float) -> void:
	if not pouring: return
	var sack: Node=get_node("/root/Sack")
	var amount:=minf(sack.ounces,RATE*maxf(0,delta))
	sack.ounces-=amount;poured+=amount;sack.changed.emit(sack.ounces)
	weights=floori(poured*.92/.25)
	angle=-.12+sin(poured*20)*.045
func release() -> void:
	if not pouring: return
	pouring=false;last_pour=poured;counter.credit_pour(poured);angle=0
