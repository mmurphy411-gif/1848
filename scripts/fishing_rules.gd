extends RefCounted
const Layout=preload("res://scripts/claim_layout.gd")
# Notes-round diagnostic: 6% lost 7 hooks; 8% loses 11 with the same policy.
const SUNK_SNAG_CHANCE := .08
static func snag_chance(point: Vector3,bait: String) -> float:
	for b in Layout.BOULDERS:
		if Vector2(point.x-b.x,point.z-b.y).length()<b.z+1: return .25
	for b in Layout.BEDROCK:
		if absf(point.x-b.x)<b.z*.5+1 and absf(point.z-b.y)<b.w*.5+1: return .25
	return 0.0 if bait=="grasshopper" else SUNK_SNAG_CHANCE
