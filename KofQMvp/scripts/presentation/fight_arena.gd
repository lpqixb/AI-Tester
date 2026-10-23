extends Node2D
## Fight scene controller: sim, views, HUD, modes.

@onready var camera: Camera2D = $Camera2D
@onready var p1_view: FighterView = $P1View
@onready var p2_view: FighterView = $P2View
@onready var hud: Control = $CanvasLayer/Hud
@onready var pause_layer: Control = $CanvasLayer/Pause
@onready var winner_label: Label = $CanvasLayer/Winner
@onready var fx_flash: ColorRect = $CanvasLayer/SuperFlash
@onready var round_dim: ColorRect = $CanvasLayer/RoundDim
@onready var round_banner: Label = $CanvasLayer/RoundBanner

var sim := FightSimulator.new()
var cpu := CpuAi.new()
var _prev_p1 := 0
var _prev_p2 := 0
var paused: bool = false
var result_timer: int = 0
var banner_timer: int = 0
var _sfx: Dictionary = {}


func _ready() -> void:
	pause_layer.visible = false
	winner_label.visible = false
	fx_flash.visible = false
	round_dim.visible = false
	round_banner.visible = false
	_load_sfx()
	var training := GameSession.mode == GameSession.Mode.TRAINING
	sim.setup(GameSession.p1_team, GameSession.p2_team, training)
	sim.hit_connected.connect(_on_hit)
	sim.fighter_ko.connect(_on_fighter_ko)
	sim.round_begin.connect(_on_round_begin)
	sim.match_over.connect(_on_match_over)
	p1_view.setup(sim.p1)
	p2_view.setup(sim.p2)
	p1_view.show_boxes = training
	p2_view.show_boxes = training
	_update_hud()


func _load_sfx() -> void:
	for key in ["hit", "block", "ko", "super", "ui"]:
		var path := "res://assets/audio/%s.wav" % key
		if ResourceLoader.exists(path):
			_sfx[key] = load(path)


func _physics_process(_delta: float) -> void:
	if p1_view == null or p2_view == null:
		return
	if paused:
		return
	if result_timer > 0:
		result_timer -= 1
		if result_timer == 0:
			_finish_match_flow()
		return

	var i1 := _sample("p1", _prev_p1)
	_prev_p1 = i1.buttons
	var i2: FightInput
	if GameSession.p2_is_cpu or GameSession.mode == GameSession.Mode.ARCADE:
		i2 = cpu.think(sim.p2, sim.p1)
	else:
		i2 = _sample("p2", _prev_p2)
		_prev_p2 = i2.buttons

	# Training hotkeys
	if GameSession.mode == GameSession.Mode.TRAINING:
		if Input.is_action_just_pressed("train_reset"):
			sim.reset_training_positions()
			p1_view.setup(sim.p1)
			p2_view.setup(sim.p2)
		if Input.is_action_just_pressed("train_dummy_block"):
			sim.dummy_block = not sim.dummy_block
		if Input.is_action_just_pressed("train_boxes"):
			p1_view.show_boxes = not p1_view.show_boxes
			p2_view.show_boxes = p1_view.show_boxes

	sim.step(i1, i2)
	p1_view.setup(sim.p1)
	p2_view.setup(sim.p2)
	if banner_timer > 0:
		banner_timer -= 1
		if banner_timer == 0:
			round_banner.visible = false
			round_dim.visible = false
	_update_camera()
	_update_hud()
	_draw_projectiles()


func _sample(prefix: String, prev: int) -> FightInput:
	var inp := ActionSampler.sample(prefix)
	inp.pressed = inp.buttons & ~prev
	inp.released = prev & ~inp.buttons
	return inp


func _update_camera() -> void:
	var mid_x: float = (sim.p1.pos.x + sim.p2.pos.x) * 0.5
	camera.position = Vector2(clampf(mid_x, 480.0, 800.0), 360.0)


