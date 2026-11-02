extends Node
var items: Dictionary = {}
func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0 or get_item_data(item_id) == null: return
	items[item_id] = get_count(item_id) + amount
	GameEvents.item_added.emit(item_id, amount)
	GameEvents.inventory_changed.emit(items.duplicate())
func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount: return false
	items[item_id] -= amount
	if items[item_id] == 0: items.erase(item_id)
	GameEvents.inventory_changed.emit(items.duplicate())
	return true
func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))
func get_items() -> Dictionary:
	return items.duplicate()
func get_item_data(item_id: String) -> ItemData:
	var path := "res://scripts/data/items/%s.tres" % item_id
	return load(path) as ItemData if ResourceLoader.exists(path) else null
