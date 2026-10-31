class_name SoldierFactory
extends RefCounted


# Returns null if the AI cap for the current quality preset is reached or no navmesh is near.
static func spawn(pos: Vector3, team: int, diff: int, leader: Node3D) -> Soldier:
    if Game.world == null:
        return null
    if Game.get_tree().get_nodes_in_group("soldiers").size() >= Game.max_ai():
        return null
    var map := Game.world.get_world_3d().navigation_map
    var p := NavigationServer3D.map_get_closest_point(map, pos)
    if Vector2(p.x - pos.x, p.z - pos.z).length() > 10.0:
        return null
    var s := Soldier.new()
    s.init_stats(team, 100.0, 25.0)
    s.setup(diff, leader)
    s.position = p
    Game.world.add_child(s)
    return s
