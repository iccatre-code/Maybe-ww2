class_name PracticeTarget
extends StaticBody3D
# Training-ground target: falls when hit enough, resets after 4 s.

static var down_count := 0
var hp := 30.0
var down := false
var up_pos := Vector3.ZERO


func _ready() -> void:
    up_pos = position


func is_dead() -> bool:
    return down


func take_damage(amount: float, _source: Node, headshot: bool) -> void:
    if down:
        return
    hp -= amount * (2.0 if headshot else 1.0)
    if hp > 0.0:
        return
    down = true
    PracticeTarget.down_count += 1
    rotation.x = deg_to_rad(-85.0)
    position = up_pos + Vector3.DOWN * 0.7
    get_tree().create_timer(4.0).timeout.connect(_reset)


func _reset() -> void:
    down = false
    hp = 30.0
    rotation.x = 0.0
    position = up_pos
