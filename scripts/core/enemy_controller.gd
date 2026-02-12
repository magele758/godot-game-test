class_name EnemyController
extends CharacterBody2D

signal died(executed: bool, world_position: Vector2)

@export var max_health: int = 40
@export var move_speed: float = 120.0
@export var attack_damage: int = 8
@export var attack_interval: float = 1.1
@export var attack_range: float = 56.0

var current_health: int = max_health
var target: Node2D
var attack_cd_left: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	_bootstrap_visuals()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_cd_left = max(0.0, attack_cd_left - delta)
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > attack_range:
		velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
		if attack_cd_left <= 0.0 and target.has_method("receive_enemy_attack"):
			target.receive_enemy_attack(self, attack_damage)
			attack_cd_left = attack_interval

	move_and_slide()


func can_be_executed() -> bool:
	return float(current_health) <= float(max_health) * 0.25


func execute() -> void:
	if is_dead:
		return
	_die(true)


func take_player_hit(hit: Dictionary, knockback_from: Vector2) -> void:
	if is_dead:
		return
	var damage := int(hit.get("damage", 1))
	current_health -= damage
	var dir := (global_position - knockback_from).normalized()
	velocity = dir * 180.0
	if current_health <= 0:
		_die(bool(hit.get("execution", false)))


func _die(executed: bool) -> void:
	is_dead = true
	emit_signal("died", executed, global_position)
	queue_free()


func _bootstrap_visuals() -> void:
	if get_node_or_null("Body") == null:
		var body := Polygon2D.new()
		body.name = "Body"
		body.polygon = PackedVector2Array([
			Vector2(-14, -18),
			Vector2(14, -18),
			Vector2(12, 18),
			Vector2(-12, 18),
		])
		body.color = Color(0.2, 0.2, 0.25, 1.0)
		add_child(body)

	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 36)
		collision.shape = shape
		add_child(collision)
