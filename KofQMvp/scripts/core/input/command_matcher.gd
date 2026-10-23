class_name CommandMatcher
extends RefCounted
## Matches fighting-game motion commands against an InputBuffer.


static func punch_strength(inp: FightInput) -> String:
	## A = light punch, C = medium punch (used in normals and as +P for motions).
	if inp.just_pressed(FightInput.BTN_LP):
		return "A"
	if inp.just_pressed(FightInput.BTN_MP):
		return "C"
	return ""


static func kick_strength(inp: FightInput) -> String:
	if inp.just_pressed(FightInput.BTN_LK) or inp.just_pressed(FightInput.BTN_MK):
		return "B"
	return ""


static func detect(buffer: InputBuffer, crouching: bool, airborne: bool = false) -> String:
	var latest := buffer.latest()
	# Throw: LP+LK (J+K). Must be on the ground; beats walking 5A.
	if not airborne and latest.is_held(FightInput.BTN_LP) and latest.is_held(FightInput.BTN_LK):
		if latest.just_pressed(FightInput.BTN_LP) or latest.just_pressed(FightInput.BTN_LK):
			return "THROW"

	var punch := punch_strength(latest)
	var kick := kick_strength(latest)
	if punch == "" and kick == "":
		return ""

	if airborne:
		if punch == "C":
			return "jC"
		if punch != "":
			return "jA"
		if kick != "":
			return "jB"
		return ""

	# Motions consume any punch button as "A" strength for MVP command table.
	if punch != "":
		if _has_motion(buffer, [2, 3, 6, 2, 3, 6], 14):
			return "236236A"
		if _has_motion(buffer, [2, 3, 6], 10):
			return "236A"
		if _has_motion(buffer, [6, 2, 3], 10):
			return "623A"
		if _has_motion(buffer, [2, 1, 4], 10):
			return "214A"
		if punch == "C":
			return "5C"
		return "2A" if crouching else "5A"

	if kick != "":
		return "2B" if crouching else "5B"
	return ""


static func _has_motion(buffer: InputBuffer, sequence: Array, window: int) -> bool:
	var hist := buffer.history()
	if hist.is_empty():
		return false
	var start: int = maxi(0, hist.size() - window)
	var si := 0
	for i in range(start, hist.size()):
		var d: int = hist[i].dir
		if _dir_matches(d, sequence[si]):
			si += 1
			if si >= sequence.size():
				return true
	return false


static func _dir_matches(actual: int, expected: int) -> bool:
	# Allow adjacent diagonals for leniency on cardinals in motions.
	if actual == expected:
		return true
	match expected:
		2:
			return actual in [1, 2, 3]
		6:
			return actual in [3, 6, 9]
		4:
			return actual in [1, 4, 7]
		3:
			return actual in [3, 6, 2]
		1:
			return actual in [1, 2, 4]
		_:
			return false
