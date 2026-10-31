extends Node3D
# Builds a whole playable scene at runtime (seeded, so battlefields are reproducible):
# ground, boundary, houses, sandbags, hills, navmesh, player, allies, enemies, HUD, touch controls.

@export var mode := 0   # 0 = Battlefield, 1 = Training

var region: NavigationRegion3D
var actors: Node3D
var rng := RandomNumberGenerator.new()
var size := 120.0
var placed: Array[Vector3] = []
var player_spawn := Vector3.ZERO
var sun: DirectionalLight3D
var env: Environment

const GROUND_C := Color(0.32, 0.4, 0.25)
const WOOD_C := Color(0.45, 0.3, 0.18)
const CONCRETE_C := Color(0.55, 0.55, 0.52)
const ROCK_C := Color(0.35, 0.34, 0.32)
const SAND_C := Color(0.7, 0.62, 0.4)


func _ready() -> void:
    Game.reset_round()
    Game.battle_mode = mode == 0
    size = 120.0 if mode == 0 else 60.0
    rng.seed = Game.map_seed if mode == 0 else 1

    _make_environment()
    region = NavigationRegion3D.new()
    add_child(region)
    actors = Node3D.new()
    actors.name = "Actors"
    add_child(actors)
    Game.world = actors

    _build_ground()
    if mode == 0:
        _build_battlefield()
    else:
        _build_training_geometry()

    var nm := NavigationMesh.new()
    nm.agent_radius = 0.5
    nm.agent_height = 2.0
    region.navigation_mesh = nm
    region.bake_navigation_mesh(true)
    await region.bake_finished
    await get_tree().physics_frame
    await get_tree().physics_frame

    var player := _spawn_player()
    var ui := CanvasLayer.new()
    add_child(ui)
    ui.add_child(TouchUI.new())
    var hud := HUD.new()
    hud.player = player
    ui.add_child(hud)

    if mode == 0:
        var cap := Game.max_ai()
        var allies := mini(Game.ally_count, cap / 3)
        var enemies := clampi(Game.enemy_count, 1, cap - allies)
        var half := size / 2.0
        for i in enemies:
            SoldierFactory.spawn(Vector3(rng.randf_range(-30, 30), 0, half - rng.randf_range(8, 20)), 1, Game.difficulty, null)
        for i in allies:
            SoldierFactory.spawn(player_spawn + Vector3(-3 + i * 2, 0, 3), 0, Game.Diff.NORMAL, player)
        SupplyStation.create(player_spawn + Vector3(8, 0, 2), 2, 0, 0.0)
    else:
        _build_targets()
        var station := Vector3(-10, 0, -14)
        SupplyStation.create(station, 2, 0, 0.0)
        for i in 2:
            SoldierFactory.spawn(player_spawn + Vector3(-2 + i * 4, 0, 3), 0, Game.Diff.NORMAL, player)
        var tut := Tutorial.new()
        tut.player = player
        tut.station_pos = station
        ui.add_child(tut)


# ---------- world ----------
func _make_environment() -> void:
    env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.55, 0.72, 0.9)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.55, 0.55)
    env.ambient_light_energy = 1.0
    env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.shadow_enabled = Game.get_quality() > 0
    add_child(sun)


func _box(parent: Node, n: String, pos: Vector3, sz: Vector3, c: Color, hp: float) -> StaticBody3D:
    var body: StaticBody3D
    if hp > 0.0:
        var d := Destructible.new()
        d.setup(hp, c)
        body = d
    else:
        body = StaticBody3D.new()
    body.name = n
    body.position = pos
    var m := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = sz
    m.mesh = bm
    m.material_override = Game.mat(c)
    body.add_child(m)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = sz
    cs.shape = sh
    body.add_child(cs)
    if hp > 0.0:
        (body as Destructible).mesh = m
    parent.add_child(body)
    return body


func _build_ground() -> void:
    _box(region, "Ground", Vector3(0, -0.5, 0), Vector3(size, 1, size), GROUND_C, 0.0)
    var h := size / 2.0 + 1.0   # indestructible boundary walls
    _box(region, "BoundaryN", Vector3(0, 4, h), Vector3(size + 4, 8, 2), CONCRETE_C, 0.0)
    _box(region, "BoundaryS", Vector3(0, 4, -h), Vector3(size + 4, 8, 2), CONCRETE_C, 0.0)
    _box(region, "BoundaryE", Vector3(h, 4, 0), Vector3(2, 8, size + 4), CONCRETE_C, 0.0)
    _box(region, "BoundaryW", Vector3(-h, 4, 0), Vector3(2, 8, size + 4), CONCRETE_C, 0.0)


