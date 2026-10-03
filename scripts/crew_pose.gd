extends SkeletonModifier3D
## A hand's off-duty pose on top of whatever clip is playing (Wave C): arms hanging easy
## with relaxed hands instead of the clip's A-pose and spread fingers, and for the evening
## fire a seat (a round, a crate or a stool), forearms on the knees or a tin cup at the
## chest. Everything is computed from the rig's own bone rests and a few targets in the
## figure's frame (+Z forward, metres at height 1.0), so it is deterministic and costs no
## animation data. Runs before the build modifier, which only scales.
##
## kinds
##   ""          off (work clips keep their own grip on tools; walking)
##   "hands"     standing idle: arms close to the sides, palms in, fingers loosely curled
##   "fingers"   the clip's own arms (eating, lying down), fingers loosely curled
##   "cup"       standing, right hand holding a cup at the chest
##   "sit"       seated at `seat` height, forearms on the knees
##   "sit_cup"   seated, left forearm on the knee, right hand holding a cup
##   "sit_lean"  seated, leaning forward, both hands loosely clasped between the knees
const FINGERS:=["Index","Middle","Ring","Little"]
const JOINTS:=["Proximal","Intermediate","Distal"]
var kind:=""
## Seat surface above the man's ground, metres at height 1.0.
var seat:=.42
## Small per-man variation (seeded by the caller): lean, head turn, foot spread.
var lean:=0.0
var turn:=0.0
var spread:=0.0
## Finger curl (radians at the proximal joint; the others follow).
var curl:=.4
## Forearm turn (radians, left and right) that brings the clip's forward-facing palms to the thighs.
var twist:=-2.3
var twist_right:=2.3
var _bones: Dictionary={}
var _rest: Dictionary={}
var _ready_bones:=false

func configure(pose_kind: String, seat_height := .42, rng_seed := 0) -> void:
	kind=pose_kind;seat=seat_height
	var rng:=RandomNumberGenerator.new();rng.seed=rng_seed
	lean=rng.randf_range(-.06,.1);turn=rng.randf_range(-.25,.25);spread=rng.randf_range(-.04,.05)
	curl=rng.randf_range(.36,.46)
	active=kind!=""

func _lookup(skeleton: Skeleton3D) -> void:
	if _ready_bones: return
	_ready_bones=true
	for i in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(i)]=i
		_rest[i]=skeleton.get_bone_global_rest(i)

func _process_modification() -> void:
	var skeleton:=get_skeleton()
	if skeleton==null or kind=="": return
	_lookup(skeleton)
	match kind:
		"sit","sit_cup","sit_lean": _sit(skeleton)
		"cup":
			_hang(skeleton,"Left")
			_cup(skeleton,"Right",Vector3(-.13,1.18,.24))
		"hands":
			_hang(skeleton,"Left");_hang(skeleton,"Right")
	_relax(skeleton)

## Standing easy: the clip's A-pose arms (out from the body, palms forward) hang close to
## the sides with the palms turned in to the thighs and the elbow a little bent.
func _hang(skeleton: Skeleton3D, side: String) -> void:
	var s:=1.0 if side=="Left" else -1.0
	var upper:=_b(side+"UpperArm");var lower:=_b(side+"LowerArm")
	var d:=_global(skeleton,upper).basis.y.normalized()
	_aim(skeleton,upper,Vector3(d.x*.4+s*.035,d.y,d.z+.02))
	var f:=_global(skeleton,lower).basis.y.normalized()
	_aim(skeleton,lower,Vector3(f.x*.35+s*.03,f.y,f.z+.16+spread))
	# Turn the forearm about its own length so the palm faces the thigh.
	_turn(skeleton,lower,_global(skeleton,lower).basis.y,twist if side=="Left" else twist_right)

# ---------------------------------------------------------------- helpers

func _b(name: String) -> int: return _bones.get(name,-1)

func _global(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var t:=skeleton.get_bone_global_pose(bone);t.basis=t.basis.orthonormalized();return t

## Turn a bone so its +Y (the bone's length) points along `direction` (skeleton space).
func _aim(skeleton: Skeleton3D, bone: int, direction: Vector3) -> void:
	var g:=_global(skeleton,bone)
	var from:=g.basis.y.normalized();var to:=direction.normalized()
	if from.dot(to)>.99999: return
	var turned:=Basis(Quaternion(from,to))*g.basis
	_set_global_basis(skeleton,bone,turned)

func _set_global_basis(skeleton: Skeleton3D, bone: int, basis: Basis) -> void:
	var parent:=skeleton.get_bone_parent(bone)
	var parent_basis:=_global(skeleton,parent).basis if parent>=0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone,(parent_basis.inverse()*basis).get_rotation_quaternion())

