class_name ReinforcementCaller
extends Node
# B = call AI reinforcements, V = call a supply drop (CALL / DROP on touch).
# Transport helicopters are NOT implemented yet: reinforcements arrive by radio call and spawn behind the player.

var reinf_calls := 0
var supply_calls := 0
var status := ""
var _next_reinf := 0.0
var _next_drop := 0.0


func _unhandled_input(event: InputEvent) -> void:
    if Game.ended or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode == KEY_B:
        call_reinforcements()
    elif event.keycode == KEY_V:
        call_supply()


func _process(_d: float) -> void:
    if Game.ended:
        return
    if Game.touch_take("call"):
        call_reinforcements()
    if Game.touch_take("drop"):
        call_supply()


func call_reinforcements() -> void:
    var t := Game.now()
    if t < _next_reinf:
        status = "Reinforcements on cooldown"
        return
    _next_reinf = t + 45.0
    reinf_calls += 1
    status = "Reinforcements inbound..."
    await get_tree().create_timer(6.0).timeout
    var p := get_parent() as Player
    if p == null:
        return
    var center := p.global_position + p.global_transform.basis.z * 25.0
    var n := 0
    for i in 4:
        var pos := center + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
        if SoldierFactory.spawn(pos, 0, Game.Diff.HARD, p) != null:
            n += 1
    status = "Reinforcements arrived (%d)" % n if n > 0 else "Reinforcements failed: AI limit or no ground"
    await get_tree().create_timer(4.0).timeout
    status = ""


func call_supply() -> void:
    var t := Game.now()
    if t < _next_drop:
        status = "Supply drop on cooldown"
        return
    _next_drop = t + 60.0
    supply_calls += 1
    status = "Supply drop inbound..."
    await get_tree().create_timer(3.0).timeout
    var p := get_parent() as Player
    if p == null:
        return
    var land := p.global_position + (-p.global_transform.basis.z) * 8.0
    var crate := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(1.2, 1.2, 1.2)
    crate.mesh = bm
    crate.material_override = Game.mat(Color(0.3, 0.75, 0.3))
    Game.world.add_child(crate)
    crate.global_position = Vector3(land.x, 40.0, land.z)
    var tw := create_tween()
    tw.tween_property(crate, "global_position:y", 0.6, 3.0)
    await tw.finished
    crate.queue_free()
    SupplyStation.create(Vector3(land.x, 0.0, land.z), 2, 0, 90.0)
    status = "Supply drop landed (90 s)"
    await get_tree().create_timer(4.0).timeout
    status = ""
