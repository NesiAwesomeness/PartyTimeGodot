extends Control
class_name Card

signal rearrange(index)

@export var card_vis : Control
@export var selection : Button
@export var count_label : Label

@export var number : Control
@export var number_panel : Control

@export var card_body : Control
@export var card_holder : Control

@export var protection_label : Control

var rank = ""
var is_power_card : bool = false
var count : int = 1
var animate : bool = true

func _ready():
	add_to_group("HandListener")
	selection.disabled = true
	protection_label.hide()
	
	number.hide()
	card_vis.hide()
	
	card_body.self_modulate = Color("252826ff")

var position_tween : Tween

func update_count(_count : int, is_protected:bool=false):
	protection_label.visible = is_protected
	
	if _count == 0:
		if GoFish.booked_cards.has(rank):
			print("insert booked card animated exit here ", rank)
		queue_free()
		return
	
	if _count == count: return
	
	count_label.text = str(_count) if is_power_card else str(_count, " of ", GoFish.CARDS[rank].tier)
	number.visible = _count > 1
	
	if _count > count:
		var duration = 0.06
		
		if animate:
			if position_tween: position_tween.kill()
			position_tween = create_tween()
			position_tween.tween_property(card_body, "position:y", -32.0, duration * 2.0).set_delay(duration * 4.0)
			position_tween.chain().tween_property(card_body, "position:y", 0.0, duration * 3.0)
	count = _count

var active := false
var is_me := false

#this can only be called by cards for "ME"
func set_up(card : Dictionary):
	is_power_card = not GoFish.CARDS.has(card.rank)
	
	is_me = true
	
	selection.pressed.connect(  on_selection)
	selection.mouse_entered.connect( _on_mouse_entered )
	selection.mouse_exited.connect( _on_mouse_exited )
	selection.disabled = false
	
	rank = card.rank
	card_vis.show()
	
	var card_name : String = GoFish.PASSIVES.merged(GoFish.POWERS)[rank] if is_power_card else GoFish.CARDS[rank].name
	if not is_power_card:
		card_body.self_modulate = Color("6780baff")
		add_to_group("RegularCard")
	else:
		if GoFish.PASSIVES.has(rank):
			add_to_group("PassiveCard")
			card_body.self_modulate = Color("647843ff")
			
			match rank:
				"silver_tongue": tooltip_text = "Click and Drag"
		else:
			card_body.self_modulate = Color("db3f39ff")
			
			match rank:
				"fast_hands": tooltip_text = "Swap a random rank with someone?"
				"magnifying_glass": tooltip_text = "Reveal what you need?"
	
	for label : RichTextLabel in card_vis.get_children():
		label.text = str("[wave]",card_name,"[/wave]") if is_power_card else card_name
	
	#slide in
	var pop_duration = 0.2
	position.y = -200.0
	
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_body, "position:y", 0.0, 0.5).set_delay(pop_duration)
	
	#pop in
	var scale_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)
	scale_tween.tween_property(card_body, "scale", Vector2.ONE, pop_duration).from(Vector2.ZERO)
	
	selection.disabled = true
	await tween.finished
	
	selection.disabled = false

# Drag state variables
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _drag_tween: Tween

func _process(delta: float) -> void:
	if _is_dragging:
		global_position = global_position.lerp(_target_pos, 25.0 * delta)

func _on_selectable_gui_input(event):
	if not is_me: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			
			_drag_offset = get_global_mouse_position() - global_position
			_target_pos = global_position
			
			_is_dragging = true
			z_index = 100
			
			# Tween the rotation to 0
			if _drag_tween and _drag_tween.is_valid():
				_drag_tween.kill()
			_drag_tween = create_tween()
			_drag_tween.tween_property(
				self, "rotation", 0.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			
		elif not event.is_pressed() and _is_dragging:
			_is_dragging = false
			_perform_drop()
	
	elif event is InputEventMouseMotion and _is_dragging:
		get_tree().call_group("CardListener", "on_card_selected", '')
		_target_pos = get_global_mouse_position() - _drag_offset

func _perform_drop() -> void:
	var mouse_pos = get_global_mouse_position()
	var my_parent: Control = get_parent()
	
	if not my_parent:
		return
		
	if mouse_pos.y < my_parent.global_position.y - 200:
		rearrange.emit(get_index())
		print("Dropped too high, returning to original index.")
		return
		
	var target_rank := ""
	var cards_to_sort: Array = []
	
	for sibling in my_parent.get_children():
		if sibling is Card:
			cards_to_sort.append(sibling)
			if sibling != self and sibling.card_body.get_global_rect().has_point(mouse_pos):
				target_rank = sibling.rank
				
	if GoFish.PASSIVES.has(target_rank):
		get_tree().call_group("CardListener", "on_passive_use", rank, target_rank)
		return
		
	cards_to_sort.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var target_index: int = cards_to_sort.find(self)
	
	for i in range(cards_to_sort.size()):
		my_parent.move_child(cards_to_sort[i], i)
		
	print("Dropped rank ", rank, " onto rank ", target_rank)
	print("Repositioned to index: ", target_index)
	
	rearrange.emit(target_index)

func on_passive_update(passive : String):
	active = passive == rank
	card_body.position.y = -32.0 if active else 0.0

func _on_mouse_entered():
	var r = GoFish.CARDS[rank].name if GoFish.CARDS.has(rank) else ''
	GoFishToolTip.tooltip = tooltip_text if tooltip_text != '' else r

func _on_mouse_exited():
	GoFishToolTip.tooltip = ""

func hand_updated(is_me : bool, _full_space:bool=false):
	var center_index : float = (get_parent().get_child_count() - 1) / 2.0
	var center_offset: float = get_index() - center_index
	var target_rotation : float = center_offset * 3.6 * float(is_me)
	
	var spacing = 120.0 if is_me else 28.0
	var target_x: float = center_offset * spacing
	var target_y: float = center_offset * center_offset * 2.4 * float(is_me)
	
	var duration : float = 0.3
	# Animate the card to its new position and rotation smoothly
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position",  Vector2(target_x, target_y), duration)
	tween.tween_property(self, "rotation_degrees", target_rotation, duration).set_delay(0.25)
	tween.chain().tween_callback( func(): z_index = 0 )

func on_selection():
	if not _is_dragging: get_tree().call_group("CardListener", "on_card_selected", rank)
