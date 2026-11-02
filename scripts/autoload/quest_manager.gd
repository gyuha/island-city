extends Node
var active: Dictionary = {}
var completed: Dictionary = {}
func _ready() -> void:
	GameEvents.item_added.connect(_on_item)
	GameEvents.enemy_defeated.connect(_on_enemy)
func get_quest_data(id: String) -> QuestData:
	var path := "res://scripts/data/quests/%s.tres" % id
	return load(path) as QuestData if ResourceLoader.exists(path) else null
func start_quest(id: String) -> bool:
	var data := get_quest_data(id)
	if data == null or active.has(id) or completed.has(id): return false
	active[id] = 0
	GameEvents.quest_started.emit(id)
	if data.objective_type == "collect": active[id] = mini(Inventory.get_count(data.objective_id), data.target)
	_publish(id)
	return true
func get_progress(id: String) -> int:
	return int(active.get(id, completed.get(id, 0)))
func is_completed(id: String) -> bool:
	return completed.has(id)
func _on_item(item_id: String, amount: int) -> void:
	_advance("collect", item_id, amount)
func _on_enemy(enemy_id: String) -> void:
	_advance("defeat", enemy_id, 1)
func _advance(kind: String, objective: String, amount: int) -> void:
	for id in active.keys():
		var data := get_quest_data(id)
		if data.objective_type == kind and data.objective_id == objective:
			active[id] = mini(int(active[id]) + amount, data.target)
			_publish(id)
func _publish(id: String) -> void:
	var data := get_quest_data(id)
	GameEvents.quest_progress.emit(id, int(active[id]), data.target)
	if int(active[id]) >= data.target:
		completed[id] = active[id]
		active.erase(id)
		GameEvents.quest_completed.emit(id)
		Inventory.add_item(data.reward_item, data.reward_amount)
