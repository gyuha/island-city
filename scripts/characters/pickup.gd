extends Area3D
@export var item_id: String = "wildflower"
@export var amount: int = 1
@export var prompt: String = "야생화 채집"
var collected: bool = false
func _ready() -> void:
	var flower := SphereMesh.new()
	flower.radius = 0.14
	flower.height = 0.19
	CharacterVisuals.mesh(self, flower, Vector3(0, 0.3, 0), Color("ffe4ec") if item_id == "wildflower" else Color("57d3b6"))
	var stem := CylinderMesh.new()
	stem.top_radius = 0.025
	stem.bottom_radius = 0.025
	stem.height = 0.3
	CharacterVisuals.mesh(self, stem, Vector3(0, 0.15, 0), Color("348832"))
func interact(_player: Node = null) -> void:
	if collected: return
	collected = true
	Inventory.add_item(item_id, amount)
	GameEvents.interact_prompt_changed.emit("", false)
	remove_from_group("interactable")
	queue_free()
