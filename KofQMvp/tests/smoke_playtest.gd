extends Node
## Windowed smoke playtest: Title → Training select → Fight, inject 1P input, save screenshots.
## godot --path KofQMvp --scene res://tests/smoke_playtest.tscn

const ARTIFACT_DIR := "/tmp/kofqmvp_smoke"

var _failed: int = 0
var _done: bool = false
var _log: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
	call_deferred("_persist_and_run")


func _persist_and_run() -> void:
	var tree := get_tree()
	var root := tree.root
	if tree.current_scene == self:
		root.remove_child(self)
		root.add_child(self)
		var dummy := Node.new()
		dummy.name = "SmokeDummy"
		root.add_child(dummy)
		tree.current_scene = dummy
	await _run()


func _run() -> void:
	_note("=== KofQMvp smoke playtest ===")
	var timer := get_tree().create_timer(35.0)
	timer.timeout.connect(_on_timeout)

	await _goto("res://scenes/title.tscn")
	await _shot("01_title")
	_assert(_scene_name() == "Title", "title scene loaded (%s)" % _scene_name())

	var title := get_tree().current_scene
	_assert(title.has_method("_on_training_pressed"), "title has training handler")
	title._on_training_pressed()
	await _wait_scene("CharSelect")
	await _shot("02_char_select")

	var sel := get_tree().current_scene
	for id in ["C01", "C02", "C03"]:
		sel._on_pick(id)
	for id in ["C04", "C03", "C02"]:
		sel._on_pick(id)
	await _idle(2)
	await _shot("03_char_select_picked")
	_assert(not sel.confirm_btn.disabled, "confirm enabled after 3+3 picks")
	sel._on_confirm_pressed()
	await _wait_scene("Fight")
	await _idle(8)
	await _shot("04_fight_idle")

	var fight := get_tree().current_scene
	_assert(fight != null and fight.get("sim") != null, "fight has sim")
	if fight == null or fight.get("sim") == null:
		_finish()
		return
	var sim: FightSimulator = fight.sim
	_assert(sim.p1 != null and sim.p1.char_def != null, "p1 spawned")
	_assert(sim.p2 != null and sim.p2.char_def != null, "p2 spawned")
	if sim.p1 == null or sim.p1.char_def == null or sim.p2 == null or sim.p2.char_def == null:
		_finish()
		return
	_assert(sim.p1.char_def.display_name == "赤焰", "p1 is 赤焰")
	var x0: float = sim.p1.pos.x
	var hp0: int = sim.p2.hp

	# Back walk (A): previously froze in BLOCK.
	Input.action_press("p1_left")
	await _idle(28)
	Input.action_release("p1_left")
	await _shot("04b_backwalk")
	_assert(sim.p1.pos.x < x0 - 8.0, "back walked (%.1f -> %.1f)" % [x0, sim.p1.pos.x])
	x0 = sim.p1.pos.x

	# Close distance so 5A can connect (~70px gap).
	Input.action_press("p1_right")
	for _i in 180:
		await get_tree().physics_frame
		if sim.p2.pos.x - sim.p1.pos.x <= 72.0:
			break
	Input.action_release("p1_right")
	await _shot("05_walk_right")
	_assert(sim.p1.pos.x > x0 + 8.0, "walked right (%.1f -> %.1f)" % [x0, sim.p1.pos.x])
	_assert(sim.p2.pos.x - sim.p1.pos.x <= 90.0, "closed gap to %.1f" % (sim.p2.pos.x - sim.p1.pos.x))

	await _tap_action("p1_lp", 8)
	await _idle(18)
	await _shot("06_after_5A")
	_assert(sim.p1.last_move_id != "", "p1 used a move (%s)" % sim.p1.last_move_id)
	_assert(sim.last_event != "", "5A connected (%s)" % sim.last_event)
	_note("tick=%d last_event=%s move=%s p2hp=%d now=%d" % [
		sim.tick, sim.last_event, sim.p1.last_move_id, hp0, sim.p2.hp
	])

	# Re-close after hitstun pushback, then jump over for a cross-up.
	await _idle(16)
	Input.action_press("p1_right")
	for _i in 90:
		await get_tree().physics_frame
		if sim.p2.pos.x - sim.p1.pos.x <= 68.0:
			break
	Input.action_press("p1_up")
	await _idle(10)
	Input.action_release("p1_up")
	await _idle(48)
	Input.action_release("p1_right")
	await _idle(8)
	await _shot("06b_crossover")
	_assert(sim.p1.pos.x > sim.p2.pos.x, "jumped behind (p1=%.1f p2=%.1f facing=%d)" % [sim.p1.pos.x, sim.p2.pos.x, sim.p1.facing])

	if fight.has_node("CanvasLayer/Hud/Info"):
		var info: Label = fight.get_node("CanvasLayer/Hud/Info")
		_assert(info.text.contains("Training"), "HUD shows Training (%s)" % info.text)

	Input.action_press("train_boxes")
	await _idle(2)
	Input.action_release("train_boxes")
	await _idle(4)
	await _shot("07_boxes")

	# Pause overlay
	var pause_ev := InputEventAction.new()
	pause_ev.action = "pause"
	pause_ev.pressed = true
	Input.parse_input_event(pause_ev)
	await _idle(4)
	await _shot("08_pause")
	_assert(fight.paused, "paused after Esc")
	fight._on_title_pressed()
	await _wait_scene("Title")
	await _shot("09_back_title")

	# Arcade: pick 3, enter fight vs CPU, run a moment
	get_tree().current_scene._on_arcade_pressed()
	await _wait_scene("CharSelect")
	sel = get_tree().current_scene
	for id in ["C01", "C04", "C02"]:
		sel._on_pick(id)
	sel._on_confirm_pressed()
	await _wait_scene("Fight")
	await _idle(20)
	await _shot("10_arcade_fight")
	fight = get_tree().current_scene
	sim = fight.sim
	_assert(GameSession.p2_is_cpu, "arcade p2 is cpu")
	_assert(sim.tick > 10, "arcade sim ticking (%d)" % sim.tick)
	await _tap_action("p1_lp", 6)
	await _idle(20)
	await _shot("11_arcade_after_hit")

	_finish()


