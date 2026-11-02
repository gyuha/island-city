extends PanelContainer

@export var max_health: int = 100
@export var current_health: int = 100
@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel

var _hp_tween: Tween
var _stamina_tween: Tween

func _ready() -> void:
	_update_hp_display(current_health, max_health, false)
	_update_stamina_display(current_stamina, max_stamina, false)

	var events: Node = get_node_or_null("/root/GameEvents")
	if events:
		if events.has_signal("player_health_changed"):
			events.player_health_changed.connect(_on_health_changed)
		if events.has_signal("stamina_changed"):
			events.stamina_changed.connect(_on_stamina_changed)

func _on_health_changed(cur: int, max_val: int) -> void:
	_update_hp_display(cur, max_val, true)

func _on_stamina_changed(cur: float, max_val: float) -> void:
	_update_stamina_display(cur, max_val, true)

func _update_hp_display(cur: int, max_val: int, animate: bool = true) -> void:
	current_health = cur
	max_health = maxi(1, max_val)
	if hp_label:
		hp_label.text = "%d / %d" % [current_health, max_health]
	if hp_bar:
		hp_bar.max_value = max_health
		if animate and is_inside_tree():
			if _hp_tween and _hp_tween.is_running():
				_hp_tween.kill()
			_hp_tween = create_tween()
			_hp_tween.tween_property(hp_bar, "value", float(current_health), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			hp_bar.value = current_health

func _update_stamina_display(cur: float, max_val: float, animate: bool = true) -> void:
	current_stamina = cur
	max_stamina = maxf(1.0, max_val)
	if stamina_label:
		stamina_label.text = "%d / %d" % [int(current_stamina), int(max_stamina)]
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		if animate and is_inside_tree():
			if _stamina_tween and _stamina_tween.is_running():
				_stamina_tween.kill()
			_stamina_tween = create_tween()
			_stamina_tween.tween_property(stamina_bar, "value", current_stamina, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			stamina_bar.value = current_stamina
