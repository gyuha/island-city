extends Node3D
func _ready() -> void:
	var water := Area3D.new()
	water.name = "WaterVolume"
	water.add_to_group("water_volume")
	water.collision_layer = 8
	water.collision_mask = 2
	water.position = Vector3(7, -1.5, 0)
	water.set_meta("surface_y", 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 12)
	shape.shape = box
	water.add_child(shape)
	add_child(water)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(8, 0.05, 12)
	CharacterVisuals.mesh(self, mesh, Vector3(7, 0, 0), Color("57d3b6"))
	for i in range(6):
		var flower := preload("res://scenes/characters/pickup_flower.tscn").instantiate()
		add_child(flower)
		flower.position = Vector3(-4 + i, 0.3, -2)
