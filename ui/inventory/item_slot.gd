extends Button

signal item_selected(item_id: String)

@onready var icon_rect: TextureRect = %IconRect
@onready var badge_panel: PanelContainer = %BadgePanel
@onready var badge_label: Label = %BadgeLabel
@onready var count_label: Label = %CountLabel
@onready var name_label: Label = %NameLabel

var item_id: String = ""
var count: int = 0
var item_data = null

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(p_item_id: String, p_count: int, p_data) -> void:
	item_id = p_item_id
	count = p_count
	item_data = p_data

	var display_name: String = item_id
	var icon_path: String = ""
	if item_data:
		if "display_name" in item_data and item_data.display_name != "":
			display_name = item_data.display_name
		if "icon_path" in item_data and item_data.icon_path != "":
			icon_path = item_data.icon_path

	if name_label:
		name_label.text = display_name
	if count_label:
		count_label.text = "x%d" % count

	# 아이콘 경로 확인
	var has_icon := false
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex = load(icon_path) as Texture2D
		if tex:
			has_icon = true
			if icon_rect:
				icon_rect.texture = tex
				icon_rect.visible = true
			if badge_panel:
				badge_panel.visible = false

	if not has_icon:
		if icon_rect:
			icon_rect.visible = false
		if badge_panel:
			badge_panel.visible = true
		if badge_label:
			badge_label.text = display_name.substr(0, 1) if display_name.length() > 0 else "?"

func _on_pressed() -> void:
	item_selected.emit(item_id)
