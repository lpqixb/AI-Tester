class_name InputBuffer
extends RefCounted
## Ring buffer of recent FightInput frames for command detection.

var _frames: Array[FightInput] = []
var capacity: int = 15


func push(sample: FightInput) -> void:
	_frames.push_back(sample)
	while _frames.size() > capacity:
		_frames.pop_front()


func latest() -> FightInput:
	if _frames.is_empty():
		return FightInput.new()
	return _frames[_frames.size() - 1]


func history() -> Array[FightInput]:
	return _frames


## Rising-edge double tap of any dir in `dirs` within `window` frames (KOF 66/44).
func just_double_tap(dirs: Array, window: int = 12) -> bool:
	if _frames.size() < 3:
		return false
	var latest: int = _frames[_frames.size() - 1].dir
	if not dirs.has(latest):
		return false
	# This frame must be a tap (previous frame was not that dir).
	if dirs.has(_frames[_frames.size() - 2].dir):
		return false
	var start: int = maxi(0, _frames.size() - window)
	var presses := 0
	var prev := -1
	if start > 0:
		prev = _frames[start - 1].dir
	for i in range(start, _frames.size()):
		var d: int = _frames[i].dir
		if dirs.has(d) and not dirs.has(prev):
			presses += 1
		prev = d
	return presses >= 2


## Very small helper: returns true if dir sequence appears in order within window.
func match_dirs(sequence: Array[int], window: int = 8) -> bool:
	if sequence.is_empty() or _frames.is_empty():
		return false
	var start: int = maxi(0, _frames.size() - window)
	var si := 0
	for i in range(start, _frames.size()):
		if _frames[i].dir == sequence[si]:
			si += 1
			if si >= sequence.size():
				return true
	return false
