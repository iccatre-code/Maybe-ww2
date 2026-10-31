class_name Destructible
extends StaticBody3D
# Prebuilt 3-stage destruction (intact -> damaged -> heavily damaged -> removed). No physics debris.
# StaticBody3D without this script (boundary, hills) is indestructible.

var max_hp := 100.0
var hp := 100.0
var dead := false
var stage := 0
var mesh: MeshInstance3D
var base_color := Color.WHITE


func setup(health: float, c: Color) -> void:
    max_hp = health
    hp = health
    base_color = c


func is_dead() -> bool:
    return dead


func take_damage(amount: float, _source: Node, _headshot: bool) -> void:
    if dead:
        return
    hp -= amount
    var f := hp / max_hp
    if f <= 0.0:
        dead = true
        visible = false
        for c in get_children():
            if c is CollisionShape3D:
                c.set_deferred("disabled", true)
        Game.impact(global_position, Vector3.UP)
        return
    var ns := 0
    if f < 0.34:
        ns = 2
    elif f < 0.67:
        ns = 1
    if ns != stage:
        stage = ns
        (mesh.material_override as StandardMaterial3D).albedo_color = base_color.lerp(Color.BLACK, 0.25 * ns)