func _goto(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await _idle(4)


func _wait_scene(expected: String, frames: int = 90) -> void:
	for _i in frames:
		await get_tree().process_frame
		if _scene_name() == expected:
			await _idle(3)
			return
	_assert(false, "timeout waiting for scene %s (got %s)" % [expected, _scene_name()])


func _scene_name() -> String:
	var s := get_tree().current_scene
	return s.name if s else "<null>"


func _idle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _hold_action(action: String, frames: int) -> void:
	Input.action_press(action)
	await _idle(frames)
	Input.action_release(action)


func _tap_action(action: String, frames: int) -> void:
	Input.action_press(action)
	await _idle(frames)
	Input.action_release(action)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		_assert(false, "screenshot %s got null image" % name)
		return
	var path := "%s/%s.png" % [ARTIFACT_DIR, name]
	var err := img.save_png(path)
	_assert(err == OK, "saved %s" % path)
	_note("shot %s %dx%d" % [name, img.get_width(), img.get_height()])


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_note("  OK  " + msg)
	else:
		_failed += 1
		_note("  FAIL " + msg)


func _note(msg: String) -> void:
	print(msg)
	_log.append(msg)


func _on_timeout() -> void:
	if _done:
		return
	_assert(false, "smoke playtest timed out at scene %s" % _scene_name())
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var report := "%s/report.txt" % ARTIFACT_DIR
	var f := FileAccess.open(report, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_log) + "\n")
		f.close()
	if _failed == 0:
		print("SMOKE PLAYTEST PASSED")
		get_tree().quit(0)
	else:
		print("SMOKE PLAYTEST FAILED: %d" % _failed)
		get_tree().quit(1)
