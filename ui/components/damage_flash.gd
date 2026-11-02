extends Control

@onready var border_rect: Panel = %BorderPanel

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false

	var events: Node = get_node_or_null("/root/GameEvents")
	if events and events.has_signal("player_damaged"):
		events.player_damaged.connect(_on_player_damaged)

func _on_player_damaged(_amount: int) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	visible = true
	modulate.a = 1.0

	_tween = create_tween()
	# 0.05초간 유지 후 0.35초간 부드럽게 페이드아웃
	_tween.tween_interval(0.06)
	_tween.tween_property(self, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): visible = false)