func _too_close(p: Vector3, d: float) -> bool:
    for q in placed:
        if p.distance_to(q) < d:
            return true
    return false


func _house(pos: Vector3, w: float, d: float, h: float, rot_y: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation_degrees.y = rot_y
    region.add_child(root)
    var t := 0.4
    var door := 2.4
    var hp := 160.0
    var seg := (w - door) / 2.0
    _box(root, "WallBack", Vector3(0, h / 2, d / 2), Vector3(w, h, t), WOOD_C, hp)
    _box(root, "WallL", Vector3(-w / 2, h / 2, 0), Vector3(t, h, d), WOOD_C, hp)
    _box(root, "WallR", Vector3(w / 2, h / 2, 0), Vector3(t, h, d), WOOD_C, hp)
    _box(root, "WallFrontL", Vector3(-(door / 2 + seg / 2), h / 2, -d / 2), Vector3(seg, h, t), WOOD_C, hp)
    _box(root, "WallFrontR", Vector3(door / 2 + seg / 2, h / 2, -d / 2), Vector3(seg, h, t), WOOD_C, hp)
    _box(root, "Lintel", Vector3(0, h - 0.5, -d / 2), Vector3(door, 1.0, t), WOOD_C, hp)
    _box(root, "Roof", Vector3(0, h + 0.15, 0), Vector3(w + 0.6, 0.3, d + 0.6), WOOD_C, hp * 1.5)


func _sandbags(pos: Vector3, rot_y: float) -> void:
    var b := _box(region, "Sandbags", Vector3(pos.x, 0.4, pos.z), Vector3(3.2, 0.8, 0.9), SAND_C, 60.0)
    b.rotation_degrees.y = rot_y


func _build_battlefield() -> void:
    var half := size / 2.0
    player_spawn = Vector3(0, 0.1, -half + 10)
    placed.append(player_spawn)
    placed.append(Vector3(0, 0, half - 10))

    var houses := 0
    var tries := 0
    while houses < 10 and tries < 300:
        tries += 1
        var p := Vector3(rng.randf_range(-half + 15, half - 15), 0, rng.randf_range(-half + 25, half - 25))
        if _too_close(p, 20.0):
            continue
        placed.append(p)
        _house(p, rng.randf_range(7, 12), rng.randf_range(7, 11), rng.randf_range(3.2, 4.5), rng.randi_range(0, 3) * 90.0)
        houses += 1

    var hills := 0
    tries = 0
    while hills < 5 and tries < 200:   # indestructible "mountain" blocks
        tries += 1
        var p := Vector3(rng.randf_range(-half + 10, half - 10), 0, rng.randf_range(-half + 28, half - 28))
        if _too_close(p, 16.0):
            continue
        placed.append(p)
        var hh := rng.randf_range(4, 9)
        var g := _box(region, "Hill", Vector3(p.x, hh / 2, p.z), Vector3(rng.randf_range(8, 16), hh, rng.randf_range(8, 16)), ROCK_C, 0.0)
        g.rotation_degrees.y = rng.randf_range(0, 90)
        hills += 1

    var bags := 0
    tries = 0
    while bags < 16 and tries < 300:
        tries += 1
        var p := Vector3(rng.randf_range(-half + 6, half - 6), 0, rng.randf_range(-half + 18, half - 18))
        if _too_close(p, 7.0):
            continue
        placed.append(p)
        _sandbags(p, rng.randf_range(0, 180))
        bags += 1


func _build_training_geometry() -> void:
    player_spawn = Vector3(0, 0.1, -20)
    _house(Vector3(18, 0, -5), 9, 8, 3.5, 270)
    _sandbags(Vector3(-6, 0, -8), 0)
    _sandbags(Vector3(6, 0, -8), 0)
    _sandbags(Vector3(0, 0, 2), 10)


func _build_targets() -> void:
    for i in 6:
        var t := PracticeTarget.new()
        t.position = Vector3(-12 + i * 4.8, 0.9, 10 + (i % 3) * 7)
        var m := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.0, 1.8, 0.2)
        m.mesh = bm
        m.material_override = Game.mat(Color(0.9, 0.35, 0.1))
        t.add_child(m)
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = Vector3(1.0, 1.8, 0.2)
        cs.shape = sh
        t.add_child(cs)
        actors.add_child(t)


# ---------- player ----------
func _spawn_player() -> Player:
    var p := Player.new()
    p.name = "Player"
    p.init_stats(0, 100.0, 50.0)
    p.position = player_spawn
    add_child(p)
    p.add_child(SquadCommander.new())
    p.add_child(ReinforcementCaller.new())
    var nm := NightMode.new()
    p.add_child(nm)
    nm.setup(env, sun)
    return p
