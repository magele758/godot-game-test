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
var selected_weapon_index: int = 0
var camera: Camera2D
var pcam: PhantomCamera2D


func _ready() -> void:
	_ensure_input_actions()
	_setup_camera()
	_setup_scene()
	_setup_hud()
	add_child(run_director)
	_start_run()


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(640, 370)
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)
	camera.make_current()

	# PhantomCamera 系统：Host 挂在 Camera2D 上
	var pcam_host := PhantomCameraHost.new()
	camera.add_child(pcam_host)

	# PhantomCamera2D 做玩家跟随（稍后 _start_run 里设置 follow_target）
	pcam = PhantomCamera2D.new()
	pcam.follow_mode = PhantomCamera2D.FollowMode.GLUED
	pcam.zoom = Vector2(1.0, 1.0)
	add_child(pcam)


func _process(_delta: float) -> void:
	_refresh_hud()
	_handle_weapon_switch()
	if Input.is_action_just_pressed("restart_run"):
		_clear_enemies()
		_start_run()


func _start_run() -> void:
	run_finished = false
	var seed: int = int(Time.get_unix_time_from_system())
	var tasks: Array = ContentDatabase.get_collection("tasks")
	var weapon_id: String = _get_selected_weapon_id()
	RunState.begin_run(seed, weapon_id, tasks)
	region_profile = RegionContentFilter.gore_profile()
	relic_inventory = []
	TelemetryLogger.log_event("run_started", {
		"seed": seed,
		"weapon_id": weapon_id,
		"region": RegionContentFilter.resolve_region(),
	})
	# 播放背景音乐
	AudioMgr.play_bgm("bgm_loop.wav")

	if is_instance_valid(player):
		player.queue_free()
	player = PlayerController.new()
	player.global_position = Vector2(360, 360)
	# 根据选中武器调整基础伤害
	var weapons: Array = ContentDatabase.get_collection("weapons")
	var idx: int = clampi(selected_weapon_index, 0, max(0, weapons.size() - 1))
	if not weapons.is_empty():
		player.base_damage = float(weapons[idx].get("base_damage", 12) as int)
	player.connect("died", Callable(self, "_on_player_died"))
	player.connect("perfect_dodge", Callable(self, "_on_perfect_dodge"))
	add_child(player)

	# PhantomCamera 跟随玩家
	if pcam != null:
		pcam.set_follow_target(player)

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
	ScreenFX.room_flash(self, Vector2(1280, 720))
	room_started_at_msec = Time.get_ticks_msec()
	room_damage_checkpoint = int(RunState.metrics.get("damage_taken", 0) as int)
	RunState.next_room()

	var room_type: String = str(current_room.get("type", "combat"))
	var progress: String = "%d/%d" % [run_director.room_cursor + 1, run_director.get_room_count()]

	if room_type == "treasure":
		# 宝藏房：治疗 + 必出遗物
		var heal: int = int(current_room.get("heal_amount", 25))
		if is_instance_valid(player):
			player.current_health = mini(player.current_health + heal, player.max_health)
		_roll_relic_drop()
		status_label.text = "[%s] 宝藏房! HP +%d" % [progress, heal]
		AudioMgr.play_sfx("sfx_perfect_dodge.wav")
		# 自动进入下一房间
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			_enter_next_room()
		)
		return

	_spawn_room_enemies(current_room)
	var type_name: String = "Boss" if room_type == "boss" else ("精英" if room_type == "elite" else "战斗")
	status_label.text = "[%s] %s房: %s" % [progress, type_name, str(current_room.get("id", "unknown"))]


func _spawn_room_enemies(room_data: Dictionary) -> void:
	active_enemy_count = max(1, int(room_data.get("enemy_count", 1)))
	var enemy_catalog: Array = ContentDatabase.get_collection("enemies")
	var room_type: String = str(room_data.get("type", "combat"))

	# 敌人贴图映射
	var enemy_sprites: Dictionary = {
		"grunt": "res://assets/sprites/enemies/enemy_grunt.png",
		"fast": "res://assets/sprites/enemies/enemy_fast.png",
		"tank": "res://assets/sprites/enemies/enemy_tank.png",
	}

	for idx in range(active_enemy_count):
		var enemy := EnemyController.new()
		enemy.target = player
		enemy.global_position = Vector2(750 + idx * 100, 280 + (idx % 2) * 160)
		enemy.connect("died", Callable(self, "_on_enemy_died"))

		# 根据原型设定贴图路径（在 add_child/_ready 之前）
		if room_type == "boss":
			enemy.sprite_path = "res://assets/sprites/boss/boss_main.png"
		elif not enemy_catalog.is_empty():
			var archetype_id: String = str(enemy_catalog[idx % enemy_catalog.size()].get("id", "grunt"))
			if enemy_sprites.has(archetype_id):
				enemy.sprite_path = enemy_sprites[archetype_id]

		add_child(enemy)
		_apply_enemy_archetype(enemy, enemy_catalog, idx)


