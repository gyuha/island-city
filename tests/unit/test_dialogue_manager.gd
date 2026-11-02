extends GutTest

var data: DialogueData

func before_each() -> void:
	Inventory.items.clear()
	QuestManager.active.clear()
	QuestManager.completed.clear()
	DialogueManager.end_dialogue()
	data = load("res://scripts/data/dialogues/gardener.tres")

func after_each() -> void:
	DialogueManager.end_dialogue()
	QuestManager.active.clear()
	QuestManager.completed.clear()

func test_start_emits_first_line() -> void:
	watch_signals(GameEvents)
	DialogueManager.start_dialogue(data)
	assert_true(DialogueManager.is_active())
	assert_signal_emitted_with_parameters(GameEvents, "dialogue_started", ["gardener"])
	assert_signal_emitted_with_parameters(GameEvents, "dialogue_line", [data.speaker, data.lines[0]])
	assert_eq(DialogueManager.line_index, 0)

func test_advance_through_to_end() -> void:
	watch_signals(GameEvents)
	DialogueManager.start_dialogue(data)
	DialogueManager.advance()
	assert_signal_emitted_with_parameters(GameEvents, "dialogue_line", [data.speaker, data.lines[1]])
	assert_true(DialogueManager.is_active())
	DialogueManager.advance()
	assert_false(DialogueManager.is_active())
	assert_signal_emitted(GameEvents, "dialogue_ended")

func test_end_dialogue_midway() -> void:
	DialogueManager.start_dialogue(data)
	DialogueManager.end_dialogue()
	assert_false(DialogueManager.is_active())
	assert_eq(DialogueManager.line_index, -1)

func test_advance_inactive_noop() -> void:
	watch_signals(GameEvents)
	DialogueManager.advance()
	assert_signal_not_emitted(GameEvents, "dialogue_line")

func test_start_null_noop() -> void:
	DialogueManager.start_dialogue(null)
	assert_false(DialogueManager.is_active())

func test_start_links_quests() -> void:
	DialogueManager.start_dialogue(data)
	assert_true(QuestManager.active.has("flowers"))
	assert_true(QuestManager.active.has("slimes"))

func test_restart_dialogue_does_not_duplicate_quests() -> void:
	DialogueManager.start_dialogue(data)
	DialogueManager.start_dialogue(data)
	assert_eq(QuestManager.active.size(), 2)
	assert_eq(DialogueManager.line_index, 0)
