extends VBoxContainer

@export var max_toasts: int = 5
@export var toast_duration: float = 2.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var events: Node = get_node_or_null("/root/GameEvents")
	if events and events.has_signal("item_added"):
		events.item_added.connect(_on_item_added)

func _on_item_added(item_id: String, amount: int) -> void:
	if amount <= 0:
		return

	var name_str := item_id
	var icon_path := ""

	var inv: Node = get_node_or_null("/root/Inventory")
	if inv:
		var item_data = inv.get_item_data(item_id)
		if item_data:
			if "display_name" in item_data and item_data.display_name != "":
				name_str = item_data.display_name
			if "icon_path" in item_data and item_data.icon_path != "":
				icon_path = item_data.icon_path

	_spawn_toast(name_str, amount, icon_path)

func _spawn_toast(item_name: String, amount: int, icon_path: String) -> void:
	# 오래된 토스트 개수 초과 시 정리
	while get_child_count() >= max_toasts:
		var old = get_child(0)
		old.queue_free()
		remove_child(old)

	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.theme = load("res://ui/theme.tres")

	# StyleBox for toast pill
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1098, 0.149, 0.2196, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.85, 0.7, 0.4)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_right = 18
	sb.corner_radius_bottom_left = 18
	sb.shadow_color = Color(0.04, 0.07, 0.12, 0.45)
	sb.shadow_size = 6
	sb.content_margin_left = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 6.0
	toast.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	toast.add_child(hbox)

	# Icon or Badge
	var has_valid_tex := false
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex = load(icon_path) as Texture2D
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(28, 28)
			hbox.add_child(tr)
			has_valid_tex = true

	if not has_valid_tex:
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(26, 26)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.24, 0.78, 0.65, 0.95)
		b_sb.corner_radius_top_left = 13
		b_sb.corner_radius_top_right = 13
		b_sb.corner_radius_bottom_right = 13
		b_sb.corner_radius_bottom_left = 13
		badge.add_theme_stylebox_override("panel", b_sb)

		var lbl := Label.new()
		lbl.text = item_name.substr(0, 1) if item_name.length() > 0 else "+"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.1, 0.18, 0.15, 1.0))
		badge.add_child(lbl)
		hbox.add_child(badge)

	# Text: "[아이템명] +[수량]"
	var text_lbl := Label.new()
	text_lbl.text = "%s +%d" % [item_name, amount]
	text_lbl.add_theme_font_size_override("font_size", 14)
	text_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hbox.add_child(text_lbl)

	add_child(toast)

	# Entrance & Exit Tween
	toast.modulate.a = 0.0
	toast.position.x = 20.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(toast_duration)
	tween.tween_property(toast, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(toast.queue_free)
