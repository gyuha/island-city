extends PanelContainer

@onready var quest_title_label: Label = %QuestTitleLabel
@onready var quest_progress_label: Label = %QuestProgressLabel
@onready var quest_badge: PanelContainer = %QuestBadge
@onready var quest_badge_label: Label = %QuestBadgeLabel

var current_quest_id: String = ""
var _hide_tween: Tween

func _ready() -> void:
	visible = false
	var events: Node = get_node_or_null("/root/GameEvents")
	if events:
		if events.has_signal("quest_started"):
			events.quest_started.connect(_on_quest_started)
		if events.has_signal("quest_progress"):
			events.quest_progress.connect(_on_quest_progress)
		if events.has_signal("quest_completed"):
			events.quest_completed.connect(_on_quest_completed)

	_check_initial_quests()

func _check_initial_quests() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm and "active" in qm and not qm.active.is_empty():
		for qid in qm.active.keys():
			var cur: int = qm.active[qid]
			var qdata = qm.get_quest_data(qid)
			if qdata:
				_display_quest(qid, qdata.title, cur, qdata.target)
				break

func _on_quest_started(quest_id: String) -> void:
	var title := _get_title(quest_id)
	var qm: Node = get_node_or_null("/root/QuestManager")
	var target := 1
	var cur := 0
	if qm:
		var qdata = qm.get_quest_data(quest_id)
		if qdata:
			target = qdata.target
			cur = qm.get_progress(quest_id)
	_display_quest(quest_id, title, cur, target)

func _on_quest_progress(quest_id: String, cur: int, target: int) -> void:
	if current_quest_id == "" or current_quest_id == quest_id:
		var title := _get_title(quest_id)
		_display_quest(quest_id, title, cur, target)

func _on_quest_completed(quest_id: String) -> void:
	if current_quest_id == quest_id or current_quest_id == "":
		var title := _get_title(quest_id)
		current_quest_id = quest_id
		visible = true
		modulate.a = 1.0
		if quest_title_label:
			quest_title_label.text = title
		if quest_progress_label:
			quest_progress_label.text = "완료!"
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1.0))
		if quest_badge_label:
			quest_badge_label.text = "✓"

		# 잠시 후 다른 활성 퀘스트가 있는지 확인하고 없으면 페이드아웃
		if _hide_tween and _hide_tween.is_running():
			_hide_tween.kill()
		_hide_tween = create_tween()
		_hide_tween.tween_interval(2.5)
		_hide_tween.tween_callback(self._check_next_quest_or_hide)

func _check_next_quest_or_hide() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm and "active" in qm and not qm.active.is_empty():
		for qid in qm.active.keys():
			var cur: int = qm.active[qid]
			var qdata = qm.get_quest_data(qid)
			if qdata:
				_display_quest(qid, qdata.title, cur, qdata.target)
				return
	
	# 남은 퀘스트 없으면 페이드아웃
	if _hide_tween and _hide_tween.is_running():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_hide_tween.tween_callback(func(): visible = false; current_quest_id = "")

func _display_quest(quest_id: String, title: String, cur: int, target: int) -> void:
	if _hide_tween and _hide_tween.is_running():
		_hide_tween.kill()
	current_quest_id = quest_id
	visible = true
	modulate.a = 1.0
	if quest_title_label:
		quest_title_label.text = title
	if quest_progress_label:
		quest_progress_label.text = "%d / %d" % [cur, target]
		quest_progress_label.remove_theme_color_override("font_color")
	if quest_badge_label:
		quest_badge_label.text = "!"

func _get_title(quest_id: String) -> String:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm:
		var qdata = qm.get_quest_data(quest_id)
		if qdata and "title" in qdata and qdata.title != "":
			return qdata.title
	return quest_id
