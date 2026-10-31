class_name SquadCommander
extends Node
# F1 Follow, F2 Defend, F3 Attack, F4 Hold, F5 Regroup, T = cycle (CMD on touch).
# Defend / Attack use the point you are looking at.

var current := 1                 # Game.Order.FOLLOW
var issued_count := 0
var _ci := -1
var _cycle := [1, 2, 3, 4, 5]    # FOLLOW, DEFEND, ATTACK, HOLD, REGROUP


func _unhandled_input(event: InputEvent) -> void:
    if Game.ended or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F1: issue(1)
        KEY_F2: issue(2)
        KEY_F3: issue(3)
        KEY_F4: issue(4)
        KEY_F5: issue(5)
        KEY_T: _next()


func _process(_d: float) -> void:
    if not Game.ended and Game.touch_take("cmd"):
        _next()


func _next() -> void:
    _ci = (_ci + 1) % _cycle.size()
    issue(_cycle[_ci])


func issue(o: int) -> void:
    var p := get_parent() as Player
    if p == null or p.is_dead():
        return
    current = o
    issued_count += 1
    var pt := p.global_position
    if o == 3 or o == 2:
        var from := p.cam.global_position
        var q := PhysicsRayQueryParameters3D.create(from, from + (-p.cam.global_transform.basis.z) * 150.0)
        q.exclude = [p.get_rid()]
        var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
        if not hit.is_empty():
            pt = hit.position
    for n in get_tree().get_nodes_in_group("soldiers"):
        var s := n as Soldier
        if s == null or s.state == Soldier.State.DEAD or s.team != p.team:
            continue
        s.order = o
        s.leader = p
        s.order_point = pt
