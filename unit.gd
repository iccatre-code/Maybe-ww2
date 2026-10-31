class_name Unit
extends CharacterBody3D
# Shared health/armor/team logic for the player and AI soldiers.

signal died(unit, killer)
signal damaged(amount, source)

var team := 0
var max_health := 100.0
var health := 100.0
var max_armor := 0.0
var armor := 0.0
var last_noise := -99.0   # time of last shot (AI hearing)
var lit := false          # flashlight on (visible at night)
var is_player := false
var weapon = null         # Weapon node (untyped to avoid cyclic class refs)


func init_stats(t: int, hp: float, arm: float) -> void:
    team = t
    max_health = hp
    health = hp
    max_armor = arm
    armor = arm


func is_dead() -> bool:
    return health <= 0.0


func head_height() -> float:
    return 1.8


func take_damage(amount: float, source: Node, headshot: bool) -> void:
    if is_dead():
        return
    if headshot:
        amount *= 2.0
    elif armor > 0.0:
        var absorbed := minf(armor, amount * 0.6)
        armor -= absorbed
        amount -= absorbed
    health = maxf(0.0, health - amount)
    damaged.emit(amount, source)
    if health <= 0.0:
        died.emit(self, source)


func heal(amount: float) -> void:
    if not is_dead():
        health = minf(max_health, health + amount)
