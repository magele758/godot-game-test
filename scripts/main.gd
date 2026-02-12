extends Node2D

const RUN_COMBAT_ROOMS := 4

var run_director := RunDirector.new()
var player: PlayerController
var hud_label := Label.new()
var status_label := Label.new()
var room_started_at_msec: int = 0
var room_damage_checkpoint: int = 0
var current_room: Dictionary = {}
var active_enemy_count: int = 0
var run_finished: bool = false
var region_profile: Dictionary = {}
var relic_inventory: Array = []


func _ready() -> void:
	_ensure_input_actions()
	_setup_scene()
	_setup_hud()
	add_child(run_director)
	_start_run()


func _process(_delta: float) -> void:
	_refresh_hud()
	if Input.is_action_just_pressed("restart_run"):
		_clear_enemies()
		_start_run()


func _start_run() -> void:
	run_finished = false
	var seed := int(Time.get_unix_time_from_system())
	var tasks: Array = ContentDatabase.get_collection("tasks")
	RunState.begin_run(seed, "paper_blade", tasks)
	region_profile = RegionContentFilter.gore_profile()
	relic_inventory = []
	TelemetryLogger.log_event("run_started", {
		"seed": seed,
		"weapon_id": "paper_blade",
		"region": RegionContentFilter.resolve_region(),
	})

	if is_instance_valid(player):
		player.queue_free()
	player = PlayerController.new()
	player.global_position = Vector2(360, 360)
	player.connect("died", Callable(self, "_on_player_died"))
	player.connect("perfect_dodge", Callable(self, "_on_perfect_dodge"))
	add_child(player)

	var rooms: Array = ContentDatabase.get_collection("rooms")
	run_director.build_run(seed, rooms, RUN_COMBAT_ROOMS)
	if not run_director.validate_generated_run():
		push_warning("Run generation invalid. Using fallback room flow.")

	RunState.mark_task_complete("welcome_patrol")
	_enter_next_room()


func _enter_next_room() -> void:
	if run_finished:
		return
	if not run_director.has_next_room():
		_finish_run(true)
		return

	current_room = run_director.next_room()
	room_started_at_msec = Time.get_ticks_msec()
	room_damage_checkpoint = int(RunState.metrics.get("damage_taken", 0))
	RunState.next_room()
	_spawn_room_enemies(current_room)
	status_label.text = "进入房间: %s" % str(current_room.get("id", "unknown"))


func _spawn_room_enemies(room_data: Dictionary) -> void:
	active_enemy_count = max(1, int(room_data.get("enemy_count", 1)))
	var enemy_catalog: Array = ContentDatabase.get_collection("enemies")

	for idx in range(active_enemy_count):
		var enemy := EnemyController.new()
		_apply_enemy_archetype(enemy, enemy_catalog, idx)
		enemy.target = player
		enemy.global_position = Vector2(700 + idx * 40, 300 + (idx % 2) * 80)
		enemy.connect("died", Callable(self, "_on_enemy_died"))
		add_child(enemy)


func _clear_enemies() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy_node):
			enemy_node.queue_free()


func _apply_enemy_archetype(enemy: EnemyController, enemy_catalog: Array, idx: int) -> void:
	if enemy_catalog.is_empty():
		return
	var archetype: Dictionary = enemy_catalog[idx % enemy_catalog.size()]
	enemy.max_health = int(archetype.get("hp", enemy.max_health))
	enemy.current_health = enemy.max_health
	enemy.move_speed = float(archetype.get("move_speed", enemy.move_speed))
	enemy.attack_damage = int(archetype.get("attack_damage", enemy.attack_damage))
	enemy.attack_interval = float(archetype.get("attack_interval", enemy.attack_interval))


func _on_enemy_died(executed: bool, world_position: Vector2) -> void:
	active_enemy_count = max(0, active_enemy_count - 1)
	RunState.register_kill(executed)
	if executed:
		RunState.mark_task_complete("tidy_finish")
	_spawn_defeat_effect(world_position, executed)

	if active_enemy_count == 0:
		var spent_seconds := float(Time.get_ticks_msec() - room_started_at_msec) / 1000.0
		var took_damage := int(RunState.metrics.get("damage_taken", 0)) > room_damage_checkpoint
		RunState.register_room_clear(spent_seconds, took_damage)
		_roll_relic_drop()
		TelemetryLogger.log_event("room_cleared", {
			"room_id": str(current_room.get("id", "unknown")),
			"spent_seconds": spent_seconds,
			"took_damage": took_damage,
		})
		if int(RunState.room_index) == 1:
			RunState.mark_task_complete("toy_rescue")
		_enter_next_room()


func _on_player_died() -> void:
	TelemetryLogger.log_event("player_died", {
		"room_index": int(RunState.room_index),
		"kills": int(RunState.metrics.get("kills", 0)),
	})
	_finish_run(false)


func _on_perfect_dodge() -> void:
	RunState.mark_task_complete("mail_dash")
	var relics_data: Array = ContentDatabase.get_collection("relics")
	RelicEffects.on_perfect_dodge(player, relic_inventory, relics_data)


