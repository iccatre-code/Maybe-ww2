class_name SupplyStation
extends Node3D
# Field hospital / ammo depot: heals and resupplies friendly units inside the radius.

var kind := 2            # 0 medical, 1 ammo, 2 both
var team := 0
var radius := 5.0
var heal_per_sec := 12.0
var _next_ammo := 0.0


static func create(pos: Vector3, k: int, t: int, lifetime: float) -> SupplyStation:
    var s := SupplyStation.new()
    s.kind = k
    s.team = t
    s.position = pos + Vector3(0, 0.6, 0)
    var m := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = Vector3(1.6, 1.2, 1.0)
    m.mesh = b
    var colors := [Color(0.9, 0.9, 0.9), Color(0.8, 0.6, 0.1), Color(0.3, 0.75, 0.3)]
    m.material_override = Game.mat(colors[k])
    s.add_child(m)
    Game.world.add_child(s)
    if lifetime > 0.0:
        s.get_tree().create_timer(lifetime).timeout.connect(s.queue_free)
    return s


func _process(delta: float) -> void:
    var tick := Game.now() >= _next_ammo
    if tick:
        _next_ammo = Game.now() + 3.0
    var r2 := radius * radius
    for n in get_tree().get_nodes_in_group("units"):
        var u := n as Unit
        if u == null or u.is_dead() or u.team != team:
            continue
        if (u.global_position - global_position).length_squared() > r2:
            continue
        if kind != 1:
            u.heal(heal_per_sec * delta)
        if kind != 0 and tick and u.weapon != null and u.weapon.reserve < u.weapon.data.reserve_ammo:
            u.weapon.reserve += 10
