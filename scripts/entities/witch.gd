class_name HollowWitch
extends CharacterBody2D

const POSES := {
	"south": [preload("res://assets/witch/walk/south_0.png"), preload("res://assets/witch/walk/south_1.png"), preload("res://assets/witch/walk/south_2.png"), preload("res://assets/witch/walk/south_3.png")],
	"north": [preload("res://assets/witch/walk/north_0.png"), preload("res://assets/witch/walk/north_1.png"), preload("res://assets/witch/walk/north_2.png"), preload("res://assets/witch/walk/north_3.png")],
	"east": [preload("res://assets/witch/walk/east_0.png"), preload("res://assets/witch/walk/east_1.png"), preload("res://assets/witch/walk/east_2.png"), preload("res://assets/witch/walk/east_3.png")],
	"west": [preload("res://assets/witch/walk/west_0.png"), preload("res://assets/witch/walk/west_1.png"), preload("res://assets/witch/walk/west_2.png"), preload("res://assets/witch/walk/west_3.png")],
}

var active := false
var facing := "south"
var clock := 0.0
var speed := 210.0
var movement_bounds := Rect2(90.0, 90.0, 1420.0, 887.0)
var sprite: Sprite2D
var frames: Dictionary = {}

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)
	frames = POSES
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position.y = -28
	add_child(sprite)
	_update_pose(Vector2.ZERO, 0.0)

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down") if active else Vector2.ZERO
	move_direction(direction, delta)

func move_direction(direction: Vector2, delta: float) -> void:
	speed = float(TuningStore.get_active_value("player.move.max_speed", 210.0))
	velocity = direction.normalized() * speed
	move_and_slide()
	position.x = clampf(position.x, movement_bounds.position.x, movement_bounds.end.x)
	position.y = clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)
	_update_pose(direction, delta)

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds

func _update_pose(direction: Vector2, delta: float) -> void:
	if direction.length() > 0.1:
		clock += delta
		if absf(direction.x) > absf(direction.y):
			facing = "east" if direction.x > 0 else "west"
		else:
			facing = "south" if direction.y > 0 else "north"
	else:
		clock = 0.0
	var frame := 0 if direction.length() < 0.1 else 1 + int(clock * 8.0) % 2
	if sprite != null and frames.has(facing):
		sprite.texture = frames[facing][frame]
