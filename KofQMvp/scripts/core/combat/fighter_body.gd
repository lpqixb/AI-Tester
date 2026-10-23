class_name FighterBody
extends RefCounted
## Full fighter state for Phase 1–5 combat simulation.

enum State {
	IDLE, WALK, CROUCH, JUMP, ATTACK, BLOCK, BLOCKSTUN, HITSTUN, KNOCKDOWN, EVADE, BACKDASH, DASH, INTRO, KO
}

var player_id: int = 0
var char_def: CharacterDef
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing: int = 1
var state: State = State.IDLE
var hp: int = 1000
var max_hp: int = 1000
var on_ground: bool = true
var crouching: bool = false

var walk_speed: float = 220.0
var back_walk_speed: float = 180.0
var dash_speed: float = 400.0
var jump_speed: float = 520.0
var gravity: float = 1600.0
var ground_y: float = 560.0
var stage_left: float = 80.0
var stage_right: float = 1200.0
var hurt := Aabb2.new(-28, -120, 56, 120)

var hitstop: int = 0
var stun_timer: int = 0
var invuln_timer: int = 0
var armor_timer: int = 0
var guard_meter: float = 100.0
var juggle: int = 0

var current_move: MoveDef = null
var move_frame: int = 0
var move_has_hit: bool = false
var spawned_projectile: bool = false
var pending_projectile: Dictionary = {}

var input_buffer := InputBuffer.new()
var last_move_id: String = ""
var debug_hitboxes: Array = []

# Team meter is owned by Match side; fighter holds a reference callback via sim.
var meter_ref: Callable = Callable()


func apply_character(cdef: CharacterDef, bal: Dictionary) -> void:
	char_def = cdef
	max_hp = cdef.max_hp
	hp = cdef.max_hp
	walk_speed = cdef.walk_speed
	back_walk_speed = cdef.back_walk_speed
	dash_speed = cdef.dash_speed
	jump_speed = cdef.jump_speed
	gravity = cdef.gravity
	hurt = Aabb2.new(cdef.hurt.x, cdef.hurt.y, cdef.hurt.w, cdef.hurt.h)
	ground_y = float(bal.get("ground_y", 560))
	stage_left = float(bal.get("stage_left", 80))
	stage_right = float(bal.get("stage_right", 1200))


func reset(at: Vector2, face: int, intro_invuln: int = 0, refill_hp: bool = true) -> void:
	pos = at
	vel = Vector2.ZERO
	facing = face
	state = State.INTRO if intro_invuln > 0 else State.IDLE
	if refill_hp:
		hp = max_hp
	on_ground = true
	crouching = false
	hitstop = 0
	stun_timer = 0
	invuln_timer = intro_invuln
	armor_timer = 0
	guard_meter = 100.0
	juggle = 0
	current_move = null
	move_frame = 0
	move_has_hit = false
	spawned_projectile = false
	pending_projectile.clear()
	last_move_id = ""
	input_buffer = InputBuffer.new()
	debug_hitboxes.clear()


func get_meter() -> float:
	if meter_ref.is_valid():
		return float(meter_ref.call("get"))
	return 0.0


func add_meter(amount: float) -> void:
	if meter_ref.is_valid():
		meter_ref.call("add", amount)


func spend_meter(amount: float) -> bool:
	if meter_ref.is_valid():
		return bool(meter_ref.call("spend", amount))
	return false


func can_act() -> bool:
	return state in [State.IDLE, State.WALK, State.CROUCH, State.JUMP, State.BLOCK, State.DASH]


func is_invulnerable() -> bool:
	return invuln_timer > 0 or state == State.INTRO


func world_hurtbox() -> Aabb2:
	var h := hurt
	if crouching or state == State.CROUCH or state == State.BLOCK and crouching:
		h = Aabb2.new(hurt.x, hurt.y + hurt.h * 0.35, hurt.w, hurt.h * 0.65)
	var local := h.flipped(facing)
	return Aabb2.new(pos.x + local.x, pos.y + local.y, local.w, local.h)


func active_attack_boxes() -> Array:
	debug_hitboxes.clear()
	var out: Array = []
	if current_move == null or state != State.ATTACK:
		return out
	for hb in current_move.active_hitboxes(move_frame):
		var local := Aabb2.new(float(hb.x), float(hb.y), float(hb.w), float(hb.h)).flipped(facing)
		var world := Aabb2.new(pos.x + local.x, pos.y + local.y, local.w, local.h)
		out.append({"box": world, "move": current_move})
		debug_hitboxes.append(world)
	return out


func push_input(inp: FightInput) -> void:
	input_buffer.push(inp)


