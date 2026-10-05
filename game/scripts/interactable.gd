class_name Interactable
extends CSGBox3D

@export var prompt := "查看"
@export var message := "什么都没有发生。"
@export var consume_on_use := false

func interact() -> void:
	print("[INTERACT] %s | %s" % [name, message])
	if consume_on_use:
		queue_free()
