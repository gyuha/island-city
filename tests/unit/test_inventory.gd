extends GutTest

func before_each() -> void:
	Inventory.items.clear()

func after_each() -> void:
	Inventory.items.clear()

func test_add_item_increases_count() -> void:
	Inventory.add_item("wildflower", 2)
	assert_eq(Inventory.get_count("wildflower"), 2)
	Inventory.add_item("wildflower")
	assert_eq(Inventory.get_count("wildflower"), 3)

func test_add_unknown_item_ignored() -> void:
	Inventory.add_item("no_such_item", 3)
	assert_eq(Inventory.get_count("no_such_item"), 0)
	assert_true(Inventory.get_items().is_empty())

func test_add_nonpositive_ignored() -> void:
	Inventory.add_item("shell", 0)
	Inventory.add_item("shell", -2)
	assert_eq(Inventory.get_count("shell"), 0)

func test_remove_item_success() -> void:
	Inventory.add_item("shell", 3)
	assert_true(Inventory.remove_item("shell", 2))
	assert_eq(Inventory.get_count("shell"), 1)
	assert_true(Inventory.remove_item("shell", 1))
	assert_false(Inventory.get_items().has("shell"), "0개가 되면 항목 제거")

func test_remove_insufficient_returns_false_without_change() -> void:
	Inventory.add_item("shell", 1)
	assert_false(Inventory.remove_item("shell", 2))
	assert_eq(Inventory.get_count("shell"), 1)
	assert_false(Inventory.remove_item("feather", 1))

func test_get_items_returns_copy() -> void:
	Inventory.add_item("shell", 1)
	var c := Inventory.get_items()
	c["shell"] = 99
	assert_eq(Inventory.get_count("shell"), 1)

func test_get_item_data() -> void:
	assert_not_null(Inventory.get_item_data("wildflower"))
	assert_null(Inventory.get_item_data("nope"))

func test_signals_emitted() -> void:
	watch_signals(GameEvents)
	Inventory.add_item("feather", 2)
	assert_signal_emitted_with_parameters(GameEvents, "item_added", ["feather", 2])
	assert_signal_emitted(GameEvents, "inventory_changed")
