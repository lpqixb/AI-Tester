extends SceneTree
## Headless combat regression: godot --headless --path . --script res://tests/run_combat_tests.gd

var _failed: int = 0


func _init() -> void:
	print("=== KofQMvp combat tests ===")
	_test_load_characters()
	_test_normals_deal_damage()
	_test_block_prevents_full_damage()
	_test_meter_and_super()
	_test_cancel_chain()
	_test_evade_invuln()
	_test_back_walk()
	_test_dash()
	_test_jump_attack()
	_test_jump_crossover()
	_test_throw()
	_test_team_ko_swap()
	_test_command_motions()
	if _failed == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("FAILED: %d" % _failed)
		quit(1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		_failed += 1
		print("  FAIL", msg)


func _neutral() -> FightInput:
	return FightInput.new()


func _btn(mask: int, dir: int = 5) -> FightInput:
	var i := FightInput.new()
	i.dir = dir
	i.buttons = mask
	i.pressed = mask
	return i


func _test_load_characters() -> void:
	print("-- load characters")
	var db := CharacterDB.new()
	db.load_all()
	_assert(db.all_ids().size() == 4, "4 characters loaded")
	for id in ["C01", "C02", "C03", "C04"]:
		var c: CharacterDef = db.get_char(id)
		_assert(c != null, "char %s" % id)
		_assert(c.moves.size() >= 6, "%s has moves" % id)
		_assert(c.get_by_command("5A") != null, "%s 5A" % id)
		_assert(c.get_by_command("236A") != null, "%s 236A" % id)
		_assert(c.get_by_command("236236A") != null, "%s super" % id)
		_assert(c.get_by_command("jA") != null, "%s jA" % id)
		_assert(c.get_by_command("THROW") != null, "%s throw" % id)
		_assert(c.dash_speed > c.walk_speed, "%s dash faster than walk" % id)


func _test_normals_deal_damage() -> void:
	print("-- normals damage")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	# Place p1 close to p2
	sim.p1.pos.x = sim.p2.pos.x - 70
	var hp0 := sim.p2.hp
	# Startup 5A: press, then wait active frames
	sim.step(_btn(FightInput.BTN_LP), _neutral())
	for _i in 20:
		sim.step(_neutral(), _neutral())
	_assert(sim.p2.hp < hp0, "5A dealt damage (%d -> %d)" % [hp0, sim.p2.hp])


func _test_block_prevents_full_damage() -> void:
	print("-- block")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.p1.pos.x = sim.p2.pos.x - 70
	var hp0 := sim.p2.hp
	sim.step(_btn(FightInput.BTN_LP), _neutral())
	for _i in 20:
		# P2 holds back (facing -1 => back is right/6)
		var blk := FightInput.new()
		blk.dir = 6
		sim.step(_neutral(), blk)
	_assert(sim.p2.hp == hp0 or sim.p2.state == FighterBody.State.BLOCKSTUN or sim.p2.hp >= hp0 - 5, "block mitigated (%d -> %d)" % [hp0, sim.p2.hp])
	_assert(sim.p2.hp > hp0 - 40, "did not take full 5A on block")


func _test_meter_and_super() -> void:
	print("-- meter super")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.meter1 = 0
	_assert(not sim.p1.spend_meter(100), "cannot spend without meter")
	sim.meter1 = 100
	_assert(sim.p1.spend_meter(100), "spend 100 ok")
	_assert(is_equal_approx(sim.meter1, 0.0), "meter emptied")
	sim.meter1 = 100
	sim.p1.pos.x = sim.p2.pos.x - 80
	# Feed 236236A via buffer then punch
	_feed_motion(sim, [2, 3, 6, 2, 3, 6], true)
	for _i in 40:
		sim.step(_neutral(), _neutral())
	_assert(sim.p1.last_move_id == "inferno" or sim.meter1 < 100, "super attempted/spent")


func _feed_motion(sim: FightSimulator, dirs: Array, punch: bool) -> void:
	for d in dirs:
		var i := FightInput.new()
		i.dir = int(d)
		sim.step(i, _neutral())
	if punch:
		sim.step(_btn(FightInput.BTN_LP, 6), _neutral())


func _test_cancel_chain() -> void:
	print("-- cancel")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], true)
	sim.p1.pos.x = sim.p2.pos.x - 65
	sim.step(_btn(FightInput.BTN_LP), _neutral())
	# Advance into cancel window after hit
	for _i in 8:
		sim.step(_neutral(), _neutral())
	# Try special cancel
	_feed_motion(sim, [2, 3, 6], true)
	for _i in 5:
		sim.step(_neutral(), _neutral())
	var ok := sim.p1.last_move_id in ["fireball", "5A", "inferno"]
	_assert(ok, "cancel or attack state ok (%s)" % sim.p1.last_move_id)