func tick(inp: FightInput, dt: float, bal: Dictionary) -> void:
	push_input(inp)
	if hitstop > 0:
		hitstop -= 1
		return

	if invuln_timer > 0:
		invuln_timer -= 1
	if armor_timer > 0:
		armor_timer -= 1

	if state == State.KO:
		vel.x = move_toward(vel.x, 0.0, 800.0 * dt)
		_integrate(dt)
		return

	if state == State.INTRO:
		if invuln_timer <= 0:
			state = State.IDLE
		_integrate(dt)
		return

	if state in [State.HITSTUN, State.BLOCKSTUN, State.KNOCKDOWN]:
		stun_timer -= 1
		if state == State.KNOCKDOWN:
			vel.x = move_toward(vel.x, 0.0, 600.0 * dt)
			if stun_timer <= 0 and on_ground:
				state = State.IDLE
				juggle = 0
		elif stun_timer <= 0:
			state = State.CROUCH if crouching else State.IDLE
			juggle = 0
		_integrate(dt)
		return

	if state == State.EVADE or state == State.BACKDASH:
		stun_timer -= 1
		if state == State.EVADE:
			vel.x = float(facing) * -walk_speed * 1.4
		else:
			vel.x = move_toward(vel.x, 0.0, 280.0 * dt)
		if stun_timer <= 0:
			state = State.IDLE
			vel.x = 0.0
		_integrate(dt)
		return

	if state == State.ATTACK:
		_tick_attack(inp, dt, bal)
		return

	_tick_neutral(inp, dt, bal)


func _tick_neutral(inp: FightInput, dt: float, bal: Dictionary) -> void:
	_face_logic()
	crouching = on_ground and inp.dir in [1, 2, 3]

	# Evade: hold back + press MK (costs meter, invuln frames).
	if on_ground and _is_holding_back(inp) and inp.just_pressed(FightInput.BTN_MK):
		_try_evade(bal)
		_integrate(dt)
		return

	var cmd := CommandMatcher.detect(input_buffer, crouching, not on_ground)
	if cmd != "" and _try_start_move(cmd, false):
		_integrate(dt)
		return

	# 66 run / 44 backdash. Holding back still auto-blocks via wants_block.
	if on_ground:
		var tap_window := int(bal.get("double_tap_window", 12))
		var fwd := 6 if facing > 0 else 4
		var back := 4 if facing > 0 else 6
		if input_buffer.just_double_tap([back], tap_window):
			_start_backdash(bal)
			_integrate(dt)
			return
		if input_buffer.just_double_tap([fwd], tap_window):
			state = State.DASH
			last_move_id = "dash"

	if state == State.DASH and on_ground:
		var holding_fwd := (facing > 0 and inp.dir in [6, 9]) or (facing < 0 and inp.dir in [4, 7])
		if inp.dir in [7, 8, 9]:
			vel.x = float(facing) * dash_speed * 0.55
			vel.y = -jump_speed
			on_ground = false
			crouching = false
			state = State.JUMP
			_integrate(dt)
			return
		if holding_fwd:
			vel.x = float(facing) * dash_speed
			crouching = false
			_integrate(dt)
			return
		state = State.IDLE
		vel.x = 0.0

	var axis := _axis(inp)
	if on_ground:
		if inp.dir in [7, 8, 9]:
			vel.y = -jump_speed
			on_ground = false
			crouching = false
			state = State.JUMP
			# Extra forward speed so a close jump can clear the opponent.
			vel.x = float(axis) * walk_speed * 1.35
		elif crouching:
			vel.x = 0.0
			state = State.CROUCH
		elif axis != 0:
			var backward := (axis < 0 and facing > 0) or (axis > 0 and facing < 0)
			vel.x = float(axis) * (back_walk_speed if backward else walk_speed)
			state = State.WALK
		else:
			vel.x = 0.0
			state = State.IDLE
	else:
		# Keep jump momentum so you can land behind; air control steers, does not snap.
		var target := float(axis) * walk_speed * 0.9
		if axis == 0:
			vel.x = move_toward(vel.x, 0.0, walk_speed * 1.1 * dt)
		else:
			vel.x = move_toward(vel.x, target, walk_speed * 6.0 * dt)
		state = State.JUMP

	_integrate(dt)


func _tick_attack(inp: FightInput, dt: float, bal: Dictionary) -> void:
	move_frame += 1
	if current_move and current_move.invuln_startup > 0 and move_frame <= current_move.invuln_startup:
		invuln_timer = maxi(invuln_timer, 1)
	if current_move and current_move.armor_frames > 0 and move_frame <= current_move.armor_frames:
		armor_timer = maxi(armor_timer, 1)

	# Spawn projectile once at first active frame
	if current_move and current_move.attribute == "projectile" and not spawned_projectile:
		if move_frame >= current_move.startup:
			spawned_projectile = true
			pending_projectile = current_move.projectile.duplicate()
			pending_projectile["move"] = current_move

	# Teleport on start of active
	if current_move and current_move.teleport_x != 0.0 and move_frame == current_move.startup:
		pos.x += float(facing) * current_move.teleport_x
		pos.x = clampf(pos.x, stage_left, stage_right)

	# Cancel into special/super (ground only for now)
	var cmd := CommandMatcher.detect(input_buffer, crouching, not on_ground)
	if cmd != "" and _can_cancel_into(cmd):
		if _try_start_move(cmd, true):
			_integrate(dt)
			return

	var was_air := not on_ground
	if move_frame > current_move.total_frames():
		current_move = null
		move_frame = 0
		if not on_ground:
			state = State.JUMP
		else:
			state = State.CROUCH if crouching else State.IDLE
			vel.x = 0.0
	_integrate(dt)
	if was_air and on_ground and state == State.ATTACK:
		current_move = null
		move_frame = 0
		state = State.IDLE
		vel.x *= 0.4


