class_name ScreenFX
extends RefCounted

## 屏幕震动
static func shake(camera: Camera2D, intensity: float = 6.0, duration: float = 0.12) -> void:
	if camera == null:
		return
	var tween: Tween = camera.create_tween()
	var steps: int = int(duration / 0.02)
	for i in range(steps):
		var offset: Vector2 = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
		)
		tween.tween_property(camera, "offset", offset, 0.02)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.02)


## 受击闪白
static func flash_white(node: Node2D, duration: float = 0.08) -> void:
	if node == null:
		return
	node.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, duration)


## 冲刺残影
static func spawn_afterimage(source: Node2D, parent: Node) -> void:
	if source == null or parent == null:
		return
	var ghost := Polygon2D.new()
	# 复制 Body 外形
	var body: Node = source.get_node_or_null("Body")
	if body is Polygon2D:
		ghost.polygon = (body as Polygon2D).polygon.duplicate()
	else:
		ghost.polygon = PackedVector2Array([
			Vector2(-12, -20), Vector2(12, -20),
			Vector2(16, 20), Vector2(-16, 20),
		])
	ghost.color = Color(0.7, 0.85, 1.0, 0.35)
	ghost.global_position = source.global_position
	parent.add_child(ghost)

	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


## 房间切换闪屏
static func room_flash(parent: Node, viewport_size: Vector2) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(1.0, 1.0, 1.0, 0.6)
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.add_child(overlay)
	parent.add_child(canvas)

	var tween: Tween = overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.25)
	tween.tween_callback(canvas.queue_free)
