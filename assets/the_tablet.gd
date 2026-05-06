extends Node3D

@onready var screen: MeshInstance3D = $"Sketchfab_model/root/GLTF_SceneRootNode/ekran_3/Object_10"
@onready var screen_viewport: SubViewport = $"Sketchfab_model/root/GLTF_SceneRootNode/ekran_3/Object_10/SubViewport"


func _ready() -> void:
	call_deferred("_bind_screen_texture")


func _bind_screen_texture() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = screen_viewport.get_texture()
	screen.set_surface_override_material(0, material)
