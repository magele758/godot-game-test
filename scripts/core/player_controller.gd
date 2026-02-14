class_name PlayerController
extends CharacterBody2D

signal died
signal perfect_dodge
signal attack_landed(combo_tag: String)

@export var move_speed: float = 380.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.6
@export var base_damage: float = 12.0
@export var attack_range: float = 110.0
@export var attack_cooldown: float = 0.24
@export var max_health: int = 100

var current_health: int = max_health
var facing: Vector2 = Vector2.RIGHT
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var attack_cooldown_left: float = 0.0
var combo_index: int = -1
var combo_reset_left: float = 0.0
var is_dead: bool = false
var relic_combo_damage_bonus: float = 0.0
var hp_bar_bg: Polygon2D
var hp_bar_fg: Polygon2D


func _ready() -> void:
	current_health = max_health
	_bootstrap_visuals()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	_handle_dash_input()
	_handle_attack_input()
	_apply_movement()
	move_and_slide()
	_update_hp_bar()


func _tick_timers(delta: float) -> void:
	dash_time_left = max(0.0, dash_time_left - delta)
	dash_cooldown_left = max(0.0, dash_cooldown_left - delta)
	attack_cooldown_left = max(0.0, attack_cooldown_left - delta)
	combo_reset_left = max(0.0, combo_reset_left - delta)
	if combo_reset_left <= 0.0:
		combo_index = -1


func _apply_movement() -> void:
	if dash_time_left > 0.0:
		velocity = facing * dash_speed
		# 每帧生成残影
		if get_parent() != null:
			ScreenFX.spawn_afterimage(self, get_parent())
		return

	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length() > 0.0:
		facing = movement.normalized()
	velocity = movement * move_speed


func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dodge") and dash_cooldown_left <= 0.0:
		dash_time_left = dash_duration
		dash_cooldown_left = dash_cooldown
		AudioMgr.play_sfx("sfx_dodge.wav")
		if facing == Vector2.ZERO:
			facing = Vector2.RIGHT


func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and attack_cooldown_left <= 0.0:
		attack_cooldown_left = attack_cooldown
		combo_index = (combo_index + 1) % 3
		combo_reset_left = 0.75
		_do_attack()


func _do_attack() -> void:
	var combo_tags: Array[String] = ["slash_a", "slash_b", "slash_c"]
	var combo_tag: String = combo_tags[combo_index]
	var bonus: float = ProgressionManager.get_weapon_bonus(RunState.current_weapon_id)
	bonus += relic_combo_damage_bonus
	var attack_origin: Vector2 = global_position + facing * 20.0
	_spawn_slash_arc()
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if enemy.is_dead:
			continue
		if attack_origin.distance_to(enemy.global_position) > attack_range:
			continue

		var region_settings: Dictionary = RegionContentFilter.gore_profile()
		var can_execute: bool = (
			enemy.can_be_executed()
			and ProgressionManager.is_action_unlocked("execution_plus")
			and bool(region_settings.get("execution_enabled", true))
		)
		if can_execute:
			enemy.execute()
			_apply_hitstop(0.08)
		else:
			var hit: Dictionary = CombatResolver.compute_hit(base_damage, bonus, combo_index + 1, false)
			enemy.take_player_hit(hit, global_position)
			_apply_hitstop(float(hit.get("hitstop_seconds", 0.04)))
		RunState.register_combo(combo_tag)
		emit_signal("attack_landed", combo_tag)
		AudioMgr.play_sfx("sfx_hit.wav")


func receive_enemy_attack(attacker: EnemyController, damage: int) -> void:
	if is_dead:
		return
	var distance: float = global_position.distance_to(attacker.global_position)
	if dash_time_left > 0.0 and distance <= attack_range + 30.0:
		RunState.register_perfect_dodge()
		emit_signal("perfect_dodge")
		return
	if is_invulnerable():
		return

	current_health -= damage
	RunState.register_damage_taken(damage)
	ScreenFX.flash_white(self, 0.1)
	AudioMgr.play_sfx("sfx_hurt.wav")
	if current_health <= 0:
		is_dead = true
		emit_signal("died")


