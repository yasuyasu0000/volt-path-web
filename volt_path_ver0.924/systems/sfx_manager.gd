extends Node

# Centralized one-shot SFX ownership for VOLT PATH.
# main.gd only sends stable StringName IDs; stream loading and volume live here.

var _players: Dictionary = {}
var _initialized := false

func _ready() -> void:
    setup()

func setup() -> void:
    if _initialized:
        return
    _initialized = true
    _register(&"step_charge", preload("res://sfx/step_charge.wav"), -14.0)
    _register(&"step_charged", preload("res://sfx/step_charged.wav"), -18.0)
    _register(&"player_hurt", preload("res://sfx/player_hurt.wav"), -3.0)
    _register(&"enemy_hit", preload("res://sfx/enemy_hit.wav"), -10.0)
    _register(&"enemy_destroy", preload("res://sfx/enemy_destroy.wav"), -6.0)
    _register(&"card_arc", preload("res://sfx/card_arc.wav"), -10.0)
    _register(&"card_surge", preload("res://sfx/card_surge.wav"), -9.0)
    _register(&"card_bomb", preload("res://sfx/card_bomb.wav"), -7.0)
    _register(&"card_warp", preload("res://sfx/card_warp.wav"), -10.0)
    _register(&"card_dash", preload("res://sfx/card_dash.wav"), -11.0)
    _register(&"card_loop", preload("res://sfx/card_loop.wav"), -8.0)
    _register(&"enemy_warn", preload("res://sfx/enemy_warn.wav"), -13.0)
    _register(&"enemy_melee", preload("res://sfx/enemy_melee.wav"), -9.0)
    _register(&"turret_warn", preload("res://sfx/turret_warn.wav"), -12.0)
    _register(&"turret_fire", preload("res://sfx/turret_fire.wav"), -7.0)
    _register(&"charger_warn", preload("res://sfx/charger_warn.wav"), -12.0)
    _register(&"charger_charge", preload("res://sfx/charger_charge.wav"), -7.0)
    _register(&"artillery_warn", preload("res://sfx/artillery_warn.wav"), -11.0)
    _register(&"artillery_fire", preload("res://sfx/artillery_fire.wav"), -6.0)
    _register(&"cross_warn", preload("res://sfx/cross_warn.wav"), -12.0)
    _register(&"cross_fire", preload("res://sfx/cross_fire.wav"), -7.0)
    _register(&"tank_warn", preload("res://sfx/tank_warn.wav"), -10.0)
    _register(&"tank_count", preload("res://sfx/tank_count.wav"), -9.0)
    _register(&"tank_fire", preload("res://sfx/tank_fire.wav"), -5.0)
    _register(&"ui_reroll", preload("res://sfx/ui_reroll.wav"), -12.0)
    _register(&"ui_bat_denied", preload("res://sfx/ui_bat_denied.wav"), -10.0)
    _register(&"ui_menu_move", preload("res://sfx/ui_menu_move.wav"), -13.0)
    _register(&"ui_menu_decide", preload("res://sfx/ui_menu_decide.wav"), -10.0)
    _register(&"stage_clear", preload("res://sfx/stage_clear.wav"), -7.0)
    _register(&"game_clear", preload("res://sfx/game_clear.wav"), -4.0)
    _register(&"game_over_hp", preload("res://sfx/game_over_hp.wav"), -4.0)
    _register(&"game_over_charge", preload("res://sfx/game_over_charge.wav"), -4.0)
    _register(&"boss_stomp", preload("res://sfx/boss_stomp.wav"), -4.5)
    _register(&"boss_leg_break", preload("res://sfx/boss_leg_break.wav"), -3.5)

func _register(id: StringName, stream: AudioStream, volume_db: float) -> void:
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = volume_db
    add_child(player)
    _players[id] = player

func play_sfx(id: StringName) -> void:
    var value: Variant = _players.get(id)
    if value == null:
        return
    var player: AudioStreamPlayer = value as AudioStreamPlayer
    if player == null:
        return
    player.stop()
    player.play()
