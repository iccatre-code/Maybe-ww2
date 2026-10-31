class_name Soldier
extends Unit
# AI soldier used for enemies AND friendly squad members.

enum State { IDLE, PATROL, CHASE, ATTACK, COVER, FLANK, RETREAT, DEAD }

var state := State.IDLE
var difficulty := 1
var cfg: NPCConfig
var order := 0            # Game.Order
var leader: Node3D = null
var order_point := Vector3.ZERO

var agent: NavigationAgent3D
var col: CollisionShape3D
var home := Vector3.ZERO
var last_known := Vector3.ZERO
var target: Unit = null
var has_target := false
var visible_now := false
var moving := false
var next_think := 0.0
var next_wander := 0.0
var cover_until := 0.0
var react_at := 0.0
var last_seen := 0.0
var next_shot := 0.0


func setup(d: int, leader_node: Node3D) -> void:
    difficulty = d
    cfg = NPCConfig.preset(d)
    leader = leader_node
    if leader_node != null:
        order = Game.Order.FOLLOW


func _mesh(m: Mesh, c: Color, pos: Vector3) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = m
    mi.material_override = Game.mat(c)
    mi.position = pos
    add_child(mi)


func _ready() -> void:
    if cfg == null:
        cfg = NPCConfig.preset(difficulty)
    add_to_group("units")
    add_to_group("soldiers")

    var cs := CapsuleShape3D.new()
    cs.radius = 0.35
    cs.height = 1.8
    col = CollisionShape3D.new()
    col.shape = cs
    col.position = Vector3(0, 0.9, 0)
    add_child(col)

    var team_color := Color(0.2, 0.35, 0.9) if team == 0 else Color(0.85, 0.2, 0.2)
    var body := CapsuleMesh.new()
    body.radius = 0.3
    body.height = 1.6
    _mesh(body, team_color, Vector3(0, 0.85, 0))
    var helmet := BoxMesh.new()
    helmet.size = Vector3(0.45, 0.25, 0.45)
    _mesh(helmet, Color(0.1, 0.12, 0.1), Vector3(0, 1.78, 0))
    var gun := BoxMesh.new()
    gun.size = Vector3(0.08, 0.1, 0.7)
    _mesh(gun, Color.BLACK, Vector3(0.25, 1.1, -0.35))

    agent = NavigationAgent3D.new()
    agent.path_desired_distance = 0.8
    agent.target_desired_distance = 1.0
    add_child(agent)

    var w := Weapon.new()
    add_child(w)
    w.equip(load("res://data/rifle.tres") as WeaponData)
    weapon = w

    home = position
    died.connect(_on_died)
    damaged.connect(_on_damaged)
    next_think = Game.now() + randf() * cfg.think_interval


func _eye() -> Vector3:
    return global_position + Vector3.UP * 1.6


func _on_died(_u, _k) -> void:
    state = State.DEAD
    remove_from_group("units")
    remove_from_group("soldiers")
    col.set_deferred("disabled", true)
    rotation.x = deg_to_rad(-90.0)
    position.y += 0.3
    get_tree().create_timer(12.0).timeout.connect(queue_free)


func _on_damaged(_amount, src) -> void:
    var u := src as Unit
    if u != null and u.team != team and not u.is_dead():
        if not has_target:
            react_at = Game.now() + cfg.reaction_time * 0.5
        target = u
        has_target = true
        last_known = u.global_position
        last_seen = Game.now()


func _physics_process(delta: float) -> void:
    if state == State.DEAD or is_dead():
        return
    var t := Game.now()
    if t >= next_think:
        next_think = t + cfg.think_interval
        _think(t)

    var target_ok := has_target and is_instance_valid(target) and not target.is_dead()
    if target_ok and visible_now:
        _face(target.global_position, delta)
        if t >= react_at:
            _shoot(target.global_position + Vector3.UP * 1.2, 1.0, t)
    elif target_ok and cfg.suppresses and t - last_seen < 2.5:
        _face(last_known, delta)
        _shoot(last_known + Vector3.UP * 1.2, 2.5, t)

    var vel := Vector3.ZERO
    if moving and not agent.is_navigation_finished():
        var nxt := agent.get_next_path_position()
        var d := nxt - global_position
        d.y = 0.0
        if d.length() > 0.05:
            vel = d.normalized() * cfg.move_speed
            if not (target_ok and visible_now):
                _face(global_position + vel, delta)
    velocity.x = vel.x
    velocity.z = vel.z
    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = 0.0
    move_and_slide()


func _face(p: Vector3, delta: float) -> void:
    var f := p - global_position
    f.y = 0.0
    if f.length_squared() < 0.01:
        return
    var ang := atan2(-f.x, -f.z)
    rotation.y = lerp_angle(rotation.y, ang, clampf(cfg.turn_speed * delta, 0.0, 1.0))


func _shoot(aim: Vector3, spread_boost: float, t: float) -> void:
    if t < next_shot:
        return
    var dir := (aim - _eye()).normalized()
    if weapon.try_fire(_eye(), dir, cfg.spread_mul * spread_boost, cfg.damage_mul, self):
        next_shot = t + (60.0 / weapon.data.fire_rate) * cfg.fire_delay_mul * randf_range(1.0, 1.6)


