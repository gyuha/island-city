extends GutTest

const ITEMS := ["wildflower", "slime_jelly", "shell", "feather", "sea_pearl"]

func test_items_load() -> void:
	for id in ITEMS:
		var r := load("res://scripts/data/items/%s.tres" % id)
		assert_true(r is ItemData, "ItemData: " + id)
		assert_eq(r.id, id)
		assert_ne(r.display_name, "", "display_name: " + id)

func test_quests_load() -> void:
	var f := load("res://scripts/data/quests/flowers.tres") as QuestData
	assert_not_null(f)
	assert_eq([f.id, f.objective_type, f.objective_id, f.target], ["flowers", "collect", "wildflower", 5])
	var s := load("res://scripts/data/quests/slimes.tres") as QuestData
	assert_not_null(s)
	assert_eq([s.id, s.objective_type, s.objective_id, s.target], ["slimes", "defeat", "slime", 3])
	for q in [f, s]:
		assert_eq(q.reward_item, "feather")
		assert_eq(q.reward_amount, 1)
		assert_not_null(Inventory.get_item_data(q.reward_item), "보상 아이템이 존재해야 함")

func test_dialogue_loads() -> void:
	var d := load("res://scripts/data/dialogues/gardener.tres") as DialogueData
	assert_not_null(d)
	assert_eq(d.id, "gardener")
	assert_eq(d.lines.size(), 2)
	assert_eq(Array(d.quest_ids), ["flowers", "slimes"])
	for id in d.quest_ids:
		assert_not_null(QuestManager.get_quest_data(id))

func test_item_icons_exist_if_declared() -> void:
	for id in ITEMS:
		var r: ItemData = load("res://scripts/data/items/%s.tres" % id)
		if r.icon_path != "":
			assert_true(ResourceLoader.exists(r.icon_path), "아이콘 경로 누락: " + r.icon_path)
