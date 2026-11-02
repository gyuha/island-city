extends SceneTree
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://scenes/characters/sandbox.tscn").instantiate()
	root.add_child(scene)
	await frames(15)
	var player = scene.get_node("Player")
	var events = root.get_node("GameEvents")
	var inventory = root.get_node("Inventory")
	var quests = root.get_node("QuestManager")
	var dialogue = root.get_node("DialogueManager")
	check(player.state == "idle", "ground idle")
	# Reproduce the autoplay's ALWAYS ancestor while the map pauses physics.
	scene.process_mode = Node.PROCESS_MODE_ALWAYS
	var paused_position: Vector3 = player.global_position
	player.velocity = Vector3.DOWN * 4.0
	paused = true
	await frames(8)
	check(player.global_position == paused_position, "player freezes while map pauses under ALWAYS ancestor")
	paused = false
	player.velocity = Vector3.ZERO
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await frames(15)
	check(player.state == "walk" and player.global_position.distance_to(start) > 0.2, "camera relative movement")
	Input.action_release("move_forward")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(5)
	check(not player.is_on_floor(), "jump leaves floor")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.gliding and player.state == "glide", "air jump starts glide")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(not player.gliding, "air jump cancels glide")
	player.global_position = Vector3(7, -0.35, 0)
	player.velocity = Vector3.ZERO
	await frames(12)
	check(player.state == "swim", "water area triggers swimming")
	Input.action_press("dive")
	await frames(30)
	check(player.underwater and player.state == "dive", "dive enters underwater state")
	Input.action_release("dive")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("jump")
	check(not player.underwater, "jump surfaces")
	quests.start_quest("flowers")
	inventory.add_item("wildflower", 5)
	check(quests.is_completed("flowers"), "collection quest completes")
	quests.start_quest("slimes")
	for i in range(3): events.enemy_defeated.emit("slime")
	check(quests.is_completed("slimes"), "defeat quest completes")
	dialogue.start_dialogue(load("res://scripts/data/dialogues/gardener.tres"))
	check(dialogue.is_active(), "dialogue starts")
	dialogue.advance()
	dialogue.advance()
	check(not dialogue.is_active(), "dialogue ends")
	player.respawn()
	player.invulnerability = 0
	player.take_damage(10)
	player.take_damage(10)
	check(player.health == player.max_health - 10, "damage invulnerability")
	var slime = scene.get_node("Slime")
	slime.set_physics_process(false)
	player.facing = Vector3.FORWARD
	slime.global_position = player.global_position + Vector3(0, 0, -0.8)
	player.attack()
	await frames(15)
	check(slime.health == slime.max_health - player.attack_damage, "melee hitbox damages once per swing")
	slime.take_damage(999)
	await frames(2)
	check(not is_instance_valid(slime), "enemy death and pickup drop")
	print("GAMEPLAY_SELF_CHECK: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
