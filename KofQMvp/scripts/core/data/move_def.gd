class_name MoveDef
extends RefCounted

var move_id: String = ""
var command: String = ""
var tags: Array = []
var startup: int = 0
var active: int = 0
var recovery: int = 0
var damage: int = 0
var chip_damage: int = 0
var hitstun: int = 0
var blockstun: int = 0
var pushback_hit: float = 0.0
var pushback_block: float = 0.0
var hitstop: int = 6
var height: String = "mid"
var attribute: String = "strike"
var meter_gain_hit: float = 0.0
var meter_cost: float = 0.0
var cancel_into: Array = []
var cancel_from_frame: int = 0
var cancel_to_frame: int = 0
var hitboxes: Array = []
var projectile: Dictionary = {}
var launch: bool = false
var knockdown: bool = false
var guard_crush: float = 0.0
var invuln_startup: int = 0
var armor_frames: int = 0
var teleport_x: float = 0.0


func total_frames() -> int:
	return startup + active + recovery


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func is_special() -> bool:
	return has_tag("special")


func is_super() -> bool:
	return has_tag("super")


func is_normal() -> bool:
	return has_tag("normal")


func is_throw() -> bool:
	return has_tag("throw") or attribute == "throw"


func active_hitboxes(frame: int) -> Array:
	var out: Array = []
	for hb in hitboxes:
		if frame >= int(hb.get("from", 0)) and frame <= int(hb.get("to", 0)):
			out.append(hb)
	return out


static func from_dict(d: Dictionary) -> MoveDef:
	var m := MoveDef.new()
	m.move_id = str(d.get("move_id", ""))
	m.command = str(d.get("command", ""))
	m.tags = d.get("tags", [])
	m.startup = int(d.get("startup", 0))
	m.active = int(d.get("active", 0))
	m.recovery = int(d.get("recovery", 0))
	m.damage = int(d.get("damage", 0))
	m.chip_damage = int(d.get("chip_damage", 0))
	m.hitstun = int(d.get("hitstun", 0))
	m.blockstun = int(d.get("blockstun", 0))
	m.pushback_hit = float(d.get("pushback_hit", 0))
	m.pushback_block = float(d.get("pushback_block", 0))
	m.hitstop = int(d.get("hitstop", 6))
	m.height = str(d.get("height", "mid"))
	m.attribute = str(d.get("attribute", "strike"))
	m.meter_gain_hit = float(d.get("meter_gain_hit", 0))
	m.meter_cost = float(d.get("meter_cost", 0))
	m.cancel_into = d.get("cancel_into", [])
	m.cancel_from_frame = int(d.get("cancel_from_frame", 0))
	m.cancel_to_frame = int(d.get("cancel_to_frame", 0))
	m.hitboxes = d.get("hitboxes", [])
	m.projectile = d.get("projectile", {})
	m.launch = bool(d.get("launch", false))
	m.knockdown = bool(d.get("knockdown", false))
	m.guard_crush = float(d.get("guard_crush", 0))
	m.invuln_startup = int(d.get("invuln_startup", 0))
	m.armor_frames = int(d.get("armor_frames", 0))
	m.teleport_x = float(d.get("teleport_x", 0))
	return m