func _update_hp_bar() -> void:
	if hp_bar_fg == null:
		return
	var ratio: float = health_ratio()
	var half_w: float = 30.0
	var right_x: float = -half_w + half_w * 2.0 * ratio
	hp_bar_fg.polygon = PackedVector2Array([
		Vector2(-half_w, -84), Vector2(right_x, -84),
		Vector2(right_x, -78), Vector2(-half_w, -78),
	])
	if ratio <= 0.3:
		hp_bar_fg.color = Color(0.9, 0.2, 0.2, 0.9)
	else:
		hp_bar_fg.color = Color(0.2, 0.85, 0.25, 0.9)


func _spawn_slash_arc() -> void:
	var arc := Polygon2D.new()
	var angle: float = facing.angle()
	var arc_points := PackedVector2Array()
	for i in range(7):
		var a: float = angle - 0.6 + float(i) * 0.2
		arc_points.append(Vector2(cos(a), sin(a)) * attack_range * 0.9)
	arc_points.append(Vector2.ZERO)
	arc.polygon = arc_points
	arc.color = Color(1.0, 1.0, 0.85, 0.55)
	arc.position = global_position + facing * 16.0
	get_parent().add_child(arc)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(arc):
			arc.queue_free()
	)
	# 打击火花
	if ResourceLoader.exists("res://assets/effects/hit_spark.png"):
		var spark_tex: Texture2D = load("res://assets/effects/hit_spark.png") as Texture2D
		if spark_tex != null:
			var spark := Sprite2D.new()
			spark.texture = spark_tex
			var sc: float = 96.0 / float(spark_tex.get_width())
			spark.scale = Vector2(sc, sc)
			spark.global_position = global_position + facing * attack_range * 0.5
			spark.rotation = randf() * TAU
			get_parent().add_child(spark)
			get_tree().create_timer(0.1).timeout.connect(func() -> void:
				if is_instance_valid(spark):
					spark.queue_free()
			)


func _apply_hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
	)


func is_invulnerable() -> bool:
	return dash_time_left > 0.0


func health_ratio() -> float:
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)


func _bootstrap_visuals() -> void:
	if get_node_or_null("Body") == null:
		var body := Sprite2D.new()
		body.name = "Body"
		var tex: Texture2D = load("res://assets/sprites/player/player_idle.png") as Texture2D
		if tex != null:
			body.texture = tex
			# 根据原图大小缩放到游戏内约 150px 高
			var target_h: float = 150.0
			var sc: float = target_h / float(tex.get_height())
			body.scale = Vector2(sc, sc)
		# 外描边 shader
		var outline_shader: Shader = load("res://assets/shaders/outline2D_outer.gdshader") as Shader
		if outline_shader != null:
			var mat := ShaderMaterial.new()
			mat.shader = outline_shader
			mat.set_shader_parameter("line_color", Color(0.1, 0.6, 1.0, 0.8))
			mat.set_shader_parameter("line_thickness", 1.5)
			body.material = mat
		add_child(body)

	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(60, 140)
		collision.shape = shape
		add_child(collision)

	hp_bar_bg = Polygon2D.new()
	hp_bar_bg.polygon = PackedVector2Array([
		Vector2(-30, -84), Vector2(30, -84),
		Vector2(30, -78), Vector2(-30, -78),
	])
	hp_bar_bg.color = Color(0.15, 0.15, 0.15, 0.7)
	add_child(hp_bar_bg)

	hp_bar_fg = Polygon2D.new()
	hp_bar_fg.polygon = hp_bar_bg.polygon.duplicate()
	hp_bar_fg.color = Color(0.2, 0.85, 0.25, 0.9)
	add_child(hp_bar_fg)