func _update_hud() -> void:
	var hp1: ProgressBar = hud.get_node("P1HP")
	var hp2: ProgressBar = hud.get_node("P2HP")
	var m1: ProgressBar = hud.get_node("P1Meter")
	var m2: ProgressBar = hud.get_node("P2Meter")
	var info: Label = hud.get_node("Info")
	var t1: Label = hud.get_node("P1Team")
	var t2: Label = hud.get_node("P2Team")
	hp1.max_value = sim.p1.max_hp
	hp1.value = sim.p1.hp
	hp2.max_value = sim.p2.max_hp
	hp2.value = sim.p2.hp
	m1.max_value = sim.meter_max
	m1.value = sim.meter1
	m2.max_value = sim.meter_max
	m2.value = sim.meter2
	var n1 := sim.p1.char_def.display_name if sim.p1.char_def else "?"
	var n2 := sim.p2.char_def.display_name if sim.p2.char_def else "?"
	t1.text = "P1 %s 队余%d [%s]" % [n1, sim.remaining(1), ",".join(sim.team1)]
	t2.text = "P2 %s 队余%d [%s]" % [n2, sim.remaining(2), ",".join(sim.team2)]
	var mode_name := "Versus"
	match GameSession.mode:
		GameSession.Mode.TRAINING:
			mode_name = "Training R复位 B假人防 F框"
		GameSession.Mode.ARCADE:
			mode_name = "Arcade 关卡 %d/4" % (GameSession.arcade_stage + 1)
	info.text = "%s | tick %d | %s | move %s/%s" % [
		mode_name, sim.tick, sim.last_event,
		sim.p1.last_move_id, sim.p2.last_move_id
	]


func _draw_projectiles() -> void:
	var layer: Node2D = $Projectiles
	for c in layer.get_children():
		c.queue_free()
	for p in sim.projectiles:
		var r := ColorRect.new()
		r.size = Vector2(p.w, p.h)
		r.position = Vector2(p.pos.x - p.w * 0.5, p.pos.y - p.h * 0.5)
		r.color = Color(1.0, 0.85, 0.3, 0.9)
		layer.add_child(r)


func _on_hit(side: int, blocked: bool, is_super: bool) -> void:
	if side == 1:
		p2_view.notify_hit(blocked)
	else:
		p1_view.notify_hit(blocked)
	_play_sfx("block" if blocked else "hit")
	if is_super:
		_play_sfx("super")
		fx_flash.visible = true
		fx_flash.modulate.a = 0.55
		var tw := create_tween()
		tw.tween_property(fx_flash, "modulate:a", 0.0, 0.25)
		tw.finished.connect(func(): fx_flash.visible = false)


func _play_sfx(key: String) -> void:
	if not _sfx.has(key):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _sfx[key]
	player.bus = "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _on_fighter_ko(_side: int) -> void:
	_play_sfx("ko")
	round_dim.visible = true
	round_banner.visible = true
	round_banner.text = "KO!"
	banner_timer = 0  # stay until round_begin or match_over
	fx_flash.visible = true
	fx_flash.modulate.a = 0.7
	var tw := create_tween()
	tw.tween_property(fx_flash, "modulate:a", 0.0, 0.45)
	tw.finished.connect(func(): fx_flash.visible = false)


func _on_round_begin() -> void:
	var n1 := sim.p1.char_def.display_name if sim.p1.char_def else "?"
	var n2 := sim.p2.char_def.display_name if sim.p2.char_def else "?"
	round_dim.visible = true
	round_banner.visible = true
	round_banner.text = "ROUND %d\n%s  vs  %s" % [sim.round_index, n1, n2]
	banner_timer = 50
	p1_view.setup(sim.p1)
	p2_view.setup(sim.p2)


func _on_match_over(winner: int) -> void:
	GameSession.last_winner_side = winner
	round_dim.visible = true
	round_banner.visible = false
	winner_label.visible = true
	winner_label.text = "P%d WINS!" % winner
	result_timer = 120


func _finish_match_flow() -> void:
	if GameSession.mode == GameSession.Mode.ARCADE:
		GameSession.advance_arcade_or_finish(sim.winner_side == 1)
	elif GameSession.mode == GameSession.Mode.TRAINING:
		sim.reset_training_positions()
		winner_label.visible = false
		p1_view.setup(sim.p1)
		p2_view.setup(sim.p2)
	else:
		get_tree().change_scene_to_file("res://scenes/result.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		paused = not paused
		pause_layer.visible = paused
		get_tree().paused = false  # we gate manually
	if paused and event.is_action_pressed("ui_cancel"):
		_resume_to_title()


func _on_resume_pressed() -> void:
	paused = false
	pause_layer.visible = false


func _on_title_pressed() -> void:
	_resume_to_title()


func _resume_to_title() -> void:
	paused = false
	pause_layer.visible = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
