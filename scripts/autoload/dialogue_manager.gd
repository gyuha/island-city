extends Node
var current: DialogueData
var line_index: int = -1
var ended_physics_frame: int = -2
func is_active() -> bool:
	return current != null
func start_dialogue(data: DialogueData) -> void:
	if data == null: return
	if current != null: end_dialogue()
	current = data
	line_index = -1
	GameEvents.dialogue_started.emit(data.id)
	for id in data.quest_ids: QuestManager.start_quest(id)
	advance()
func advance() -> void:
	if current == null: return
	line_index += 1
	if line_index >= current.lines.size():
		end_dialogue()
	else:
		GameEvents.dialogue_line.emit(current.speaker, current.lines[line_index])
func end_dialogue() -> void:
	if current == null: return
	ended_physics_frame = Engine.get_physics_frames()
	current = null
	line_index = -1
	GameEvents.dialogue_ended.emit()

func can_start_interaction() -> bool:
	# Input can close UI before the next physics tick consumes just_pressed.
	return not is_active() and Engine.get_physics_frames() > ended_physics_frame + 1
