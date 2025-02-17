extends NodeState

@export var character: CharacterBody2D
@export var animation_player: AnimationPlayer
@export var navigation_agent: NavigationAgent2D
@export var speed : float = 50.0

var location
var counter : int = 1
var tracking_counter : int = 1

@onready var sprite_2d: Sprite2D = $"../../Sprite2D"

@onready var seeking_zone: CollisionPolygon2D = $"../../seekingArea/seeking_zone"
@onready var seeking_zone_left: CollisionPolygon2D = $"../../seekingArea/seeking_zone_left"
@onready var seeking_zone_right: CollisionPolygon2D = $"../../seekingArea/seeking_zone_right"


func _ready() -> void:
	navigation_agent.velocity_computed.connect(on_safe_velocity_computed)
	call_deferred("character_setup")

func character_setup() -> void:
	await get_tree().physics_frame
	
	set_movement_target()

func set_movement_target() -> void:
	var target_position : Vector2 = GlobalTrackingValues.last_reported_kitty_location
	navigation_agent.target_position = target_position


func _on_process(_delta : float) -> void:
	pass

func _on_physics_process(_delta : float) -> void:
	set_speed()
	if GlobalTrackingValues.game_paused:
		character.velocity = Vector2.ZERO
		return
	 
	if GlobalTrackingValues.game_over:
		character.velocity = Vector2.ZERO
		transition.emit("idle")
		return
	
	if navigation_agent.is_navigation_finished():
		set_movement_target()
		return
	
	tracking_location()
	
	if character.last_chase_tracking:
		if tracking_counter < 30:
			tracking_counter += 1
		else:
			tracking_counter == 1
			set_movement_target()
	
	var target_position : Vector2 = navigation_agent.get_next_path_position()
	var target_direction : Vector2 = character.global_position.direction_to(target_position)
	sprite_2d.flip_h = target_direction.x < 0
	if target_direction.x < 0:
		seeking_zone_left.disabled = false
		seeking_zone_left.visible = true
		seeking_zone_right.disabled = true
		seeking_zone_right.visible = false
	else:
		seeking_zone_left.disabled = true
		seeking_zone_left.visible = false
		seeking_zone_right.disabled = false
		seeking_zone_right.visible = true
	
	var velocity: Vector2 = target_direction * speed
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = velocity
	else:
		character.velocity = velocity
		character.move_and_slide()


func on_safe_velocity_computed(safe_velocity: Vector2) -> void:
	character.velocity = safe_velocity
	character.move_and_slide()

func tracking_location() -> void:
	if location == character.global_position:
		counter += 1
		print ("Supervisor in same location for: ", counter , " frames")
		if counter == 3:
			set_movement_target()
			navigation_agent.navigation_finished.emit()
			print("Sup is stuck, moving to idle")
			character.velocity = Vector2.ZERO
			transition.emit("idle")
	
	location = character.global_position

func _on_next_transitions() -> void:	
	if GlobalTrackingValues.game_paused:
		return
	
	if GlobalTrackingValues.game_over:
		navigation_agent.navigation_finished.emit()
		character.velocity = Vector2.ZERO
		transition.emit("idle")
		return
	
	if !character.tracking_kitty && !character.last_chase_tracking && !GlobalTrackingValues.game_over:
		navigation_agent.navigation_finished.emit()
		character.velocity = Vector2.ZERO
		transition.emit("idle")
		return

func _on_enter() -> void:
	set_movement_target()
	location = character.global_position
	counter = 1
	tracking_counter = 1
	animation_player.play("run")
	sprite_2d.flip_h = false
	seeking_zone.disabled = true
	seeking_zone.visible = false
	seeking_zone_left.disabled = true
	seeking_zone_left.visible = false
	seeking_zone_right.disabled = false
	seeking_zone_right.visible = true


func _on_exit() -> void:
	animation_player.stop()
	$"../../emotionAnimation".play("bounce")
	seeking_zone.disabled = false
	seeking_zone.visible = true
	seeking_zone_left.disabled = true
	seeking_zone_left.visible = false
	seeking_zone_right.disabled = true
	seeking_zone_right.visible = false

func set_speed() -> void:
	var reported_level = GlobalTrackingValues.productivity_level()
	var percent : float = reported_level * 0.01
	match GlobalTrackingValues.difficulty_level:
		0:
			speed = 30 + (percent * 15)
		1:
			speed = 35 + (percent * 15)
		2:
			speed = 40 + (percent * 15)
		3:
			speed = 40 + (percent * 20)
	#print("sup speed: ", speed)
	#print("sup percent: ", percent)
	#print("reported levels: ", reported_level )
