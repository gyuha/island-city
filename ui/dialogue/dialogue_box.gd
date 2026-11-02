extends Control

signal dialogue_active_changed(is_active: bool)

@onready var speaker_pill: PanelContainer = %SpeakerPill
@onready var speaker_label: Label = %SpeakerLabel
@onready var content_label: Label = %ContentLabel
@onready var advance_hint: Label = %AdvanceHint

## 타자기 출력 속도 (초당 글자 수). 0 이하로 설정 시 즉시 전체 텍스트 표시(QA 테스트용).
@export var chars_per_second: float = 40.0

var is_open: bool = false
var _full_text: String = ""
var _typewriter_tween: Tween
var _is_typing: bool = false

func _ready() -> void:
	visible = false
	var events: Node = get_node_or_null("/root/GameEvents")
	if events:
		if events.has_signal("dialogue_started"):
			events.dialogue_started.connect(_on_dialogue_started)
		if events.has_signal("dialogue_line"):
			events.dialogue_line.connect(_on_dialogue_line)
		if events.has_signal("dialogue_ended"):
			events.dialogue_ended.connect(_on_dialogue_ended)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	# 키 누름 유지(echo)로 인한 연속 호출 방지
	if event.is_echo():
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		_handle_advance()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_advance()
		accept_event()

func _handle_advance() -> void:
	if _is_typing:
		# (a) 타자기 진행 중 -> 줄 즉시 완성
		_finish_typewriter()
	else:
		# (b) 완성 상태 -> DialogueManager.advance() 1회 호출
		var dm: Node = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("advance"):
			dm.advance()

func _on_dialogue_started(_dialogue_id: String) -> void:
	is_open = true
	visible = true
	dialogue_active_changed.emit(true)

func _on_dialogue_line(speaker: String, text: String) -> void:
	is_open = true
	visible = true
	dialogue_active_changed.emit(true)

	if speaker_label:
		speaker_label.text = speaker
	if speaker_pill:
		speaker_pill.visible = (speaker.strip_edges() != "")

	_full_text = text
	if content_label:
		content_label.text = _full_text
		content_label.visible_characters = 0

	_start_typewriter()

func _on_dialogue_ended() -> void:
	is_open = false
	visible = false
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	_is_typing = false
	dialogue_active_changed.emit(false)

func _start_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()

	if advance_hint:
		advance_hint.visible = false

	var char_count := _full_text.length()
	if char_count == 0 or chars_per_second <= 0.0:
		_finish_typewriter()
		return

	_is_typing = true
	var duration := float(char_count) / chars_per_second

	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(content_label, "visible_characters", char_count, duration)
	_typewriter_tween.tween_callback(_finish_typewriter)

func _finish_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()

	_is_typing = false
	if content_label:
		content_label.visible_characters = _full_text.length()
	if advance_hint:
		advance_hint.visible = true
