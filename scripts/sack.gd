extends Node

signal changed(ounces: float)
const THRESHOLDS := [0.0, 0.25, 1.0, 3.0, 8.0]
var ounces := 0.0

func add(amount: float) -> void:
	ounces += maxf(amount, 0.0)
	changed.emit(ounces)

func stage() -> int:
	for index in range(THRESHOLDS.size() - 1, -1, -1):
		if ounces >= THRESHOLDS[index]:
			return index
	return 0
