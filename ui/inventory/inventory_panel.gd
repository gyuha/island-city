extends Control

signal window_opened
signal window_closed

const ITEM_SLOT_SCENE := preload("res://ui/inventory/item_slot.tscn")

@onready var grid_container: GridContainer = %GridContainer
@onready var empty_label: Label = %EmptyLabel
@onready var close_button: Button = %CloseButton

# Item Detail Views
@onready var detail_container: Control = %DetailContainer
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_count: Label = %DetailCount
@onready var detail_badge: PanelContainer = %DetailBadge
@onready var detail_badge_label: Label = %DetailBadgeLabel
@onready var detail_icon: TextureRect = %DetailIcon

var is_open: bool = false
var _selected_id: String = ""

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close)

	var events: Node = get_node_or_null("/root/GameEvents")
	if events and events.has_signal("inventory_changed"):
		events.inventory_changed.connect(_on_inventory_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	refresh()
	window_opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	window_closed.emit()

func refresh() -> void:
	# 슬롯 청소
	for child in grid_container.get_children():
		child.queue_free()

	var inv: Node = get_node_or_null("/root/Inventory")
	var items: Dictionary = {}
	if inv and inv.has_method("get_items"):
		items = inv.get_items()

	if items.is_empty():
		if empty_label:
			empty_label.visible = true
		if detail_container:
			detail_container.visible = false
		return

	if empty_label:
		empty_label.visible = false

	var first_item_id := ""
	for item_id in items.keys():
		var count: int = items[item_id]
		var item_data = null
		if inv and inv.has_method("get_item_data"):
			item_data = inv.get_item_data(item_id)

		var slot = ITEM_SLOT_SCENE.instantiate()
		grid_container.add_child(slot)
		slot.setup(item_id, count, item_data)
		slot.item_selected.connect(_on_item_selected)

		if first_item_id == "":
			first_item_id = item_id

	# 이전에 선택한 아이템이 여전히 있으면 그것을 선택, 없으면 첫 번째 선택
	if items.has(_selected_id):
		_select_item(_selected_id)
	elif first_item_id != "":
		_select_item(first_item_id)
	else:
		if detail_container:
			detail_container.visible = false

func _on_inventory_changed(_items: Dictionary) -> void:
	if is_open:
		refresh()

func _on_item_selected(item_id: String) -> void:
	_select_item(item_id)

func _select_item(item_id: String) -> void:
	_selected_id = item_id
	var inv: Node = get_node_or_null("/root/Inventory")
	if not inv:
		return

	var count: int = inv.get_count(item_id) if inv.has_method("get_count") else 1
	var item_data = inv.get_item_data(item_id) if inv.has_method("get_item_data") else null

	if detail_container:
		detail_container.visible = true

	var display_name: String = item_id
	var desc: String = ""
	var icon_path: String = ""

	if item_data:
		if "display_name" in item_data and item_data.display_name != "":
			display_name = item_data.display_name
		if "description" in item_data and item_data.description != "":
			desc = item_data.description
		if "icon_path" in item_data and item_data.icon_path != "":
			icon_path = item_data.icon_path

	if detail_name:
		detail_name.text = display_name
	if detail_desc:
		detail_desc.text = desc if desc != "" else "상세 설명이 없습니다."
	if detail_count:
		detail_count.text = "보유 수량: %d개" % count

	var has_icon := false
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex = load(icon_path) as Texture2D
		if tex:
			has_icon = true
			if detail_icon:
				detail_icon.texture = tex
				detail_icon.visible = true
			if detail_badge:
				detail_badge.visible = false

	if not has_icon:
		if detail_icon:
			detail_icon.visible = false
		if detail_badge:
			detail_badge.visible = true
		if detail_badge_label:
			detail_badge_label.text = display_name.substr(0, 1) if display_name.length() > 0 else "?"
