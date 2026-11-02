extends CanvasLayer

@onready var damage_flash: Control = %DamageFlash
@onready var status_bars: PanelContainer = %StatusBars
@onready var quest_tracker: PanelContainer = %QuestTracker
@onready var interact_prompt: PanelContainer = %InteractPrompt
@onready var toast_manager: VBoxContainer = %ToastManager

@onready var dialogue_box: Control = %DialogueBox
@onready var inventory_panel: Control = %InventoryPanel
@onready var world_map_panel: Control = %WorldMapPanel

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _was_paused_by_ui: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if inventory_panel:
		if inventory_panel.has_signal("window_opened"):
			inventory_panel.window_opened.connect(_on_inventory_opened)
		if inventory_panel.has_signal("window_closed"):
			inventory_panel.window_closed.connect(_on_inventory_closed)

	if world_map_panel:
		if world_map_panel.has_signal("window_opened"):
			world_map_panel.window_opened.connect(_on_map_opened)
		if world_map_panel.has_signal("window_closed"):
			world_map_panel.window_closed.connect(_on_map_closed)

	if dialogue_box:
		if dialogue_box.has_signal("dialogue_active_changed"):
			dialogue_box.dialogue_active_changed.connect(_on_dialogue_active_changed)

func _unhandled_input(event: InputEvent) -> void:
	# 창 간의 전환 처리: 인벤토리 열린 상태에서 월드맵 키 누를 때 또는 그 반대
	if event.is_action_pressed("inventory"):
		if world_map_panel and ("is_open" in world_map_panel) and world_map_panel.is_open:
			world_map_panel.close()
			if inventory_panel:
				inventory_panel.open()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("world_map"):
		if inventory_panel and ("is_open" in inventory_panel) and inventory_panel.is_open:
			inventory_panel.close()
			if world_map_panel:
				world_map_panel.open()
			get_viewport().set_input_as_handled()

func _on_inventory_opened() -> void:
	_enter_modal()

func _on_inventory_closed() -> void:
	if not _is_any_modal_open():
		_exit_modal()

func _on_map_opened() -> void:
	_enter_modal()

func _on_map_closed() -> void:
	if not _is_any_modal_open():
		_exit_modal()

func _on_dialogue_active_changed(is_active: bool) -> void:
	if is_active:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			_previous_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if not _is_any_modal_open() and _previous_mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = _previous_mouse_mode

func _is_any_modal_open() -> bool:
	var inv_open: bool = false
	if inventory_panel and "is_open" in inventory_panel:
		inv_open = bool(inventory_panel.is_open)

	var map_open: bool = false
	if world_map_panel and "is_open" in world_map_panel:
		map_open = bool(world_map_panel.is_open)

	return inv_open or map_open

func _enter_modal() -> void:
	if not _was_paused_by_ui:
		_previous_mouse_mode = Input.mouse_mode
		_was_paused_by_ui = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_modal() -> void:
	if _was_paused_by_ui:
		_was_paused_by_ui = false
		get_tree().paused = false
		if _previous_mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = _previous_mouse_mode
