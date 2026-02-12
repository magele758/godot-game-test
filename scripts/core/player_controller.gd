class_name PlayerController
extends CharacterBody2D

signal died
signal perfect_dodge
signal attack_landed(combo_tag: String)

@export var move_speed: float = 260.0
@export var dash_speed: float = 560.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.6
@export var base_damage: float = 12.0
@export var attack_range: float = 72.0
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
		return

	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length() > 0.0:
		facing = movement.normalized()
	velocity = movement * move_speed


func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dodge") and dash_cooldown_left <= 0.0:
		dash_time_left = dash_duration
		dash_cooldown_left = dash_cooldown
		if facing == Vector2.ZERO:
			facing = Vector2.RIGHT


func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and attack_cooldown_left <= 0.0:
		attack_cooldown_left = attack_cooldown
		combo_index = (combo_index + 1) % 3
		combo_reset_left = 0.75
		_do_attack()


func _do_attack() -> void:
	var combo_tags := ["slash_a", "slash_b", "slash_c"]
	var combo_tag := combo_tags[combo_index]
	var bonus := ProgressionManager.get_weapon_bonus(RunState.current_weapon_id)
	# 遗物连段伤害加成由外部注入
	bonus += relic_combo_damage_bonus
	var attack_origin := global_position + facing * 12.0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is not EnemyController:
			continue
		var enemy := enemy_node as EnemyController
		if enemy.is_dead:
			continue
		if attack_origin.distance_to(enemy.global_position) > attack_range:
			continue

		var region_settings := RegionContentFilter.gore_profile()
		var can_execute := (
			enemy.can_be_executed()
			and ProgressionManager.is_action_unlocked("execution_plus")
			and bool(region_settings.get("execution_enabled", true))
		)
		if can_execute:
			enemy.execute()
		else:
			var hit := CombatResolver.compute_hit(base_damage, bonus, combo_index + 1, false)
			enemy.take_player_hit(hit, global_position)
		RunState.register_combo(combo_tag)
		emit_signal("attack_landed", combo_tag)


func receive_enemy_attack(attacker: EnemyController, damage: int) -> void:
	if is_dead:
		return
	var distance := global_position.distance_to(attacker.global_position)
	if dash_time_left > 0.0 and distance <= attack_range + 16.0:
		RunState.register_perfect_dodge()
		emit_signal("perfect_dodge")
		return
	if is_invulnerable():
		return

	current_health -= damage
	RunState.register_damage_taken(damage)
	if current_health <= 0:
		is_dead = true
		emit_signal("died")


func is_invulnerable() -> bool:
	return dash_time_left > 0.0


func health_ratio() -> float:
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)


func _bootstrap_visuals() -> void:
	if get_node_or_null("Body") == null:
		var body := Polygon2D.new()
		body.name = "Body"
		body.polygon = PackedVector2Array([
			Vector2(-12, -20),
			Vector2(12, -20),
			Vector2(16, 20),
			Vector2(-16, 20),
		])
		body.color = Color(0.97, 0.96, 0.9, 1.0)
		add_child(body)

	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(26, 40)
		collision.shape = shape
		add_child(collision)
