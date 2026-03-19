extends Label
class_name GoFishToolTip

# The global static variable your cards will modify
static var tooltip: String = ""

# Internal state tracking
var _current_tooltip: String = ""
var active_tween: Tween

# Positioning constants
var _base_offset: Vector2 = Vector2(40, -32)
var _anim_offset_y: float = 0.0 # This is what we will actually tween!

func _ready() -> void:
	# Start completely invisible and hidden
	modulate.a = 0.0
	z_index = 101
	visible = false

func _process(_delta: float) -> void:
	# 1. Check if a card has changed the static tooltip variable
	if tooltip != _current_tooltip:
		_current_tooltip = tooltip
		if _current_tooltip == "":
			_animate_hide()
		else:
			# Update the text before showing
			text = _current_tooltip
			_animate_show()

	# 2. If it's visible, lock it to the mouse + offset + the tweened animation value
	if visible:
		global_position = get_global_mouse_position() + _base_offset + Vector2(0, _anim_offset_y)


func _animate_show() -> void:
	visible = true
	
	# Kill any ongoing animations to prevent overlapping tweens
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	
	# Start the animation slightly lower (15 pixels down)
	_anim_offset_y = 15.0 
	
	# Fade in and move up to 0 offset over 0.2 seconds
	active_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	active_tween.tween_property(self, "_anim_offset_y", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_hide() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	
	# Fade out and move down (15 pixels) over 0.2 seconds
	active_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	active_tween.tween_property(self, "_anim_offset_y", 15.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.chain().tween_callback( hide )