# ---------- decision tick ----------
func _think(t: float) -> void:
    _acquire(t)
    var engaged := has_target and is_instance_valid(target) and not target.is_dead()
    var low := health < max_health * cfg.retreat_pct

    if order == Game.Order.REGROUP and leader != null and _flat(leader.global_position) > 3.0:
        state = State.CHASE
        _go(leader.global_position)
        return
    if order == Game.Order.FOLLOW and leader != null and _flat(leader.global_position) > 25.0:
        state = State.CHASE
        _go(leader.global_position)
        return
    if engaged and low:
        state = State.RETREAT
        _go(leader.global_position if leader != null else home)
        return

    if engaged:
        var d := _flat(target.global_position)
        if order == Game.Order.HOLD:
            _halt()
            state = State.ATTACK
            return
        if order == Game.Order.DEFEND and global_position.distance_to(order_point) > 12.0 and not visible_now:
            state = State.CHASE
            _go(order_point)
            return
        if not visible_now:
            state = State.CHASE
            _go(last_known)
            return
        if d > cfg.engage_range:
            state = State.CHASE
            _go(target.global_position)
            return
        if (state == State.COVER or state == State.FLANK) and _is_moving():
            return
        if t > cover_until and randf() < cfg.cover_chance:
            var c := _find_cover()
            if c != Vector3.INF:
                state = State.COVER
                _go(c)
                cover_until = t + cfg.cover_duration
                return
        if cfg.flanks and d > 14.0 and randf() < 0.25:
            var away := global_position - target.global_position
            away.y = 0.0
            var side := away.normalized().rotated(Vector3.UP, deg_to_rad(80.0 if randf() < 0.5 else -80.0))
            state = State.FLANK
            _go(target.global_position + side * 12.0)
            return
        _halt()
        state = State.ATTACK
        return

    # no target: follow orders or patrol
    if order == Game.Order.FOLLOW and leader != null:
        if _flat(leader.global_position) > 4.0:
            state = State.CHASE
            _go(leader.global_position)
        else:
            _halt()
            state = State.IDLE
    elif order == Game.Order.DEFEND or order == Game.Order.ATTACK:
        if global_position.distance_to(order_point) > 3.0:
            state = State.CHASE
            _go(order_point)
        else:
            _halt()
            state = State.IDLE
    elif order == Game.Order.HOLD or order == Game.Order.REGROUP:
        _halt()
        state = State.IDLE
    elif t >= next_wander:
        next_wander = t + randf_range(4.0, 9.0)
        state = State.PATROL
        _go(home + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)))


func _acquire(t: float) -> void:
    visible_now = false
    var best: Unit = null
    var bd := INF
    var best_seen := false
    for n in get_tree().get_nodes_in_group("units"):
        var u := n as Unit
        if u == null or u == self or u.team == team or u.is_dead():
            continue
        var d := global_position.distance_to(u.global_position)
        var seen := _can_see(u, d)
        var heard: bool = d < cfg.hearing_range and t - u.last_noise < 1.5
        if not seen and not heard:
            continue
        if d < bd:
            bd = d
            best = u
            best_seen = seen
    if best != null:
        if not has_target:
            react_at = t + cfg.reaction_time
        target = best
        has_target = true
        last_known = best.global_position
        last_seen = t
        visible_now = best_seen
    elif has_target and (not is_instance_valid(target) or target.is_dead() or t - last_seen > cfg.memory_time):
        has_target = false
        target = null


func _can_see(u: Unit, d: float) -> bool:
    var rng := cfg.view_range
    if Game.night and not u.lit:
        rng *= 0.45   # darkness hides targets that are not using a light
    if d > rng:
        return false
    var from := _eye()
    var to := u.global_position + Vector3.UP * 1.2
    var dirv := to - from
    if d > 6.0:
        var fwd := -global_transform.basis.z
        var flat := Vector3(dirv.x, 0.0, dirv.z)
        if rad_to_deg(fwd.angle_to(flat)) > cfg.fov * 0.5:
            return false
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(q)
    return hit.is_empty() or hit.collider == u


func _find_cover() -> Vector3:
    var best := INF
    var result := Vector3.INF
    var tp := target.global_position + Vector3.UP * 1.2
    var map := get_world_3d().navigation_map
    var space := get_world_3d().direct_space_state
    for i in 10:
        var c := global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
        var p := NavigationServer3D.map_get_closest_point(map, c)
        if Vector2(p.x - c.x, p.z - c.z).length() > 2.0:
            continue
        var from := p + Vector3.UP
        var q := PhysicsRayQueryParameters3D.create(from, tp)
        q.exclude = [get_rid(), target.get_rid()]
        if not space.intersect_ray(q).is_empty():
            var dd := global_position.distance_to(p)
            if dd < best:
                best = dd
                result = p
    return result


func _is_moving() -> bool:
    return moving and not agent.is_navigation_finished()


func _flat(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _halt() -> void:
    moving = false


func _go(p: Vector3) -> void:
    var map := get_world_3d().navigation_map
    agent.target_position = NavigationServer3D.map_get_closest_point(map, p)
    moving = true
