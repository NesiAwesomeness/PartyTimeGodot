extends CharacterBody2D

const SPEED = 300.0

func _enter_tree():
	set_multiplayer_authority(name.to_int())

# Only move if I am the one controlling this player.
func _physics_process(_delta):
	if not multiplayer.multiplayer_peer: return
	
	if is_multiplayer_authority():
		var direction = Input.get_vector(
			"ui_left", "ui_right", "ui_up", "ui_down"
		)
		
		if direction:
			velocity = direction * SPEED
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		move_and_slide()