func _clear_enemies() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy_node):
			enemy_node.queue_free()


func _apply_enemy_archetype(enemy: EnemyController, enemy_catalog: Array, idx: int) -> void:
	if enemy_catalog.is_empty():
		return
	var archetype: Dictionary = enemy_catalog[idx % enemy_catalog.size()]
	enemy.max_health = int(archetype.get("hp", enemy.max_health))
	enemy.move_speed = float(archetype.get("move_speed", enemy.move_speed))
	enemy.attack_damage = int(archetype.get("attack_damage", enemy.attack_damage))
	enemy.attack_interval = float(archetype.get("attack_interval", enemy.attack_interval))

	# 难度递增加成
	var diff_bonus: float = float(current_room.get("difficulty_bonus", 0.0))
	enemy.max_health = int(float(enemy.max_health) * (1.0 + diff_bonus))
	enemy.move_speed *= (1.0 + diff_bonus * 0.3)

	# Boss 房间倍率
	var room_type: String = str(current_room.get("type", "combat"))
	if room_type == "boss":
		enemy.max_health *= 3
		enemy.attack_damage = int(float(enemy.attack_damage) * 1.5)
		enemy.attack_range *= 1.3
		var body_node := enemy.get_node_or_null("Body")
		if body_node is Sprite2D:
			body_node.scale *= 2.0
	elif room_type == "elite":
		enemy.max_health = int(float(enemy.max_health) * 1.8)
		enemy.attack_damage = int(float(enemy.attack_damage) * 1.3)
		var body_node := enemy.get_node_or_null("Body")
		if body_node is Sprite2D:
			body_node.scale *= 1.3
			body_node.modulate = Color(1.0, 0.7, 0.3, 1.0)

	enemy.current_health = enemy.max_health


func _on_enemy_died(executed: bool, world_position: Vector2) -> void:
	active_enemy_count = max(0, active_enemy_count - 1)
	RunState.register_kill(executed)
	if executed:
		RunState.mark_task_complete("tidy_finish")
	_spawn_defeat_effect(world_position, executed)
	ScreenFX.shake(camera, 14.0 if executed else 7.0, 0.12)
	AudioMgr.play_sfx("sfx_kill.wav")

	if active_enemy_count == 0:
		var spent_seconds := float(Time.get_ticks_msec() - room_started_at_msec) / 1000.0
		var took_damage: bool = int(RunState.metrics.get("damage_taken", 0) as int) > room_damage_checkpoint
		# clear_speed_bonus 遗物：快速通关额外注册一次完美闪避奖励
		var relics_data: Array = ContentDatabase.get_collection("relics")
		var speed_bonus: float = RelicEffects.clear_speed_bonus(relic_inventory, relics_data)
		if speed_bonus > 0.0 and spent_seconds < 15.0:
			RunState.register_perfect_dodge()
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
	AudioMgr.play_sfx("sfx_hurt.wav")
	AudioMgr.stop_bgm()
	_finish_run(false)


func _on_perfect_dodge() -> void:
	RunState.mark_task_complete("mail_dash")
	var relics_data: Array = ContentDatabase.get_collection("relics")
	RelicEffects.on_perfect_dodge(player, relic_inventory, relics_data)
	AudioMgr.play_sfx("sfx_perfect_dodge.wav")


func _finish_run(victory: bool) -> void:
	if run_finished:
		return
	run_finished = true
	if victory:
		RunState.mark_task_complete("final_delivery")

	var snapshot: Dictionary = RunState.snapshot_for_progression()
	snapshot["victory"] = victory
	snapshot["region"] = RegionContentFilter.resolve_region()
	var progression_summary: Dictionary = ProgressionManager.record_run(snapshot)
	TelemetryLogger.log_event("run_completed", {
		"snapshot": snapshot,
		"progression": progression_summary,
	})

	var result: String = "胜利" if victory else "失败"
	status_label.text = "本局%s | 评级 %s | XP +%d\n按 R 重新开始" % [
		result,
		str(progression_summary.get("rank", "D")),
		int(progression_summary.get("xp_gain", 0)),
	]
	# 死亡后让玩家视觉变灰
	if not victory and is_instance_valid(player):
		var body_node := player.get_node_or_null("Body")
		if body_node != null:
			body_node.modulate = Color(0.4, 0.4, 0.4, 0.5)