## Rotate a bone about a skeleton-space axis on top of its current pose.
func _turn(skeleton: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone<0 or absf(angle)<1e-5: return
	var g:=_global(skeleton,bone)
	_set_global_basis(skeleton,bone,Basis(axis.normalized(),angle)*g.basis)

## Two-bone chain (upper, lower) reaching `target` with the middle joint bent toward `hint`.
func _reach(skeleton: Skeleton3D, upper: int, lower: int, end: int, target: Vector3, hint: Vector3) -> void:
	var a:=_global(skeleton,upper).origin
	var l1: float=(_rest[lower].origin-_rest[upper].origin).length()
	var l2: float=(_rest[end].origin-_rest[lower].origin).length()
	var to:=target-a
	var d:=clampf(to.length(),absf(l1-l2)+.01,l1+l2-.002)
	var dir:=to.normalized()
	var x: float=(l1*l1-l2*l2+d*d)/(2.0*d)
	var h:=sqrt(maxf(0.0,l1*l1-x*x))
	var side:=(hint-dir*hint.dot(dir)).normalized()
	var joint: Vector3=a+dir*x+side*h
	_aim(skeleton,upper,joint-a)
	_aim(skeleton,lower,a+dir*d-joint)

func _relax(skeleton: Skeleton3D) -> void:
	# A loose, half-closed hand: fingers curl toward the palm, the thumb tucks in.
	# Each finger joint flexes about its own -X (checked on the rig: +X bends the fingers
	# back). Starting from the rest pose drops the idle clip's spread claw.
	for side in ["Left","Right"]:
		# A hand hanging at the side is barely closed; one on a knee or a cup, more.
		var hanging: bool=kind=="hands" or (kind=="cup" and side=="Left")
		var c: float=curl*(.55 if hanging else 1.0)
		for f in FINGERS.size():
			for j in JOINTS.size():
				var bone:=_b(side+FINGERS[f]+JOINTS[j])
				if bone<0: continue
				var amount: float=c*[.5,1.2,.9][j]*(1.0+f*.12)
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-amount))
		for j in JOINTS.size():
			var bone:=_b(side+"Thumb"+JOINTS[j])
			if bone<0: continue
			skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-c*[.3,.35,.25][j]))

## Standing with a cup: the upper arm hangs, the forearm comes up and in.
func _cup(skeleton: Skeleton3D, side: String, wrist: Vector3) -> void:
	var s:=1.0 if side=="Left" else -1.0
	_reach(skeleton,_b(side+"UpperArm"),_b(side+"LowerArm"),_b(side+"Hand"),wrist,Vector3(s*.5,-.3,-1.0))
	# Wrist level, palm toward the midline, cup upright.
	var hand:=_b(side+"Hand")
	var g:=_global(skeleton,hand)
	var up:=Vector3(-s*.25,-.15,1.0).normalized()
	_set_global_basis(skeleton,hand,Basis(Quaternion(g.basis.y.normalized(),up))*g.basis)

func _sit(skeleton: Skeleton3D) -> void:
	var hips:=_b("Hips")
	# The hip joints sit 0.11 m above the seat; the pelvis is back over the seat's middle.
	var hip_y:=seat+.11
	skeleton.set_bone_pose_position(hips,Vector3(0,hip_y,-.02))
	skeleton.set_bone_pose_rotation(hips,skeleton.get_bone_rest(hips).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-.12))
	var ankle_y: float=_rest[_b("LeftFoot")].origin.y
	var thigh: float=(_rest[_b("LeftLowerLeg")].origin-_rest[_b("LeftUpperLeg")].origin).length()
	for side in ["Left","Right"]:
		var s:=1.0 if side=="Left" else -1.0
		var up:=_b(side+"UpperLeg");var low:=_b(side+"LowerLeg");var foot:=_b(side+"Foot")
		# Feet under the knees (a little ahead on a low seat), slightly apart.
		var forward:=thigh+.02+maxf(0.0,.42-seat)*.5
		var target:=Vector3(s*(.15+spread),ankle_y,forward)
		_reach(skeleton,up,low,foot,target,Vector3(s*.15,.2,1.0))
		# Feet flat on the ground, toes a little out.
		_set_global_basis(skeleton,foot,Basis(Vector3.UP,s*.18)*_rest[foot].basis)
	# Trunk: lean toward the fire, head a little down and turned.
	var forward_lean: float={"sit":.18,"sit_cup":.08,"sit_lean":.42}.get(kind,.15)+lean
	_turn(skeleton,_b("Spine"),Vector3.RIGHT,forward_lean*.55)
	_turn(skeleton,_b("Chest"),Vector3.RIGHT,forward_lean*.45)
	_turn(skeleton,_b("Neck"),Vector3.RIGHT,-forward_lean*.35+.1)
	_turn(skeleton,_b("Head"),Vector3.UP,turn)
	for side in ["Left","Right"]:
		var s:=1.0 if side=="Left" else -1.0
		var knee:=_global(skeleton,_b(side+"LowerLeg")).origin
		var wrist: Vector3
		var hint:=Vector3(s*.6,-.2,-1.0)
		if kind=="sit_lean":
			# Hands loosely together between the knees.
			wrist=Vector3(s*.05,knee.y-.06,knee.z-.04)
			hint=Vector3(s*1.0,-.4,-.3)
		elif kind=="sit_cup" and side=="Right":
			_cup(skeleton,side,Vector3(-.1,_global(skeleton,_b("Chest")).origin.y-.02,.36))
			continue
		else:
			# Forearm along the thigh, wrist just behind the knee.
			wrist=knee+Vector3(-s*.02,.08,-.10)
		_reach(skeleton,_b(side+"UpperArm"),_b(side+"LowerArm"),_b(side+"Hand"),wrist,hint)
		var hand:=_b(side+"Hand")
		var g:=_global(skeleton,hand)
		var fore:=_global(skeleton,_b(side+"LowerArm")).basis.y.normalized()
		# The hand droops over the knee, continuing the forearm.
		var droop:=(fore+Vector3(0,-.9,.3)).normalized()
		_set_global_basis(skeleton,hand,Basis(Quaternion(g.basis.y.normalized(),droop))*g.basis)
