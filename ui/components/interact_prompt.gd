extends PanelContainer

@onready var prompt_label: Label = %PromptLabel
@onready var key_badge: PanelContainer = %KeyBadge
@onready var key_label: Label = %KeyLabel

var _tween: Tween

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	var events: Node = get_node_or_null("/root/GameEvents")
	if events and events.has_signal("interact_prompt_changed"):
		events.interact_prompt_changed.connect(_on_prompt_changed)

func _on_prompt_changed(text: String, is_show: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	if is_show and text != "":
		# text에 [E]나 E가 이미 포함되어 있으면 정리하거나 그대로 사용
		var clean_text := text
		if clean_text.begins_with("[E] "):
			clean_text = clean_text.substr(4)
		elif clean_text.begins_with("[E]"):
			clean_text = clean_text.substr(3)

		if prompt_label:
			prompt_label.text = clean_text
		visible = true
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func(): visible = false)
