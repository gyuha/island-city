extends GutTest

func before_each() -> void:
	Inventory.items.clear()
	QuestManager.active.clear()
	QuestManager.completed.clear()

func after_each() -> void:
	Inventory.items.clear()
	QuestManager.active.clear()
	QuestManager.completed.clear()

func test_start_quest() -> void:
	watch_signals(GameEvents)
	assert_true(QuestManager.start_quest("flowers"))
	assert_true(QuestManager.active.has("flowers"))
	assert_eq(QuestManager.get_progress("flowers"), 0)
	assert_signal_emitted_with_parameters(GameEvents, "quest_started", ["flowers"])

func test_start_unknown_quest_false() -> void:
	assert_false(QuestManager.start_quest("nope"))

func test_duplicate_start_blocked() -> void:
	assert_true(QuestManager.start_quest("flowers"))
	assert_false(QuestManager.start_quest("flowers"))

func test_start_blocked_after_completed() -> void:
	QuestManager.start_quest("slimes")
	for i in 3:
		GameEvents.enemy_defeated.emit("slime")
	assert_true(QuestManager.is_completed("slimes"))
	assert_false(QuestManager.start_quest("slimes"))

func test_collect_progress() -> void:
	QuestManager.start_quest("flowers")
	Inventory.add_item("wildflower", 2)
	assert_eq(QuestManager.get_progress("flowers"), 2)

func test_collect_ignores_other_items() -> void:
	QuestManager.start_quest("flowers")
	Inventory.add_item("shell", 2)
	assert_eq(QuestManager.get_progress("flowers"), 0)

func test_existing_items_counted_on_start() -> void:
	Inventory.add_item("wildflower", 3)
	QuestManager.start_quest("flowers")
	assert_eq(QuestManager.get_progress("flowers"), 3)

func test_defeat_progress() -> void:
	QuestManager.start_quest("slimes")
	GameEvents.enemy_defeated.emit("slime")
	assert_eq(QuestManager.get_progress("slimes"), 1)
	GameEvents.enemy_defeated.emit("other")
	assert_eq(QuestManager.get_progress("slimes"), 1)

func test_collect_completion_gives_reward() -> void:
	watch_signals(GameEvents)
	QuestManager.start_quest("flowers")
	Inventory.add_item("wildflower", 5)
	assert_true(QuestManager.is_completed("flowers"))
	assert_false(QuestManager.active.has("flowers"))
	assert_signal_emitted_with_parameters(GameEvents, "quest_completed", ["flowers"])
	var data := QuestManager.get_quest_data("flowers")
	assert_gt(data.reward_amount, 0)
	assert_eq(Inventory.get_count(data.reward_item), data.reward_amount, "보상이 인벤토리에 들어감")

func test_defeat_completion_gives_reward() -> void:
	QuestManager.start_quest("slimes")
	for i in 3:
		GameEvents.enemy_defeated.emit("slime")
	assert_true(QuestManager.is_completed("slimes"))
	assert_eq(Inventory.get_count("feather"), 1)

func test_progress_capped_and_no_double_reward() -> void:
	QuestManager.start_quest("slimes")
	for i in 6:
		GameEvents.enemy_defeated.emit("slime")
	assert_eq(Inventory.get_count("feather"), 1)
	assert_eq(QuestManager.get_progress("slimes"), 3)

func test_get_quest_data() -> void:
	assert_not_null(QuestManager.get_quest_data("flowers"))
	assert_null(QuestManager.get_quest_data("nope"))
