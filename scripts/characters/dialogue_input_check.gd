extends SceneTree
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func tap() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(35)
	var player = main.get_node("Player")
	var dialogue = root.get_node("DialogueManager")
	var npc: Node3D
	for candidate in get_nodes_in_group("interactable"):
		if candidate.get_script() == load("res://scripts/characters/npc.gd"): npc = candidate
	player.global_position = npc.global_position + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await frames(5)
	await tap()
	assert(dialogue.is_active() and dialogue.line_index == 0, "E starts dialogue at first line")
	# action_press updates polling state but does not dispatch _unhandled_input.
	await create_timer(1.3).timeout
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)
	print("DIALOGUE_POLL_ONLY line_index=", dialogue.line_index)
	assert(dialogue.line_index == 0, "poll-only action must not advance UI-owned dialogue")
	for i in range(2):
		await create_timer(1.3).timeout
		await tap()
	await frames(5)
	var passed: bool = not dialogue.is_active()
	print("DIALOGUE_REAL_INPUT_CHECK: ", "PASS" if passed else "FAIL", " line_index=", dialogue.line_index)
	quit(0 if passed else 1)
