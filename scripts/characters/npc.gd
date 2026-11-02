extends Area3D
@export var prompt: String = "모루와 대화"
@export var dialogue: DialogueData = preload("res://scripts/data/dialogues/gardener.tres")
func _ready() -> void:
	CharacterVisuals.gardener($Model)
func interact(_player: Node = null) -> void:
	DialogueManager.start_dialogue(dialogue)