func _finish_run(victory: bool) -> void:
	if run_finished:
		return
	run_finished = true
	if victory:
		RunState.mark_task_complete("final_delivery")

	var snapshot := RunState.snapshot_for_progression()
	snapshot["victory"] = victory
	snapshot["region"] = RegionContentFilter.resolve_region()
	var progression_summary := ProgressionManager.record_run(snapshot)
	TelemetryLogger.log_event("run_completed", {
		"snapshot": snapshot,
		"progression": progression_summary,
	})

	var result := "胜利" if victory else "失败"
	status_label.text = "本局%s | 评级 %s | XP +%d" % [
		result,
		str(progression_summary.get("rank", "D")),
		int(progression_summary.get("xp_gain", 0)),
	]


func _setup_scene() -> void:
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([
		Vector2(80, 120),
		Vector2(1200, 120),
		Vector2(1200, 620),
		Vector2(80, 620),
	])
	board.color = Color(0.93, 0.9, 0.78, 1.0)
	add_child(board)


func _setup_hud() -> void:
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)

	hud_label.position = Vector2(20, 20)
	hud_label.size = Vector2(900, 300)
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_layer.add_child(hud_label)

	status_label.position = Vector2(20, 180)
	status_label.size = Vector2(1000, 120)
	hud_layer.add_child(status_label)


func _refresh_hud() -> void:
	if not is_instance_valid(player):
		return

	var gore_intensity := int(region_profile.get("gore_intensity", 2))
	var combo_count := RunState.get_combo_variety_count()
	var tasks_done := 0
	for done in RunState.cute_tasks.values():
		if bool(done):
			tasks_done += 1

	var profile_level := int(ProgressionManager.profile.get("profile_level", 1))
	hud_label.text = (
		"HP: %d/%d\n" % [player.current_health, player.max_health]
		+ "房间: %d | 击杀: %d | 完美闪避: %d\n" % [
			int(RunState.room_index),
			int(RunState.metrics.get("kills", 0)),
			int(RunState.metrics.get("perfect_dodges", 0)),
		]
		+ "连段多样性: %d | 可爱任务: %d/%d\n" % [
			combo_count,
			tasks_done,
			RunState.cute_tasks.size(),
		]
		+ "遗物: %d | 当前武器: %s\n" % [
			relic_inventory.size(),
			RunState.current_weapon_id,
		]
		+ "地区: %s | 血腥等级: %d | 档案等级: %d" % [
			RegionContentFilter.resolve_region(),
			gore_intensity,
			profile_level,
		]
	)


func _spawn_defeat_effect(position: Vector2, executed: bool) -> void:
	var particles := CPUParticles2D.new()
	var gore_intensity := int(region_profile.get("gore_intensity", 2))
	particles.one_shot = true
	particles.amount = 10 + gore_intensity * 20
	particles.lifetime = 0.35
	particles.emitting = true
	particles.global_position = position
	particles.direction = Vector2(0, -1)
	particles.spread = 120.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2(0, 260)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0

	if gore_intensity <= 0:
		particles.color = Color(0.95, 0.83, 0.3, 1.0)
	elif executed:
		particles.color = Color(0.78, 0.05, 0.05, 1.0)
	else:
		particles.color = Color(0.45, 0.08, 0.08, 1.0)
	add_child(particles)
	_cleanup_particles_later(particles)


func _roll_relic_drop() -> void:
	var relics: Array = ContentDatabase.get_collection("relics")
	if relics.is_empty():
		return
	var entries: Array = []
	for relic in relics:
		entries.append({
			"id": str(relic.get("id", "")),
			"name": str(relic.get("name", "")),
			"weight": float(relic.get("weight", 1.0)),
		})

	var rng := RandomNumberGenerator.new()
	rng.seed = int(RunState.run_seed + RunState.room_index * 97 + Time.get_ticks_msec() % 1000)
	var picked: Dictionary = DropTable.pick(entries, rng)
	var relic_id := str(picked.get("id", ""))
	if relic_id.is_empty() or relic_inventory.has(relic_id):
		return

	relic_inventory.append(relic_id)
	_refresh_relic_bonuses()
	TelemetryLogger.log_event("relic_obtained", {
		"relic_id": relic_id,
		"room_index": int(RunState.room_index),
	})


func _refresh_relic_bonuses() -> void:
	if not is_instance_valid(player):
		return
	var relics_data: Array = ContentDatabase.get_collection("relics")
	player.relic_combo_damage_bonus = RelicEffects.combo_damage_bonus(relic_inventory, relics_data)


func _cleanup_particles_later(particles: CPUParticles2D) -> void:
	var timer := get_tree().create_timer(0.8)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _ensure_input_actions() -> void:
	_ensure_action_key("move_left", KEY_A)
	_ensure_action_key("move_left", KEY_LEFT)
	_ensure_action_key("move_right", KEY_D)
	_ensure_action_key("move_right", KEY_RIGHT)
	_ensure_action_key("move_up", KEY_W)
	_ensure_action_key("move_up", KEY_UP)
	_ensure_action_key("move_down", KEY_S)
	_ensure_action_key("move_down", KEY_DOWN)
	_ensure_action_key("attack", KEY_J)
	_ensure_action_key("attack", KEY_SPACE)
	_ensure_action_key("dodge", KEY_K)
	_ensure_action_key("dodge", KEY_SHIFT)
	_ensure_action_key("restart_run", KEY_R)


func _ensure_action_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
