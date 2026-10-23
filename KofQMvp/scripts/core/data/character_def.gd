class_name CharacterDef
extends RefCounted

var char_id: String = ""
var display_name: String = ""
var role: String = ""
var color: Color = Color.WHITE
var accent: Color = Color.WHITE
var max_hp: int = 1000
var walk_speed: float = 220.0
var back_walk_speed: float = 180.0
var dash_speed: float = 400.0
var jump_speed: float = 520.0
var gravity: float = 1600.0
var hurt := Aabb2.new(-28, -120, 56, 120)
var moves: Array[MoveDef] = []
var move_by_id: Dictionary = {}
var move_by_command: Dictionary = {}


func get_move(move_id: String) -> MoveDef:
	return move_by_id.get(move_id, null)


func get_by_command(cmd: String) -> MoveDef:
	return move_by_command.get(cmd, null)


static func from_dict(d: Dictionary) -> CharacterDef:
	var c := CharacterDef.new()
	c.char_id = str(d.get("char_id", ""))
	c.display_name = str(d.get("display_name", c.char_id))
	c.role = str(d.get("role", ""))
	var col: Array = d.get("color", [1, 1, 1])
	c.color = Color(float(col[0]), float(col[1]), float(col[2]))
	var acc: Array = d.get("accent", col)
	c.accent = Color(float(acc[0]), float(acc[1]), float(acc[2]))
	c.max_hp = int(d.get("max_hp", 1000))
	c.walk_speed = float(d.get("walk_speed", 220))
	c.back_walk_speed = float(d.get("back_walk_speed", 180))
	c.dash_speed = float(d.get("dash_speed", 400))
	c.jump_speed = float(d.get("jump_speed", 520))
	c.gravity = float(d.get("gravity", 1600))
	var h: Array = d.get("hurt", [-28, -120, 56, 120])
	c.hurt = Aabb2.new(float(h[0]), float(h[1]), float(h[2]), float(h[3]))
	for md in d.get("moves", []):
		_register_move(c, MoveDef.from_dict(md))
	_ensure_system_moves(c)
	return c


static func _register_move(c: CharacterDef, move: MoveDef) -> void:
	c.moves.append(move)
	c.move_by_id[move.move_id] = move
	c.move_by_command[move.command] = move


static func _ensure_system_moves(c: CharacterDef) -> void:
	## Jump normals + throw are shared system tools; a character JSON may override.
	for md in [
		{
			"move_id": "2B", "command": "2B", "tags": ["normal", "kick", "light", "low"],
			"startup": 5, "active": 3, "recovery": 10, "damage": 38, "hitstun": 12, "blockstun": 9,
			"pushback_hit": 30, "pushback_block": 22, "hitstop": 5, "height": "low",
			"attribute": "strike", "meter_gain_hit": 10, "cancel_into": ["special"],
			"cancel_from_frame": 5, "cancel_to_frame": 12,
			"hitboxes": [{"from": 5, "to": 7, "x": 20, "y": -36, "w": 52, "h": 28}]
		},
		{
			"move_id": "jA", "command": "jA", "tags": ["normal", "punch", "light", "jump"],
			"startup": 5, "active": 4, "recovery": 10, "damage": 42, "hitstun": 12, "blockstun": 8,
			"pushback_hit": 28, "pushback_block": 18, "hitstop": 5, "height": "overhead",
			"attribute": "strike", "meter_gain_hit": 10,
			"hitboxes": [{"from": 5, "to": 8, "x": 18, "y": -80, "w": 50, "h": 40}]
		},
		{
			"move_id": "jB", "command": "jB", "tags": ["normal", "kick", "light", "jump"],
			"startup": 6, "active": 4, "recovery": 12, "damage": 50, "hitstun": 14, "blockstun": 9,
			"pushback_hit": 32, "pushback_block": 20, "hitstop": 6, "height": "overhead",
			"attribute": "strike", "meter_gain_hit": 12,
			"hitboxes": [{"from": 6, "to": 9, "x": 22, "y": -48, "w": 56, "h": 48}]
		},
		{
			"move_id": "jC", "command": "jC", "tags": ["normal", "punch", "medium", "jump"],
			"startup": 8, "active": 5, "recovery": 14, "damage": 72, "hitstun": 16, "blockstun": 11,
			"pushback_hit": 40, "pushback_block": 24, "hitstop": 7, "height": "overhead",
			"attribute": "strike", "meter_gain_hit": 16,
			"hitboxes": [{"from": 8, "to": 12, "x": 20, "y": -90, "w": 64, "h": 50}]
		},
		{
			"move_id": "throw", "command": "THROW", "tags": ["throw"],
			"startup": 5, "active": 3, "recovery": 24, "damage": 140, "hitstun": 8, "blockstun": 0,
			"pushback_hit": 20, "pushback_block": 0, "hitstop": 8, "height": "mid",
			"attribute": "throw", "meter_gain_hit": 18, "knockdown": true,
			"hitboxes": [{"from": 5, "to": 7, "x": 10, "y": -90, "w": 58, "h": 80}]
		},
	]:
		if c.get_by_command(str(md["command"])) == null:
			_register_move(c, MoveDef.from_dict(md))
