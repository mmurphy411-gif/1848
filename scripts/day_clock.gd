@tool
extends Node
## Unequal day/night lengths expressed in elapsed real seconds, independent of FPS.
signal advanced(hour: float)
const DAWN := 4.75
const DUSK := 20.5
const DAY_SECONDS := 1200.0
const NIGHT_SECONDS := 180.0
const CYCLE_SECONDS := DAY_SECONDS + NIGHT_SECONDS
var running := false
var elapsed := 0.0

func hour_at(seconds: float) -> float:
	var phase := fposmod(seconds, CYCLE_SECONDS)
	if phase <= DAY_SECONDS:
		return lerpf(DAWN, DUSK, phase / DAY_SECONDS)
	return fposmod(DUSK + (24.0-DUSK+DAWN)*(phase-DAY_SECONDS)/NIGHT_SECONDS,24.0)

func start(hour := DAWN) -> void:
	var h := fposmod(hour,24.0)
	elapsed = (h-DAWN)/(DUSK-DAWN)*DAY_SECONDS if h >= DAWN and h <= DUSK else DAY_SECONDS+fposmod(h-DUSK,24.0)/(24.0-DUSK+DAWN)*NIGHT_SECONDS
	running = true
	advanced.emit(hour_at(elapsed))

func advance(delta: float) -> void:
	if not running: return
	elapsed = fposmod(elapsed+maxf(delta,0.0),CYCLE_SECONDS)
	advanced.emit(hour_at(elapsed))

func _process(delta: float) -> void:
	advance(delta)