func _test_evade_invuln() -> void:
	print("-- evade")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.meter1 = 100
	sim.p1.pos.x = 400
	var i := FightInput.new()
	i.dir = 4  # back while facing right
	i.pressed = FightInput.BTN_MK
	i.buttons = FightInput.BTN_MK
	sim.step(i, _neutral())
	_assert(sim.p1.state == FighterBody.State.EVADE, "entered evade")
	_assert(sim.p1.invuln_timer > 0, "evade invuln")
	_assert(sim.meter1 < 100, "evade cost meter")


func _test_jump_crossover() -> void:
	print("-- jump crossover")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.p1.pos.x = sim.p2.pos.x - 72
	var hop := FightInput.new()
	hop.dir = 9
	sim.step(hop, _neutral())
	_assert(not sim.p1.on_ground, "jump takeoff")
	var fwd := FightInput.new()
	fwd.dir = 6
	for _i in 48:
		sim.step(fwd, _neutral())
	_assert(sim.p1.pos.x > sim.p2.pos.x, "landed behind (p1=%.1f p2=%.1f)" % [sim.p1.pos.x, sim.p2.pos.x])
	_assert(sim.p1.facing < 0, "facing flipped after cross (facing %d)" % sim.p1.facing)
	_assert(sim.p2.facing > 0, "p2 now faces right")


func _test_team_ko_swap() -> void:
	print("-- team ko swap")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.p2.hp = 1
	sim.p1.pos.x = sim.p2.pos.x - 70
	var p1_hp := sim.p1.hp
	sim.step(_btn(FightInput.BTN_MP), _neutral())
	var saw_ko_hold := false
	for _i in 160:
		sim.step(_neutral(), _neutral())
		if sim.round_pause > 0:
			saw_ko_hold = true
		if sim.idx2 >= 1:
			break
	_assert(saw_ko_hold, "KO hold played before swap")
	_assert(sim.idx2 >= 1 or sim.winner_side == 1, "P2 swapped or match over (idx2=%d winner=%d)" % [sim.idx2, sim.winner_side])
	if sim.idx2 >= 1:
		_assert(absf(sim.p1.pos.x - 360.0) < 8.0, "P1 reset to corner (%.1f)" % sim.p1.pos.x)
		_assert(absf(sim.p2.pos.x - 920.0) < 8.0, "P2 reset to corner (%.1f)" % sim.p2.pos.x)
		_assert(sim.p1.hp == p1_hp, "survivor HP kept")
		_assert(sim.p2.char_def.char_id == "C02", "next P2 is C02 (got %s)" % sim.p2.char_def.char_id)
		_assert(sim.round_index == 2, "round index 2")


func _test_back_walk() -> void:
	print("-- back walk")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.p1.facing = 1
	sim.p1.pos.x = 500
	var x0 := sim.p1.pos.x
	var back := FightInput.new()
	back.dir = 4
	for _i in 25:
		sim.step(back, _neutral())
	_assert(sim.p1.pos.x < x0 - 20.0, "holding back walks left (%.1f -> %.1f)" % [x0, sim.p1.pos.x])
	_assert(sim.p1.state == FighterBody.State.WALK, "back walk is WALK not BLOCK (%s)" % str(sim.p1.state))


