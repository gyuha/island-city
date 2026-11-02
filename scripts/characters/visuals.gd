class_name CharacterVisuals
extends RefCounted
static func mesh(parent: Node3D, shape: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = position
	node.material_override = toon_material(color)
	parent.add_child(node)
	return node
static func asset(parent: Node3D, path: String) -> bool:
	if not ResourceLoader.exists(path): return false
	var scene := load(path) as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	apply_toon(instance, toon_material(Color.WHITE))
	parent.add_child(instance)
	return true
static func explorer(parent: Node3D, color: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.23
	body.height = 0.58
	mesh(parent, body, Vector3(0, 0.36, 0), color)
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.48
	mesh(parent, head, Vector3(0, 0.79, 0), Color("e2c98f"))
	var pack := BoxMesh.new()
	pack.size = Vector3(0.35, 0.38, 0.18)
	mesh(parent, pack, Vector3(0, 0.48, 0.22), Color("2b8277"))

static func toon_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/toon.gdshader")
	material.set_shader_parameter("albedo", color)
	material.set_shader_parameter("rim_strength", 0.25)
	return material

static func apply_toon(node: Node, material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		apply_toon(child, material)

static func ellipsoid(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var result := mesh(parent, sphere, position, color)
	result.scale = size
	return result

static func gardener(parent: Node3D) -> void:
	# Pear-shaped work dress, broad cream apron, side basket and leafy cap.
	var dress := CylinderMesh.new()
	dress.top_radius = 0.17
	dress.bottom_radius = 0.32
	dress.height = 0.48
	mesh(parent, dress, Vector3(0, 0.36, 0), Color("387e70"))
	ellipsoid(parent, Vector3(0, 0.36, -0.19), Vector3(0.43, 0.43, 0.12), Color("efe0b4"))
	ellipsoid(parent, Vector3(0, 0.47, -0.26), Vector3(0.23, 0.14, 0.035), Color("c99456"))
	ellipsoid(parent, Vector3(0, 0.78, 0), Vector3(0.46, 0.43, 0.42), Color("f3d5ae"))
	ellipsoid(parent, Vector3(0, 0.89, 0.045), Vector3(0.49, 0.25, 0.44), Color("694635"))
	ellipsoid(parent, Vector3(-0.20, 0.81, 0.13), Vector3(0.22, 0.22, 0.22), Color("694635"))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.20
	cap.bottom_radius = 0.25
	cap.height = 0.12
	mesh(parent, cap, Vector3(0, 0.99, 0), Color("81d465"))
	for x in [-0.085, 0.085]:
		ellipsoid(parent, Vector3(x, 0.79, -0.203), Vector3(0.035, 0.05, 0.025), Color("254633"))
		ellipsoid(parent, Vector3(x, 0.08, -0.035), Vector3(0.16, 0.16, 0.24), Color("7a4f30"))
	for sign_value in [-1.0, 1.0]:
		var arm := ellipsoid(parent, Vector3(sign_value * 0.26, 0.48, -0.015), Vector3(0.13, 0.31, 0.14), Color("4eb790"))
		arm.rotation.z = sign_value * 0.3
		ellipsoid(parent, Vector3(sign_value * 0.30, 0.34, -0.02), Vector3(0.12, 0.12, 0.12), Color("f3d5ae"))
	var basket := CylinderMesh.new()
	basket.top_radius = 0.19
	basket.bottom_radius = 0.13
	basket.height = 0.24
	mesh(parent, basket, Vector3(0.40, 0.29, -0.02), Color("c99456"))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.13
	handle.outer_radius = 0.16
	var handle_node := mesh(parent, handle, Vector3(0.40, 0.46, -0.02), Color("a8763e"))
	handle_node.rotation.x = PI / 2.0
	for i in range(4):
		var angle := float(i) * TAU / 4.0
		ellipsoid(parent, Vector3(0.40 + cos(angle) * 0.09, 0.44, -0.02 + sin(angle) * 0.09), Vector3(0.13, 0.14, 0.12), Color("81d465"))
