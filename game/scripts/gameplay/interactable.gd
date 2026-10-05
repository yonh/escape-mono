extends StaticBody3D

## F-key interaction target for the hideout room. The room controller
## raycasts for bodies in the "interactable" group and dispatches on
## `action`.

@export var prompt := ""
@export var action := &""