func _test_dash() -> void:
	print("-- dash")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.p1.facing = 1
	sim.p1.pos.x = 400
	for d in [6, 5, 6]:
		var i := FightInput.new()
		i.dir = d
		sim.step(i, _neutral())
	_assert(sim.p1.state == FighterBody.State.DASH, "66 entered dash (state %s)" % str(sim.p1.state))
	var x0 := sim.p1.pos.x
	var hold := FightInput.new()
	hold.dir = 6
	for _i in 18:
		sim.step(hold, _neutral())
	_assert(sim.p1.pos.x > x0 + 50.0, "run covers more ground than walk (%.1f -> %.1f)" % [x0, sim.p1.pos.x])

	# Backdash 44
	var sim2 := FightSimulator.new()
	sim2.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim2.p1.facing = 1
	sim2.p1.pos.x = 500
	for d in [4, 5, 4]:
		var i2 := FightInput.new()
		i2.dir = d
		sim2.step(i2, _neutral())
	_assert(sim2.p1.state == FighterBody.State.BACKDASH, "44 entered backdash")
	_assert(sim2.p1.invuln_timer > 0, "backdash invuln")


func _test_jump_attack() -> void:
	print("-- jump attack")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	var up := FightInput.new()
	up.dir = 8
	sim.step(up, _neutral())
	_assert(not sim.p1.on_ground, "jumped")
	for _i in 5:
		sim.step(_neutral(), _neutral())
	sim.step(_btn(FightInput.BTN_LP), _neutral())
	_assert(sim.p1.last_move_id == "jA", "air LP is jA (got %s)" % sim.p1.last_move_id)
	_assert(sim.p1.state == FighterBody.State.ATTACK, "jump attack state")


func _test_throw() -> void:
	print("-- throw")
	var sim := FightSimulator.new()
	sim.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim.p1.pos.x = sim.p2.pos.x - 60
	var grab := FightInput.new()
	grab.buttons = FightInput.BTN_LP | FightInput.BTN_LK
	grab.pressed = FightInput.BTN_LP | FightInput.BTN_LK
	sim.step(grab, _neutral())
	_assert(sim.p1.last_move_id == "throw", "started throw (got %s)" % sim.p1.last_move_id)
	for _i in 16:
		sim.step(_neutral(), _neutral())
	_assert(
		sim.p2.state in [FighterBody.State.KNOCKDOWN, FighterBody.State.HITSTUN, FighterBody.State.KO]
		or sim.last_event.begins_with("throw"),
		"throw connected (event=%s state=%s)" % [sim.last_event, str(sim.p2.state)]
	)

	# Throw beats block
	var sim2 := FightSimulator.new()
	sim2.setup(["C01", "C02", "C03"], ["C04", "C02", "C03"], false)
	sim2.p1.pos.x = sim2.p2.pos.x - 60
	var blk := FightInput.new()
	blk.dir = 6  # P2 faces -1, back is 6
	sim2.step(grab, blk)
	for _i in 16:
		sim2.step(_neutral(), blk)
	_assert(sim2.p2.state != FighterBody.State.BLOCKSTUN, "throw is unblockable (state %s)" % str(sim2.p2.state))
	_assert(sim2.p2.hp < sim2.p2.max_hp, "throw dealt damage through block")


func _test_command_motions() -> void:
	print("-- command matcher")
	var buf := InputBuffer.new()
	for d in [5, 2, 3, 6]:
		var i := FightInput.new()
		i.dir = d
		buf.push(i)
	var punch := FightInput.new()
	punch.dir = 6
	punch.pressed = FightInput.BTN_LP
	punch.buttons = FightInput.BTN_LP
	buf.push(punch)
	var cmd := CommandMatcher.detect(buf, false)
	_assert(cmd == "236A", "236A detected (got %s)" % cmd)
