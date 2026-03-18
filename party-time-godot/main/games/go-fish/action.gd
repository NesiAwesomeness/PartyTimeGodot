extends Label
class_name ActionLabel

@export var action_color : Color = Color('303030ff')

func _ready():
	$Panel.self_modulate = action_color

func set_up( color : Color ):
	action_color = color
	
	if is_inside_tree():
		_ready()