func _setup_scene() -> void:
	# 背景图片（笔记本纸张）
	var bg_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/backgrounds/notebook_paper.png"):
		bg_tex = load("res://assets/backgrounds/notebook_paper.png") as Texture2D
	if bg_tex != null:
		var bg_sprite := Sprite2D.new()
		bg_sprite.texture = bg_tex
		bg_sprite.centered = false
		bg_sprite.position = Vector2.ZERO
		# 缩放到 1280x720
		var sx: float = 1280.0 / float(bg_tex.get_width())
		var sy: float = 720.0 / float(bg_tex.get_height())
		bg_sprite.scale = Vector2(sx, sy)
		bg_sprite.z_index = -10
		add_child(bg_sprite)
	else:
		# fallback: 纯色背景
		var bg := ColorRect.new()
		bg.color = Color(0.96, 0.94, 0.86, 1.0)
		bg.position = Vector2.ZERO
		bg.size = Vector2(1280, 720)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	# 战斗区域半透明边框（让背景图透出来）
	var border := Line2D.new()
	border.add_point(Vector2(80, 120))
	border.add_point(Vector2(1200, 120))
	border.add_point(Vector2(1200, 620))
	border.add_point(Vector2(80, 620))
	border.add_point(Vector2(80, 120))
	border.width = 4.0
	border.default_color = Color(0.3, 0.28, 0.25, 0.7)
	add_child(border)

	# 四面碰撞墙
	_add_wall(Vector2(640, 112), Vector2(1140, 16))
	_add_wall(Vector2(640, 628), Vector2(1140, 16))
	_add_wall(Vector2(72, 370), Vector2(16, 516))
	_add_wall(Vector2(1208, 370), Vector2(16, 516))


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
	add_child(wall)


func _setup_hud() -> void:
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)

	hud_label.position = Vector2(20, 16)
	hud_label.size = Vector2(900, 300)
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 0.9))
	hud_layer.add_child(hud_label)

	status_label.position = Vector2(20, 200)
	status_label.size = Vector2(1000, 120)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.15, 0.1, 1.0))
	hud_layer.add_child(status_label)


func _refresh_hud() -> void:
	if not is_instance_valid(player):
		return

	var gore_intensity: int = int(region_profile.get("gore_intensity", 2) as int)
	var combo_count: int = RunState.get_combo_variety_count()
	var tasks_done: int = 0
	for done in RunState.cute_tasks.values():
		if bool(done):
			tasks_done += 1

	var profile_level: int = int(ProgressionManager.profile.get("profile_level", 1) as int)
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
		+ "进度: %d%% | 遗物: %d | 档案等级: %d" % [
			int(run_director.get_progress_ratio() * 100.0),
			relic_inventory.size(),
			profile_level,
		]
	)


func _spawn_defeat_effect(pos: Vector2, executed: bool) -> void:
	var gore_intensity: int = int(region_profile.get("gore_intensity", 2) as int)

	# 血溅贴图
	if gore_intensity > 0 and ResourceLoader.exists("res://assets/effects/blood_splat.png"):
		var splat_tex: Texture2D = load("res://assets/effects/blood_splat.png") as Texture2D
		if splat_tex != null:
			var splat := Sprite2D.new()
			splat.texture = splat_tex
			splat.global_position = pos
			var target_size: float = 120.0 + gore_intensity * 60.0
			if executed:
				target_size *= 1.5
			var sc: float = target_size / float(splat_tex.get_width())
			splat.scale = Vector2(sc, sc)
			splat.rotation = randf() * TAU
			splat.z_index = -1
			add_child(splat)
			# 2秒后淡出
			var tween := create_tween()
			tween.tween_interval(1.5)
			tween.tween_property(splat, "modulate:a", 0.0, 0.5)
			tween.tween_callback(splat.queue_free)

	# 粒子保留
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 12 + gore_intensity * 16
	particles.lifetime = 0.4
	particles.emitting = true
	particles.global_position = pos
	particles.direction = Vector2(0, -1)
	particles.spread = 140.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 260.0
	particles.gravity = Vector2(0, 360)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

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
	var relic_id: String = str(picked.get("id", ""))
	if relic_id.is_empty() or relic_inventory.has(relic_id):
		return

	relic_inventory.append(relic_id)
	_refresh_relic_bonuses()
	TelemetryLogger.log_event("relic_obtained", {
		"relic_id": relic_id,
		"room_index": int(RunState.room_index),
	})


func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		selected_weapon_index = 0
	elif Input.is_action_just_pressed("weapon_2"):
		selected_weapon_index = 1
	elif Input.is_action_just_pressed("weapon_3"):
		selected_weapon_index = 2


func _get_selected_weapon_id() -> String:
	var weapons: Array = ContentDatabase.get_collection("weapons")
	if weapons.is_empty():
		return "paper_blade"
	var idx: int = clampi(selected_weapon_index, 0, weapons.size() - 1)
	return str(weapons[idx].get("id", "paper_blade"))


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
	_ensure_action_key("weapon_1", KEY_1)
	_ensure_action_key("weapon_2", KEY_2)
	_ensure_action_key("weapon_3", KEY_3)


func _ensure_action_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