func _try_start_move(cmd: String, is_cancel: bool) -> bool:
	if char_def == null:
		return false
	var move: MoveDef = char_def.get_by_command(cmd)
	if move == null:
		return false
	if move.has_tag("jump") and on_ground:
		return false
	if (move.is_throw() or move.has_tag("throw")) and not on_ground:
		return false
	if move.meter_cost > 0.0 and not spend_meter(move.meter_cost):
		return false
	current_move = move
	move_frame = 0
	move_has_hit = false
	spawned_projectile = false
	pending_projectile.clear()
	state = State.ATTACK
	last_move_id = move.move_id
	if on_ground:
		vel.x = 0.0
	return true


func _can_cancel_into(cmd: String) -> bool:
	if current_move == null or not move_has_hit:
		return false
	if move_frame < current_move.cancel_from_frame or move_frame > current_move.cancel_to_frame:
		return false
	var next: MoveDef = char_def.get_by_command(cmd)
	if next == null:
		return false
	for tag in current_move.cancel_into:
		if tag == "special" and next.is_special():
			return true
		if tag == "super" and next.is_super():
			return true
	return false


func _start_backdash(bal: Dictionary) -> void:
	state = State.BACKDASH
	stun_timer = int(bal.get("backdash_frames", 18))
	invuln_timer = int(bal.get("backdash_invuln_frames", 10))
	current_move = null
	last_move_id = "backdash"
	vel.x = float(facing) * -float(bal.get("backdash_speed", 420))


func _try_evade(bal: Dictionary) -> void:
	var cost := float(bal.get("evade_meter_cost", 50))
	if not spend_meter(cost):
		return
	state = State.EVADE
	stun_timer = int(bal.get("evade_frames", 20))
	invuln_timer = int(bal.get("evade_invuln_frames", 14))
	current_move = null
	last_move_id = "evade"


func take_hit(move: MoveDef, attacker_facing: int, blocked: bool) -> void:
	if armor_timer > 0 and not blocked:
		armor_timer = 0
		return
	move_has_hit = false
	current_move = null
	move_frame = 0
	pending_projectile.clear()
	var dir := float(attacker_facing)
	if blocked:
		var chip := move.chip_damage
		hp = maxi(1, hp - chip)  # chip cannot KO in MVP
		stun_timer = move.blockstun
		state = State.BLOCKSTUN
		vel.x = dir * move.pushback_block * 8.0
		guard_meter = maxf(0.0, guard_meter - move.guard_crush)
		if guard_meter <= 0.0:
			guard_meter = 100.0
			stun_timer = move.hitstun + 10
			state = State.HITSTUN
			hp = maxi(0, hp - move.damage / 2)
		hitstop = move.hitstop
		return

	var dmg := move.damage
	if juggle > 0:
		dmg = int(dmg * maxf(0.35, 1.0 - 0.15 * float(juggle)))
	hp = maxi(0, hp - dmg)
	hitstop = move.hitstop
	vel.x = dir * move.pushback_hit * 8.0
	if move.launch:
		vel.y = -420.0
		on_ground = false
		juggle += 1
	if move.knockdown or hp <= 0:
		state = State.KNOCKDOWN if hp > 0 else State.KO
		stun_timer = 40 if hp > 0 else 9999
	else:
		state = State.HITSTUN
		stun_timer = move.hitstun
	if hp <= 0:
		state = State.KO
		stun_timer = 9999


func mark_hit_connected() -> void:
	move_has_hit = true


func _is_holding_back(inp: FightInput) -> bool:
	if facing > 0:
		return inp.dir in [1, 4, 7]
	return inp.dir in [3, 6, 9]


func _axis(inp: FightInput) -> int:
	if inp.dir in [1, 4, 7]:
		return -1
	if inp.dir in [3, 6, 9]:
		return 1
	return 0


func _face_logic() -> void:
	# Facing updated by simulator based on opponent position.
	pass


func _integrate(dt: float) -> void:
	if not on_ground:
		vel.y += gravity * dt
	pos += vel * dt
	if pos.y >= ground_y:
		pos.y = ground_y
		vel.y = 0.0
		on_ground = true
	pos.x = clampf(pos.x, stage_left, stage_right)


func wants_block(inp: FightInput) -> bool:
	return state == State.BLOCK or (can_act() and on_ground and _is_holding_back(inp))
