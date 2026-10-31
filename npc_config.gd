class_name NPCConfig
extends Resource

var reaction_time := 0.7
var spread_mul := 1.8
var damage_mul := 0.9
var view_range := 40.0
var fov := 110.0
var hearing_range := 20.0
var engage_range := 35.0
var move_speed := 3.4
var turn_speed := 5.0
var think_interval := 0.25
var memory_time := 4.0
var cover_chance := 0.4
var cover_duration := 4.0
var retreat_pct := 0.0
var fire_delay_mul := 1.4
var flanks := false
var suppresses := false


static func preset(d: int) -> NPCConfig:
    var c := NPCConfig.new()
    if d == 0:       # EASY
        c.reaction_time = 1.2; c.spread_mul = 3.0; c.damage_mul = 0.7; c.view_range = 30.0; c.fov = 90.0
        c.hearing_range = 12.0; c.engage_range = 25.0; c.move_speed = 2.8; c.turn_speed = 3.0
        c.think_interval = 0.35; c.memory_time = 2.0; c.cover_chance = 0.05; c.cover_duration = 3.0
        c.fire_delay_mul = 2.0
    elif d == 1:     # NORMAL (defaults)
        pass
    elif d == 2:     # HARD
        c.reaction_time = 0.35; c.spread_mul = 1.0; c.damage_mul = 1.0; c.view_range = 55.0; c.fov = 130.0
        c.hearing_range = 30.0; c.engage_range = 45.0; c.move_speed = 4.0; c.turn_speed = 8.0
        c.think_interval = 0.15; c.memory_time = 6.0; c.cover_chance = 0.7; c.cover_duration = 5.0
        c.retreat_pct = 0.15; c.fire_delay_mul = 1.0; c.flanks = true
    else:            # EXTREME
        c.reaction_time = 0.15; c.spread_mul = 0.6; c.damage_mul = 1.15; c.view_range = 70.0; c.fov = 150.0
        c.hearing_range = 40.0; c.engage_range = 55.0; c.move_speed = 4.6; c.turn_speed = 12.0
        c.think_interval = 0.1; c.memory_time = 8.0; c.cover_chance = 0.85; c.cover_duration = 6.0
        c.retreat_pct = 0.25; c.fire_delay_mul = 0.8; c.flanks = true; c.suppresses = true
    return c
