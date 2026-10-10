extends Node2D

const CardCatalog = preload("res://systems/card_catalog.gd")
const GameBalance = preload("res://systems/game_balance.gd")
const SfxManager = preload("res://systems/sfx_manager.gd")
const SpiderBoss = preload("res://systems/spider_boss.gd")
const SkillFx = preload("res://systems/skill_fx.gd")
const EnemySystem = preload("res://systems/enemy_system.gd")
const HudRenderer = preload("res://systems/hud_renderer.gd")
const BoardRenderer = preload("res://systems/board_renderer.gd")
const TerrainSystem = preload("res://systems/terrain_system.gd")
const EnemyGeometry = preload("res://systems/enemy_geometry.gd")
const WebAnalytics = preload("res://systems/web_analytics.gd")
const UiFont = preload("res://systems/ui_font.gd")

# VOLT PATH ver0.949
# HUD prototype:
# - 左: 手札3枚 + 0キーリロール
# - 中: ステージ
# - 右: 現在ステータス
# - 使用したカードは1枚だけ補充する
# - 0キーでBAT 2を消費し、手札3枚をすべてリロールする

const GRID_W := 17
const GRID_H := 11
const CELL := 38
const GRID_ORIGIN := Vector2(337, 52)
const WINDOW_SIZE := Vector2(1280, 720)
const MAX_BAT := 10
const MAX_HP := 6
const REROLL_COST := GameBalance.REROLL_COST
const TOTAL_FLOORS := 10
const AUTO_PASS_DELAY := 1.0
const FULL_CHARGE_MOVE_DAMAGE := GameBalance.FULL_CHARGE_MOVE_DAMAGE
const FULL_CHARGE_ENEMY_DAMAGE := GameBalance.FULL_CHARGE_ENEMY_DAMAGE
const FULL_CHARGE_FLASH_INTERVAL := 0.16

const DAMAGE_FEEDBACK_DURATION := 0.22
const DAMAGE_SHAKE_PIXELS := 5.0
const DAMAGE_FRAME_THICKNESS := 12.0
const DAMAGE_HUD_FLASH_ALPHA := 0.42

const SFX_STEP_CHARGE := &"step_charge"
const SFX_STEP_CHARGED := &"step_charged"
const SFX_PLAYER_HURT := &"player_hurt"
const SFX_ENEMY_HIT := &"enemy_hit"
const SFX_ENEMY_DESTROY := &"enemy_destroy"
const SFX_CARD_ARC := &"card_arc"
const SFX_CARD_SURGE := &"card_surge"
const SFX_CARD_BOMB := &"card_bomb"
const SFX_CARD_WARP := &"card_warp"
const SFX_CARD_DASH := &"card_dash"
const SFX_CARD_LOOP := &"card_loop"
const SFX_ENEMY_WARN := &"enemy_warn"
const SFX_ENEMY_MELEE := &"enemy_melee"
const SFX_TURRET_WARN := &"turret_warn"
const SFX_TURRET_FIRE := &"turret_fire"
const SFX_CHARGER_WARN := &"charger_warn"
const SFX_CHARGER_CHARGE := &"charger_charge"
const SFX_ARTILLERY_WARN := &"artillery_warn"
const SFX_ARTILLERY_FIRE := &"artillery_fire"
const SFX_CROSS_WARN := &"cross_warn"
const SFX_CROSS_FIRE := &"cross_fire"
const SFX_TANK_WARN := &"tank_warn"
const SFX_TANK_COUNT := &"tank_count"
const SFX_TANK_FIRE := &"tank_fire"
const SFX_UI_REROLL := &"ui_reroll"
const SFX_UI_BAT_DENIED := &"ui_bat_denied"
const SFX_UI_MENU_MOVE := &"ui_menu_move"
const SFX_UI_MENU_DECIDE := &"ui_menu_decide"
const SFX_STAGE_CLEAR := &"stage_clear"
const SFX_GAME_CLEAR := &"game_clear"
const SFX_GAME_OVER_HP := &"game_over_hp"
const SFX_GAME_OVER_CHARGE := &"game_over_charge"
const SFX_BOSS_STOMP := &"boss_stomp"
const SFX_BOSS_LEG_BREAK := &"boss_leg_break"

const CARD_ARC := CardCatalog.ARC
const CARD_SURGE := CardCatalog.SURGE
const CARD_BOMB := CardCatalog.BOMB
const CARD_WARP := CardCatalog.WARP
const CARD_DASH := CardCatalog.DASH
const CARD_LOOP := CardCatalog.LOOP

const C_BG := Color("#091018")
const C_PANEL := Color("#101a24")
const C_PANEL_INNER := Color("#15222e")
const C_PANEL_DISABLED := Color("#0d141c")
const C_PANEL_ACTIVE := Color("#1d3442")
const C_FLOOR := Color("#1a2632")
const C_FLOOR_EDGE := Color("#2f4050")
const C_CHARGED := Color("#174f5b")
const C_CHARGED_INNER := Color("#35d6e4")
const C_WALL := Color("#0b0f14")
const C_WALL_EDGE := Color("#59636d")
const C_PLAYER := Color("#4f8cff")
const PLAYER_PULSE_INTERVAL := 1.8
const HP_ICON_PULSE_INTERVAL := 1.8
# Slow idle pulses/telegraph flashes do not need a full 60 redraws per second.
# Active skill/hit FX still request up to 60 FPS for smooth short animations.
const IDLE_REDRAW_FPS := 20.0
const ACTIVE_REDRAW_FPS := 60.0
const C_ENEMY := Color("#ef6262")
const C_TEXT := Color("#e7eef5")
const C_DIM := Color("#8fa0ae")
const C_BAT := Color("#3f8cff")
const C_HP := Color("#ff6675")
const C_RESOURCE_EMPTY := Color("#23303d")
const C_ATTACK := Color(1.0, 0.25, 0.18, 0.34)
const C_TELEGRAPH := Color(1.0, 0.56, 0.12, 0.32)
const C_TELEGRAPH_EDGE := Color("#ff9a38")
const C_AIM := Color(1.0, 0.91, 0.34, 0.46)
const C_ARC := Color(0.55, 0.92, 1.0, 0.55)
const C_WARNING := Color("#ffb347")
const C_FULL_CHARGE_RED := Color(1.0, 0.12, 0.18, 0.82)
const C_FULL_CHARGE_BLUE := Color(0.12, 0.42, 1.0, 0.82)
const C_FULL_CHARGE_EDGE_RED := Color("#ff6973")
const C_FULL_CHARGE_EDGE_BLUE := Color("#75a8ff")
const C_TURRET := Color("#687786")
const C_TURRET_LENS := Color("#ff3f46")
const C_TURRET_BEAM_EDGE := Color("#ff4650")
const C_CHARGER := Color("#d08a36")
const C_CHARGER_CORE := Color("#ffe06a")
const C_CHARGER_EDGE := Color("#ffc247")
const C_RUNNER := Color("#58c978")
const C_RUNNER_CORE := Color("#d8ff91")
const C_RUNNER_EDGE := Color("#8af0a0")
const C_SERPENT := Color("#8666d8")
const C_SERPENT_CORE := Color("#e0d4ff")
const C_SERPENT_EDGE := Color("#bca8ff")
const C_HEAVY := Color("#59636d")
const C_HEAVY_CORE := Color("#ffb454")
const C_HEAVY_EDGE := Color("#aab5c0")
const C_ARTILLERY := Color("#4f6172")
const C_ARTILLERY_CORE := Color("#ff725c")
const C_ARTILLERY_EDGE := Color("#c7d4df")
const C_ARTILLERY_BEAM_EDGE := Color("#ff684c")
const C_LONG_SERPENT := Color("#5f4aa8")
const C_LONG_SERPENT_CORE := Color("#f0d8ff")
const C_LONG_SERPENT_EDGE := Color("#d18cff")
const C_CROSS := Color("#345f72")
const C_CROSS_CORE := Color("#73e6ff")
const C_CROSS_EDGE := Color("#a3f1ff")
const C_CROSS_BEAM_EDGE := Color("#58dcff")
const C_TANK := Color("#3e4b58")
const C_TANK_CORE := Color("#ff5e42")
const C_TANK_EDGE := Color("#9aa8b5")
const C_TANK_BEAM_EDGE := Color("#ff6048")
const C_BOSS_LEG := Color("#4a4458")
const C_BOSS_LEG_CORE := Color("#ff7b57")
const C_BOSS_LEG_EDGE := Color("#d7c9ef")
const C_BOSS_LEG_BROKEN := Color("#24232b")
const C_BOSS_LEG_BROKEN_EDGE := Color("#68636f")
const C_BOSS_BODY := Color("#24202d")
const C_HUD_VALUE := Color("#f7fbff")
const C_HUD_VALUE_BG := Color("#0a1118")

const TELEGRAPH_FLASH_INTERVAL := 0.14
const C_TELEGRAPH_FLASH_RED := Color("#ff3b30")
const C_TELEGRAPH_FLASH_WHITE := Color(1.0, 1.0, 1.0, 0.98)
const REROLL_ANIM_DURATION := 0.38
const REROLL_SHRINK_END := 0.11
const REROLL_NOISE_END := 0.17
const REROLL_CARD_STAGGER := 0.045
const REROLL_POP_DURATION := 0.12
const CARD_REPLACE_ANIM_DURATION := 0.30
const CARD_REPLACE_SHRINK_END := 0.10
const CARD_REPLACE_NOISE_END := 0.15
const CARD_REPLACE_POP_DURATION := 0.12
const BOSS_LEG_LIFT_PIXELS := 7.0
const ENEMY_HIT_REACTION_DURATION := 0.18
const ENEMY_HIT_SHAKE_PIXELS := 3.0
const ENEMY_DAMAGE_NUMBER_DURATION := 0.48
const ENEMY_DESTROY_FX_DURATION := 0.34
const ENEMY_IMPACT_SHAKE_DURATION := 0.16
const ENEMY_IMPACT_FREEZE_DURATION := 0.06

var rng := RandomNumberGenerator.new()
var walls: Dictionary = {}
var charged: Dictionary = {}
var player_pos := Vector2i.ZERO
var player_facing := Vector2i.DOWN
var enemies: Array[Dictionary] = []
var hand: Array[String] = []

var bat := 0
var hp := MAX_HP
var turn := 0
var game_over := false
var game_over_reason := ""
var full_charge_hazard_active := false
var current_floor := 1
var stage_clear := false
var stage_clear_timer := 0.0
var run_clear := false
var run_elapsed_seconds: float = 0.0
var step_count := 0
var damage_taken := 0

# Public-test analytics: difficulty-focused telemetry only.
# Keep floor progression, damage pressure and retry behavior; avoid resource/skill noise.
var floor_start_run_time_seconds := 0.0
var floor_start_turn := 0
var floor_start_damage_taken := 0
var floor_hits_taken := 0
var last_player_damage_source := ""
var last_player_damage_enemy_type := ""

var damage_fx_time_left := 0.0
var damage_fx_intensity := 0.0
var damage_fx_sequence := 0
var auto_pass_pending := false
var auto_pass_timer := 0.0
var reroll_anim_active := false
var reroll_anim_time := 0.0
var reroll_new_committed := false
var reroll_old_hand: Array[String] = []
var reroll_new_hand: Array[String] = []
var card_replace_anim_active := false
var card_replace_anim_time := 0.0
var card_replace_slot := -1
var card_replace_old_card := ""
var card_replace_new_card := ""
var card_replace_committed := false
var skill_turn_pending := false
var skill_fx_finished := false
var spider_boss = null
var skill_fx = null
var sfx_manager = null
var enemy_system = null
var hud_renderer = null
var board_renderer = null
var terrain_system = null
var enemy_geometry = null
var web_analytics = null
var ui_font: Font = null


var aim_mode := ""
var aim_dir := Vector2i.RIGHT
var bomb_cursor := Vector2i.ZERO
var warp_cursor := Vector2i.ZERO
var dash_path_preview: Array[Vector2i] = []
var dash_branch_options: Array[Vector2i] = []
var dash_branch_origin := Vector2i.ZERO
var dash_route_customized := false
var loop_candidates: Array[Dictionary] = []
var loop_candidate_index := 0
var active_hand_slot := -1
var last_attack_cells: Array[Vector2i] = []
var enemy_hit_flashes: Array[Dictionary] = []
var enemy_damage_numbers: Array[Dictionary] = []
var enemy_destroy_fx: Array[Dictionary] = []
var enemy_impact_shake_time := 0.0
var enemy_impact_shake_strength := 0.0
var enemy_impact_shake_sequence := 0
var enemy_impact_freeze_time := 0.0
var message := ""
var restart_confirm_active := false
var restart_confirm_yes := false
var stage_restart_snapshot: Dictionary = {}
var _redraw_accumulator := 0.0
var title_screen_active := true
var title_menu_index := 0
var title_exit_pending := false

func _ready() -> void:
    ui_font = UiFont.build()
    rng.randomize()
    sfx_manager = SfxManager.new()
    add_child(sfx_manager)
    sfx_manager.setup()
    spider_boss = SpiderBoss.new()
    skill_fx = SkillFx.new()
    enemy_system = EnemySystem.new()
    hud_renderer = HudRenderer.new()
    hud_renderer.setup(self)
    board_renderer = BoardRenderer.new()
    board_renderer.setup(self)
    terrain_system = TerrainSystem.new()
    terrain_system.setup(self)
    enemy_geometry = EnemyGeometry.new()
    enemy_geometry.setup(self)
    web_analytics = WebAnalytics.new()
    web_analytics.setup()
    title_screen_active = true
    title_menu_index = 0
    title_exit_pending = false
    queue_redraw()

func _return_to_title() -> void:
    title_screen_active = true
    title_menu_index = 0
    title_exit_pending = false
    restart_confirm_active = false
    restart_confirm_yes = false
    queue_redraw()

func _play_sfx(id: StringName) -> void:
    if sfx_manager == null:
        return
    sfx_manager.play_sfx(id)

func reset_run() -> void:
    walls.clear()
    charged.clear()
    enemies.clear()
    hand.clear()
    bat = 0
    hp = MAX_HP
    turn = 0
    game_over = false
    game_over_reason = ""
    full_charge_hazard_active = false
    current_floor = 1
    stage_clear = false
    stage_clear_timer = 0.0
    run_clear = false
    run_elapsed_seconds = 0.0
    step_count = 0
    damage_taken = 0
    floor_start_run_time_seconds = 0.0
    floor_start_turn = 0
    floor_start_damage_taken = 0
    floor_hits_taken = 0
    last_player_damage_source = ""
    last_player_damage_enemy_type = ""
    if spider_boss != null:
        spider_boss.reset()
    damage_fx_time_left = 0.0
    damage_fx_intensity = 0.0
    damage_fx_sequence = 0
    auto_pass_pending = false
    auto_pass_timer = 0.0
    reroll_anim_active = false
    reroll_anim_time = 0.0
    reroll_new_committed = false
    reroll_old_hand.clear()
    reroll_new_hand.clear()
    card_replace_anim_active = false
    card_replace_anim_time = 0.0
    card_replace_slot = -1
    card_replace_old_card = ""
    card_replace_new_card = ""
    card_replace_committed = false
    skill_turn_pending = false
    skill_fx_finished = false
    if skill_fx != null:
        skill_fx.reset()
    aim_mode = ""
    active_hand_slot = -1
    last_attack_cells.clear()
    enemy_hit_flashes.clear()
    enemy_damage_numbers.clear()
    enemy_destroy_fx.clear()
    enemy_impact_shake_time = 0.0
    enemy_impact_shake_strength = 0.0
    enemy_impact_shake_sequence = 0
    enemy_impact_freeze_time = 0.0
    message = ""
    restart_confirm_active = false
    restart_confirm_yes = false
    stage_restart_snapshot.clear()
    _redraw_accumulator = 0.0

    player_pos = Vector2i(GRID_W >> 1, GRID_H >> 1)
    player_facing = Vector2i.DOWN
    _generate_stage_board(5)
    _draw_new_hand()
    bomb_cursor = player_pos
    warp_cursor = player_pos
    dash_path_preview.clear()
    dash_branch_options.clear()
    dash_branch_origin = player_pos
    dash_route_customized = false
    _reset_floor_analytics_baseline()
    _capture_stage_restart_snapshot()
    _schedule_auto_pass_if_needed()

func _process(delta: float) -> void:
    # タイトル画面ではランをまだ生成せず、タイマー・敵・演出を完全に停止する。
    if title_screen_active:
        _redraw_accumulator += delta
        if _redraw_accumulator >= 1.0 / IDLE_REDRAW_FPS:
            _redraw_accumulator = 0.0
            queue_redraw()
        return

    # リスタート確認中はゲーム内時間・演出・敵進行を完全に停止する。
    if restart_confirm_active:
        _redraw_accumulator = 0.0
        return

    # 0 = no continuous visual update, 1 = slow idle animation, 2 = short active FX.
    # queue_redraw() is centralized here so CanvasItem can reuse cached draw commands.
    var redraw_priority := 0

    # クリア時間はプレイヤーが入力できる時間だけを計測する。
    # スキル/カード交換/リロール演出、自動待機、STAGE CLEARなど、
    # プレイヤー側で短縮できない待ち時間は記録へ含めない。
    if _run_timer_should_advance():
        run_elapsed_seconds += delta

    if damage_fx_time_left > 0.0:
        damage_fx_time_left = maxf(0.0, damage_fx_time_left - delta)
        if damage_fx_time_left <= 0.0:
            damage_fx_intensity = 0.0
        redraw_priority = 2

    # 6DMG以上の強打だけ、演出時計をほんの一瞬止めて衝撃を作る。
    # ゲームの論理状態はすでに確定済みなので、入力待ちやターン処理は増やさない。
    var enemy_hitstop_active := enemy_impact_freeze_time > 0.0
    if enemy_hitstop_active:
        enemy_impact_freeze_time = maxf(0.0, enemy_impact_freeze_time - delta)
        redraw_priority = 2
    else:
        if _process_enemy_hit_reactions(delta):
            redraw_priority = 2
        if enemy_impact_shake_time > 0.0:
            enemy_impact_shake_time = maxf(0.0, enemy_impact_shake_time - delta)
            if enemy_impact_shake_time <= 0.0:
                enemy_impact_shake_strength = 0.0
            redraw_priority = 2

    if spider_boss != null and bool(spider_boss.process(delta)):
        redraw_priority = 2

    if not enemy_hitstop_active and skill_fx != null and bool(skill_fx.active):
        if bool(skill_fx.process(delta)):
            skill_fx_finished = true
        redraw_priority = 2

    if card_replace_anim_active and not enemy_hitstop_active:
        card_replace_anim_time += delta
        if not card_replace_committed and card_replace_anim_time >= CARD_REPLACE_NOISE_END:
            if card_replace_slot >= 0 and card_replace_slot < hand.size():
                hand[card_replace_slot] = card_replace_new_card
            card_replace_committed = true
        if card_replace_anim_time >= CARD_REPLACE_ANIM_DURATION:
            if not card_replace_committed and card_replace_slot >= 0 and card_replace_slot < hand.size():
                hand[card_replace_slot] = card_replace_new_card
                card_replace_committed = true
            card_replace_anim_active = false
            card_replace_anim_time = 0.0
            card_replace_slot = -1
            card_replace_old_card = ""
            card_replace_new_card = ""
        redraw_priority = 2

    if skill_turn_pending and skill_fx_finished and not card_replace_anim_active:
        skill_turn_pending = false
        skill_fx_finished = false
        _finish_player_turn()
        redraw_priority = 2

    if reroll_anim_active:
        reroll_anim_time += delta
        if not reroll_new_committed and reroll_anim_time >= REROLL_NOISE_END:
            hand = reroll_new_hand.duplicate()
            reroll_new_committed = true
        if reroll_anim_time >= REROLL_ANIM_DURATION:
            if not reroll_new_committed:
                hand = reroll_new_hand.duplicate()
                reroll_new_committed = true
            reroll_anim_active = false
            reroll_anim_time = 0.0
            reroll_old_hand.clear()
            reroll_new_hand.clear()
            _finish_player_turn()
        redraw_priority = 2

    if stage_clear:
        stage_clear_timer -= delta
        if stage_clear_timer <= 0.0:
            _start_next_stage()
            redraw_priority = 2

    if auto_pass_pending and not game_over and not run_clear and not stage_clear:
        auto_pass_timer = maxf(0.0, auto_pass_timer - delta)
        if auto_pass_timer <= 0.0:
            auto_pass_pending = false
            # 敵の行動などで状況が変わっていれば自動待機を中止する。
            if aim_mode == "" and not _has_legal_player_action():
                last_attack_cells.clear()
                message = "行動不能：自動でターンを進めます。"
                _finish_player_turn()
                redraw_priority = 2

    # 通常プレイ中に常時動くのは主人公/HPのゆっくりした脈動と予告点滅だけ。
    # これらは20FPSでも十分読みやすいので、盤面全体の再描画頻度を約3分の1へ抑える。
    if not game_over and not run_clear and not stage_clear:
        redraw_priority = maxi(redraw_priority, 1)

    _schedule_visual_redraw(delta, redraw_priority)

func _run_timer_should_advance() -> bool:
    if game_over or run_clear or stage_clear:
        return false
    if auto_pass_pending or reroll_anim_active or card_replace_anim_active or skill_turn_pending:
        return false
    if skill_fx != null and bool(skill_fx.active):
        return false
    return true

func _schedule_visual_redraw(delta: float, priority: int) -> void:
    if priority <= 0:
        _redraw_accumulator = 0.0
        return
    var target_fps: float = ACTIVE_REDRAW_FPS if priority >= 2 else IDLE_REDRAW_FPS
    var interval: float = 1.0 / target_fps
    _redraw_accumulator += delta
    if _redraw_accumulator < interval:
        return
    # Preserve the fractional remainder so animation cadence does not drift over time.
    _redraw_accumulator = fmod(_redraw_accumulator, interval)
    queue_redraw()

func _start_next_stage() -> void:
    if current_floor >= TOTAL_FLOORS:
        return
    current_floor += 1
    hp = MAX_HP
    stage_clear = false
    stage_clear_timer = 0.0
    full_charge_hazard_active = false
    walls.clear()
    charged.clear()
    enemies.clear()
    if spider_boss != null:
        spider_boss.reset()
    aim_mode = ""
    active_hand_slot = -1
    auto_pass_pending = false
    auto_pass_timer = 0.0
    reroll_anim_active = false
    reroll_anim_time = 0.0
    reroll_new_committed = false
    reroll_old_hand.clear()
    reroll_new_hand.clear()
    card_replace_anim_active = false
    card_replace_anim_time = 0.0
    card_replace_slot = -1
    card_replace_old_card = ""
    card_replace_new_card = ""
    card_replace_committed = false
    skill_turn_pending = false
    skill_fx_finished = false
    if skill_fx != null:
        skill_fx.reset()
    last_attack_cells.clear()
    dash_path_preview.clear()
    dash_branch_options.clear()
    dash_route_customized = false

    player_pos = Vector2i(GRID_W >> 1, GRID_H >> 1)
    player_facing = Vector2i.DOWN
    _generate_stage_board(5)
    bomb_cursor = player_pos
    warp_cursor = player_pos
    dash_branch_origin = player_pos
    if current_floor == TOTAL_FLOORS:
        message = "四本の脚をすべて破壊してください。脚の踏みつけを避けて攻撃してください。"
    else:
        message = ""
    last_player_damage_source = ""
    last_player_damage_enemy_type = ""
    _reset_floor_analytics_baseline()
    _capture_stage_restart_snapshot()
    _track_floor_start_event()
    _schedule_auto_pass_if_needed()
    queue_redraw()

func _capture_stage_restart_snapshot() -> void:
    # 「この階層を始めから」は新しい乱数を引き直さず、階層入場時点をそのまま復元する。
    # これにより地形/敵配置/手札のリセマラ用途にはならない。
    stage_restart_snapshot = {
        "floor": current_floor,
        "walls": walls.duplicate(true),
        "charged": charged.duplicate(true),
        "enemies": enemies.duplicate(true),
        "hand": hand.duplicate(),
        "player_pos": player_pos,
        "player_facing": player_facing,
        "bat": bat,
        "hp": hp,
        "turn": turn,
        "run_elapsed_seconds": run_elapsed_seconds,
        "step_count": step_count,
        "damage_taken": damage_taken,
        "floor_start_run_time_seconds": floor_start_run_time_seconds,
        "floor_start_turn": floor_start_turn,
        "floor_start_damage_taken": floor_start_damage_taken,
        "floor_hits_taken": floor_hits_taken,
        "message": message,
        "rng_state": rng.state,
    }

func _open_restart_confirm() -> void:
    if stage_clear or run_clear or stage_restart_snapshot.is_empty():
        return
    restart_confirm_active = true
    # 誤操作防止のため初期選択は「いいえ」。
    restart_confirm_yes = false
    queue_redraw()

func _close_restart_confirm() -> void:
    restart_confirm_active = false
    restart_confirm_yes = false
    queue_redraw()

func _handle_restart_confirm_input(keycode: Key) -> void:
    match keycode:
        KEY_LEFT:
            restart_confirm_yes = true
        KEY_RIGHT:
            restart_confirm_yes = false
        KEY_UP, KEY_DOWN:
            restart_confirm_yes = not restart_confirm_yes
        KEY_Z, KEY_ENTER:
            if restart_confirm_yes:
                _restart_current_stage_from_snapshot("reset")
            else:
                _close_restart_confirm()
            return
        KEY_X, KEY_ESCAPE, KEY_R:
            _close_restart_confirm()
            return
        _:
            return
    queue_redraw()

func _restart_current_stage_from_snapshot(reason: String = "reset") -> void:
    if stage_restart_snapshot.is_empty():
        _close_restart_confirm()
        return

    if reason == "retry":
        _track_run_event("floor_retry")

    current_floor = int(stage_restart_snapshot.get("floor", current_floor))

    var saved_walls: Dictionary = stage_restart_snapshot.get("walls", {})
    walls = saved_walls.duplicate(true)
    var saved_charged: Dictionary = stage_restart_snapshot.get("charged", {})
    charged = saved_charged.duplicate(true)

    enemies.clear()
    var saved_enemies: Array = stage_restart_snapshot.get("enemies", [])
    for item in saved_enemies:
        var enemy_copy: Dictionary = item
        enemies.append(enemy_copy.duplicate(true))

    hand.clear()
    var saved_hand: Array = stage_restart_snapshot.get("hand", [])
    for card_id in saved_hand:
        hand.append(str(card_id))

    player_pos = Vector2i(stage_restart_snapshot.get("player_pos", player_pos))
    player_facing = Vector2i(stage_restart_snapshot.get("player_facing", Vector2i.DOWN))
    bat = int(stage_restart_snapshot.get("bat", bat))
    hp = int(stage_restart_snapshot.get("hp", MAX_HP))
    turn = int(stage_restart_snapshot.get("turn", turn))
    run_elapsed_seconds = float(stage_restart_snapshot.get("run_elapsed_seconds", run_elapsed_seconds))
    step_count = int(stage_restart_snapshot.get("step_count", step_count))
    damage_taken = int(stage_restart_snapshot.get("damage_taken", damage_taken))
    floor_start_run_time_seconds = float(stage_restart_snapshot.get("floor_start_run_time_seconds", run_elapsed_seconds))
    floor_start_turn = int(stage_restart_snapshot.get("floor_start_turn", turn))
    floor_start_damage_taken = int(stage_restart_snapshot.get("floor_start_damage_taken", damage_taken))
    floor_hits_taken = int(stage_restart_snapshot.get("floor_hits_taken", 0))
    last_player_damage_source = ""
    last_player_damage_enemy_type = ""
    message = str(stage_restart_snapshot.get("message", ""))
    rng.state = int(stage_restart_snapshot.get("rng_state", rng.state))

    game_over = false
    game_over_reason = ""
    full_charge_hazard_active = _uncharged_count() <= 0
    stage_clear = false
    stage_clear_timer = 0.0
    run_clear = false
    restart_confirm_active = false
    restart_confirm_yes = false

    damage_fx_time_left = 0.0
    damage_fx_intensity = 0.0
    auto_pass_pending = false
    auto_pass_timer = 0.0
    reroll_anim_active = false
    reroll_anim_time = 0.0
    reroll_new_committed = false
    reroll_old_hand.clear()
    reroll_new_hand.clear()
    card_replace_anim_active = false
    card_replace_anim_time = 0.0
    card_replace_slot = -1
    card_replace_old_card = ""
    card_replace_new_card = ""
    card_replace_committed = false
    skill_turn_pending = false
    skill_fx_finished = false
    if skill_fx != null:
        skill_fx.reset()
    if spider_boss != null:
        spider_boss.reset()

    aim_mode = ""
    aim_dir = Vector2i.RIGHT
    active_hand_slot = -1
    bomb_cursor = player_pos
    warp_cursor = player_pos
    dash_path_preview.clear()
    dash_branch_options.clear()
    dash_branch_origin = player_pos
    dash_route_customized = false
    loop_candidates.clear()
    loop_candidate_index = 0
    last_attack_cells.clear()
    enemy_hit_flashes.clear()
    enemy_damage_numbers.clear()
    enemy_destroy_fx.clear()
    enemy_impact_shake_time = 0.0
    enemy_impact_shake_strength = 0.0
    enemy_impact_freeze_time = 0.0
    _redraw_accumulator = 0.0

    _schedule_auto_pass_if_needed()
    queue_redraw()

func _generate_map() -> void:
    if terrain_system != null:
        terrain_system.generate_map()

func _stage_required_enemy_types() -> Array[String]:
    var required: Array[String] = []
    if current_floor == 4:
        required.append("serpent")
    elif current_floor == 5:
        required = ["serpent", "heavy"]
    elif current_floor == 6:
        required = ["serpent", "heavy", "artillery"]
    elif current_floor == 7:
        required = ["heavy", "artillery", "long_serpent"]
    elif current_floor == 8:
        required = ["heavy", "artillery", "long_serpent", "cross_discharge"]
    elif current_floor == 9:
        required = ["heavy", "artillery", "long_serpent", "cross_discharge", "tank"]
    return required

func _stage_has_required_enemy_types() -> bool:
    var required: Array[String] = _stage_required_enemy_types()
    if required.is_empty():
        return true
    var found: Dictionary = {}
    for enemy in enemies:
        found[str(enemy.get("type", ""))] = true
    for enemy_type in required:
        if not found.has(enemy_type):
            return false
    return true

func _generate_stage_board(enemy_count: int) -> void:
    # FLOORごとの大型敵は、そのFLOORで必ず体験できることを優先する。
    # ランダム壁の形で必要な大型敵を置けない時だけ地形を引き直す。
    # 小盤面なので生成時限定のリトライコストは十分小さい。
    if current_floor == TOTAL_FLOORS:
        walls.clear()
        charged.clear()
        enemies.clear()
        _generate_map()
        charged[player_pos] = true
        _spawn_enemies(enemy_count)
        return

    const MAX_STAGE_GENERATION_ATTEMPTS := 24
    for _attempt in range(MAX_STAGE_GENERATION_ATTEMPTS):
        walls.clear()
        charged.clear()
        enemies.clear()
        _generate_map()
        charged[player_pos] = true
        _spawn_enemies(enemy_count)
        if _stage_has_required_enemy_types():
            return

    # 極端な乱数でもカテゴリ欠落を起こさない最終保証。
    # 内部壁なしならFLOOR 4〜9の必須大型敵はすべて配置できる。
    walls.clear()
    charged.clear()
    enemies.clear()
    if terrain_system != null:
        terrain_system.generate_open_map()
    charged[player_pos] = true
    _spawn_enemies(enemy_count)

func _stationary_cells_have_open_loop_margin(cells: Array[Vector2i]) -> bool:
    # 動かない敵はLOOPで攻略できる余白を必ず持つ。
    # 1マス固定砲台なら3x3、横3マス固定砲撃機なら5x3がすべて床になる。
    if cells.is_empty():
        return false
    var min_x: int = cells[0].x
    var max_x: int = cells[0].x
    var min_y: int = cells[0].y
    var max_y: int = cells[0].y
    for cell in cells:
        min_x = mini(min_x, cell.x)
        max_x = maxi(max_x, cell.x)
        min_y = mini(min_y, cell.y)
        max_y = maxi(max_y, cell.y)
    for y in range(min_y - 1, max_y + 2):
        for x in range(min_x - 1, max_x + 2):
            if not _is_floor(Vector2i(x, y)):
                return false
    return true

func _turret_spawn_has_loop_space(pos: Vector2i) -> bool:
    var cells: Array[Vector2i] = [pos]
    return _stationary_cells_have_open_loop_margin(cells)

func _artillery_spawn_has_loop_space(left_cell: Vector2i) -> bool:
    return _stationary_cells_have_open_loop_margin(_artillery_cells(left_cell))

func _spawn_enemies(count: int) -> void:
    if current_floor == TOTAL_FLOORS:
        _spawn_boss_legs()
        return

    var candidates: Array[Vector2i] = []
    for y in range(1, GRID_H - 1):
        for x in range(1, GRID_W - 1):
            var p := Vector2i(x, y)
            if walls.has(p):
                continue
            if _manhattan(p, player_pos) < 5:
                continue
            candidates.push_back(p)
    candidates.shuffle()

    var spawn_count: int = min(count, candidates.size())
    if spawn_count <= 0:
        return

    # FLOOR 1: 基本の追跡敵のみ。
    if current_floor == 1:
        for i in range(spawn_count):
            enemies.append(_make_chaser_enemy(candidates[i]))
        return

    var next_candidate := 0

    # FLOOR 2以降: 固定砲台は周囲8マスも床になる位置だけに生成する。
    # LOOPで囲めない壁際配置しか無い場合は固定砲台を無理に出さず、通常敵へ置き換える。
    var turret_candidate_index := -1
    for i in range(candidates.size()):
        if _turret_spawn_has_loop_space(candidates[i]):
            turret_candidate_index = i
            break
    if turret_candidate_index >= 0:
        var turret_pos: Vector2i = candidates[turret_candidate_index]
        candidates[turret_candidate_index] = candidates[0]
        candidates[0] = turret_pos
        enemies.append(_make_turret_enemy(candidates[next_candidate]))
    else:
        enemies.append(_make_chaser_enemy(candidates[next_candidate]))
    next_candidate += 1

    # FLOOR 3以降: 突進機と逃走機を最低1体ずつ保証。
    # どちらも1マス特殊敵なので、FLOOR 3で挙動の違いを比較できる。
    if current_floor >= 3 and next_candidate < spawn_count:
        enemies.append(_make_charger_enemy(candidates[next_candidate]))
        next_candidate += 1
    if current_floor >= 3 and next_candidate < spawn_count:
        enemies.append(_make_runner_enemy(candidates[next_candidate]))
        next_candidate += 1

    # 残り枠は、そのFLOORまでに解禁済みの1マス敵から抽選する。
    # 固定砲台の抽選位置にLOOP余白が無い場合は追跡敵へ置き換える。
    while next_candidate < spawn_count:
        var roll: int = rng.randi_range(0, 99)
        var spawn_pos: Vector2i = candidates[next_candidate]
        if current_floor == 2:
            if roll < 28 and _turret_spawn_has_loop_space(spawn_pos):
                enemies.append(_make_turret_enemy(spawn_pos))
            else:
                enemies.append(_make_chaser_enemy(spawn_pos))
        else:
            if roll < 18 and _turret_spawn_has_loop_space(spawn_pos):
                enemies.append(_make_turret_enemy(spawn_pos))
            elif roll < 38:
                enemies.append(_make_charger_enemy(spawn_pos))
            elif roll < 58:
                enemies.append(_make_runner_enemy(spawn_pos))
            else:
                enemies.append(_make_chaser_enemy(spawn_pos))
        next_candidate += 1

    # FLOOR 4以降: 初めての複数マス敵として二連蛇を最低1体保証する。
    # 既に配置した1マス敵のうち、隣接床を胴体として確保できる1体を二連蛇へ置き換える。
    if current_floor >= 4:
        _promote_one_enemy_to_serpent()

    # FLOOR 5以降: 2x2重装機を最低1体保証する。
    # 4マス占有そのものの圧迫感と、爆弾が大型敵に効率的になるかを検証する。
    if current_floor >= 5:
        _promote_one_enemy_to_heavy()

    # FLOOR 6以降: 横3マスの砲撃機を最低1体保証する。
    # 左右の砲身から外向きへ同時射撃し、3マス敵の形そのものを攻撃予告に使う。
    if current_floor >= 6:
        _promote_one_enemy_to_artillery()

    # FLOOR 7以降: 5マス長蛇を最低1体保証する。
    # 初めての5〜9マス敵として、頭1マス＋胴体4マスが軌跡を追従する。
    if current_floor >= 7:
        _promote_one_enemy_to_long_serpent()

    if current_floor >= 8:
        _promote_one_enemy_to_cross_discharge()

    # FLOOR 9以降: 3x3重戦車を最低1体保証する。
    # 9マス占有と、2ターン予告の正面3マス幅砲撃で盤面そのものを圧迫する。
    if current_floor >= 9:
        _promote_one_enemy_to_tank()

func _boss_leg_cells(top_left: Vector2i) -> Array[Vector2i]:
    if spider_boss == null:
        var empty: Array[Vector2i] = []
        return empty
    return spider_boss.leg_cells(top_left)

func _spawn_boss_legs() -> void:
    if spider_boss == null:
        return
    spider_boss.spawn_legs(enemies)
    _boss_schedule_next_telegraph()

func _boss_all_legs_destroyed() -> bool:
    if current_floor != TOTAL_FLOORS or spider_boss == null:
        return false
    return bool(spider_boss.all_legs_destroyed(enemies))

func _boss_schedule_next_telegraph() -> void:
    if spider_boss == null:
        return
    var scheduled: bool = bool(spider_boss.schedule_next_telegraph(enemies, player_pos, Callable(self, "_is_floor")))
    if scheduled:
        _play_sfx(SFX_TANK_WARN)

func _boss_stomp(index: int) -> void:
    if spider_boss == null:
        return
    var result: Dictionary = spider_boss.stomp(enemies, index, last_attack_cells, player_pos, Callable(self, "_is_floor"))
    if not bool(result.get("valid", false)):
        return
    _play_sfx(SFX_BOSS_STOMP)
    if bool(result.get("hit_player", false)):
        _apply_player_damage(1, "boss_stomp", "boss_leg")
        if hp > 0:
            var stomp_cells: Array[Vector2i] = []
            for item in result.get("cells", []):
                stomp_cells.append(Vector2i(item))
            var knockback_target: Vector2i = _boss_stomp_knockback_target(stomp_cells)
            if knockback_target != player_pos:
                player_pos = knockback_target
                message = "踏みつけ：HP -1。脚の外へ弾き出されました。"
            else:
                message = "踏みつけ：HP -1。"
        else:
            message = "踏みつけ：HP -1。"
    else:
        message = "脚が踏みつけました。"

func _boss_stomp_knockback_target(stomp_cells: Array[Vector2i]) -> Vector2i:
    if stomp_cells.is_empty() or not stomp_cells.has(player_pos):
        return player_pos

    var stomp_set: Dictionary = {}
    for cell in stomp_cells:
        stomp_set[cell] = true

    # 強制移動なので歩数・BAT取得・帯電付与は発生しない。
    # 脚の内側だけは探索経路として通し、最短の安全な外側床へ押し出す。
    var open: Array[Vector2i] = [player_pos]
    var seen: Dictionary = {player_pos: true}
    var read_index := 0
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    while read_index < open.size():
        var cur: Vector2i = open[read_index]
        read_index += 1
        if not stomp_set.has(cur) and _is_floor(cur) and _enemy_index_at(cur) == -1:
            return cur
        for d in dirs:
            var next: Vector2i = cur + d
            if seen.has(next) or not _is_floor(next):
                continue
            if not stomp_set.has(next) and _enemy_index_at(next) != -1:
                continue
            seen[next] = true
            open.append(next)
    return player_pos

func _boss_take_turn() -> void:
    if spider_boss == null or _boss_all_legs_destroyed():
        return

    # 1巡の中では生存脚を1本ずつ動かし、行動済み脚は未行動脚が残る間は再行動しない。
    # さらに各脚は個別に4ターン間隔を維持する。1ターンに動く脚は最大1本。
    spider_boss.begin_turn()
    var index: int = int(spider_boss.find_telegraphed_leg(enemies))
    if index != -1:
        _boss_stomp(index)
        if hp <= 0:
            return
        spider_boss.leg_cursor = (index + 1) % enemies.size()

    # 次のボスターンに「この巡で未行動」かつ4ターン間隔を満たす脚がいれば1ターン予告を出す。
    # 候補がいない場合は何もせず、休止ターンになる。
    _boss_schedule_next_telegraph()

func _make_chaser_enemy(pos: Vector2i) -> Dictionary:
    return {
        "type": "chaser",
        "pos": pos,
        "hp": GameBalance.ENEMY_HP_PER_CELL,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO
    }

func _make_turret_enemy(pos: Vector2i) -> Dictionary:
    return {
        "type": "turret",
        "pos": pos,
        "hp": GameBalance.ENEMY_HP_PER_CELL,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO,
        "turret_dir": Vector2i.ZERO,
        "cooldown": 0
    }

func _make_charger_enemy(pos: Vector2i) -> Dictionary:
    return {
        "type": "charger",
        "pos": pos,
        "hp": GameBalance.ENEMY_HP_PER_CELL,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO,
        "charge_dir": Vector2i.ZERO
    }


func _make_runner_enemy(pos: Vector2i) -> Dictionary:
    return {
        "type": "runner",
        "pos": pos,
        "hp": GameBalance.ENEMY_HP_PER_CELL,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO
    }

func _make_serpent_enemy(head: Vector2i, tail: Vector2i) -> Dictionary:
    var face: Vector2i = head - tail
    if face == Vector2i.ZERO:
        face = Vector2i.DOWN
    return {
        "type": "serpent",
        "pos": head,
        "tail": tail,
        "hp": GameBalance.ENEMY_HP_PER_CELL * 2,
        "facing": face,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO
    }

func _make_long_serpent_enemy(segments: Array[Vector2i]) -> Dictionary:
    var face := Vector2i.DOWN
    if segments.size() >= 2:
        face = segments[0] - segments[1]
        if face == Vector2i.ZERO:
            face = Vector2i.DOWN
    return {
        "type": "long_serpent",
        "pos": segments[0],
        "segments": segments.duplicate(),
        "hp": GameBalance.ENEMY_HP_PER_CELL * segments.size(),
        "facing": face,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO
    }

func _make_heavy_enemy(top_left: Vector2i) -> Dictionary:
    return {
        "type": "heavy",
        "pos": top_left,
        "hp": GameBalance.ENEMY_HP_PER_CELL * 4,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO,
        "move_phase": 0
    }

func _make_artillery_enemy(left_cell: Vector2i) -> Dictionary:
    return {
        "type": "artillery",
        "pos": left_cell,
        "hp": GameBalance.ENEMY_HP_PER_CELL * 3,
        "facing": Vector2i.RIGHT,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO,
        "cooldown": 0
    }

func _make_cross_discharge_enemy(center: Vector2i) -> Dictionary:
    return {
        "type": "cross_discharge",
        "pos": center,
        "hp": GameBalance.ENEMY_HP_PER_CELL * 5,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO,
        "cooldown": 1
    }

func _make_tank_enemy(top_left: Vector2i) -> Dictionary:
    return {
        "type": "tank",
        "pos": top_left,
        "hp": GameBalance.ENEMY_HP_PER_CELL * 9,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": Vector2i.ZERO,
        "tank_dir": Vector2i.DOWN,
        "telegraph_turns": 0,
        "move_phase": 0
    }

func _promote_one_enemy_to_serpent() -> void:
    if enemies.is_empty():
        return

    var occupied: Dictionary = {}
    for e in enemies:
        for cell in _enemy_cells(e):
            occupied[cell] = true

    # まず基本追跡敵から置き換え、いなければ他の1マス敵も候補にする。
    var candidate_indices: Array[int] = []
    for i in range(enemies.size()):
        if str(enemies[i].get("type", "chaser")) == "chaser":
            candidate_indices.append(i)
    for i in range(enemies.size()):
        if not candidate_indices.has(i):
            candidate_indices.append(i)

    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for index in candidate_indices:
        var head: Vector2i = enemies[index]["pos"]
        var shuffled_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
        shuffled_dirs.shuffle()
        for d in shuffled_dirs:
            var tail: Vector2i = head - d
            if not _is_floor(tail):
                continue
            if tail == player_pos or occupied.has(tail):
                continue
            enemies[index] = _make_serpent_enemy(head, tail)
            return

func _promote_one_enemy_to_long_serpent() -> void:
    if enemies.is_empty():
        return

    # 既存敵1体を5マス長蛇へ置き換える。FLOOR 7の新カテゴリが欠けないよう、
    # 必要なら元位置にこだわらず盤面内の空き直線5マスへ再配置する。
    var candidate_indices: Array[int] = []
    for i in range(enemies.size()):
        if str(enemies[i].get("type", "chaser")) == "serpent":
            candidate_indices.append(i)
    for i in range(enemies.size()):
        if not candidate_indices.has(i):
            candidate_indices.append(i)

    for index in candidate_indices:
        var occupied: Dictionary = {}
        for j in range(enemies.size()):
            if j == index:
                continue
            for cell in _enemy_cells(enemies[j]):
                occupied[cell] = true

        var placements: Array = []
        # 横5マス。
        for y in range(1, GRID_H - 1):
            for x in range(1, GRID_W - 5):
                var cells_h: Array[Vector2i] = []
                var valid_h := true
                for k in range(5):
                    var cell_h := Vector2i(x + k, y)
                    if not _is_floor(cell_h) or cell_h == player_pos or occupied.has(cell_h):
                        valid_h = false
                        break
                    cells_h.append(cell_h)
                if valid_h:
                    placements.append(cells_h)
        # 縦5マス。
        for x in range(1, GRID_W - 1):
            for y in range(1, GRID_H - 5):
                var cells_v: Array[Vector2i] = []
                var valid_v := true
                for k in range(5):
                    var cell_v := Vector2i(x, y + k)
                    if not _is_floor(cell_v) or cell_v == player_pos or occupied.has(cell_v):
                        valid_v = false
                        break
                    cells_v.append(cell_v)
                if valid_v:
                    placements.append(cells_v)

        if placements.is_empty():
            continue
        placements.shuffle()
        var selected_variant: Array = placements[0]
        var selected: Array[Vector2i] = []
        for item in selected_variant:
            selected.append(Vector2i(item))
        if rng.randi_range(0, 1) == 1:
            selected.reverse()
        enemies[index] = _make_long_serpent_enemy(selected)
        return

func _promote_one_enemy_to_heavy() -> void:
    if enemies.is_empty():
        return

    var occupied: Dictionary = {}
    for e in enemies:
        for cell in _enemy_cells(e):
            occupied[cell] = true

    # 1マス敵を2x2へ置き換える。既存の二連蛇は候補にしない。
    var candidate_indices: Array[int] = []
    for i in range(enemies.size()):
        if _enemy_cells(enemies[i]).size() == 1:
            candidate_indices.append(i)
    candidate_indices.shuffle()

    var corner_offsets: Array[Vector2i] = [
        Vector2i.ZERO,
        Vector2i(-1, 0),
        Vector2i(0, -1),
        Vector2i(-1, -1)
    ]

    for index in candidate_indices:
        var anchor: Vector2i = enemies[index]["pos"]
        occupied.erase(anchor)
        var shuffled_offsets: Array[Vector2i] = [
            Vector2i.ZERO,
            Vector2i(-1, 0),
            Vector2i(0, -1),
            Vector2i(-1, -1)
        ]
        shuffled_offsets.shuffle()
        for offset in shuffled_offsets:
            var top_left: Vector2i = anchor + offset
            var cells: Array[Vector2i] = [
                top_left,
                top_left + Vector2i.RIGHT,
                top_left + Vector2i.DOWN,
                top_left + Vector2i(1, 1)
            ]
            var valid := true
            for cell in cells:
                if not _is_floor(cell) or cell == player_pos or occupied.has(cell):
                    valid = false
                    break
            if not valid:
                continue
            enemies[index] = _make_heavy_enemy(top_left)
            return
        occupied[anchor] = true

func _promote_one_enemy_to_artillery() -> void:
    if enemies.is_empty():
        return

    # 1マス敵1体を横3マス固定砲撃機へ置き換える。
    # まず既存位置を含む配置を試し、難しければ盤面内の空き横3マスへ再配置する。
    var candidate_indices: Array[int] = []
    for i in range(enemies.size()):
        if _enemy_cells(enemies[i]).size() == 1:
            candidate_indices.append(i)
    if candidate_indices.is_empty():
        return
    candidate_indices.shuffle()

    for index in candidate_indices:
        var occupied: Dictionary = {}
        for j in range(enemies.size()):
            if j == index:
                continue
            for cell in _enemy_cells(enemies[j]):
                occupied[cell] = true

        var anchor: Vector2i = enemies[index]["pos"]
        var left_candidates: Array[Vector2i] = [
            anchor,
            anchor - Vector2i.RIGHT,
            anchor - Vector2i(2, 0)
        ]
        left_candidates.shuffle()
        for left_cell in left_candidates:
            if _artillery_can_occupy(left_cell, occupied) and _artillery_spawn_has_loop_space(left_cell):
                enemies[index] = _make_artillery_enemy(left_cell)
                return

        # 既存位置の周辺で入らない場合でも、FLOOR 6の新カテゴリが欠けないよう
        # 空いている横3マスを盤面全体から探して置き換える。
        var free_triples: Array[Vector2i] = []
        for y in range(1, GRID_H - 1):
            for x in range(1, GRID_W - 3):
                var left_cell := Vector2i(x, y)
                if _artillery_can_occupy(left_cell, occupied) and _artillery_spawn_has_loop_space(left_cell):
                    free_triples.append(left_cell)
        if not free_triples.is_empty():
            free_triples.shuffle()
            enemies[index] = _make_artillery_enemy(free_triples[0])
            return

func _promote_one_enemy_to_cross_discharge() -> void:
    if enemies.is_empty():
        return

    # FLOOR 8の5マス敵。中央＋上下左右の十字5マスを確保できる1マス敵を置き換える。
    # 既存位置で入らなければ盤面全体から空き十字を探し、新カテゴリの出現を保証する。
    var candidate_indices: Array[int] = []
    for i in range(enemies.size()):
        if _enemy_cells(enemies[i]).size() == 1:
            candidate_indices.append(i)
    if candidate_indices.is_empty():
        return
    candidate_indices.shuffle()

    for index in candidate_indices:
        var occupied: Dictionary = {}
        for j in range(enemies.size()):
            if j == index:
                continue
            for cell in _enemy_cells(enemies[j]):
                occupied[cell] = true

        var anchor: Vector2i = enemies[index]["pos"]
        if _cross_can_occupy(anchor, occupied):
            enemies[index] = _make_cross_discharge_enemy(anchor)
            return

        var free_centers: Array[Vector2i] = []
        for y in range(2, GRID_H - 2):
            for x in range(2, GRID_W - 2):
                var center := Vector2i(x, y)
                if _cross_can_occupy(center, occupied):
                    free_centers.append(center)
        if not free_centers.is_empty():
            free_centers.shuffle()
            enemies[index] = _make_cross_discharge_enemy(free_centers[0])
            return

func _promote_one_enemy_to_tank() -> void:
    if enemies.is_empty():
        return

    # FLOOR 9の9マス敵。既存の1マス敵1体を3x3重戦車へ置き換える。
    # 元位置周辺に入らない場合は、盤面全体から空き3x3を探して再配置する。
    var candidate_indices: Array[int] = []
    for i in range(enemies.size()):
        if _enemy_cells(enemies[i]).size() == 1:
            candidate_indices.append(i)
    if candidate_indices.is_empty():
        return
    candidate_indices.shuffle()

    for index in candidate_indices:
        var occupied: Dictionary = {}
        for j in range(enemies.size()):
            if j == index:
                continue
            for cell in _enemy_cells(enemies[j]):
                occupied[cell] = true

        var anchor: Vector2i = enemies[index]["pos"]
        var offsets: Array[Vector2i] = []
        for oy in range(-2, 1):
            for ox in range(-2, 1):
                offsets.append(Vector2i(ox, oy))
        offsets.shuffle()
        for offset in offsets:
            var top_left: Vector2i = anchor + offset
            if _tank_can_occupy(top_left, occupied):
                enemies[index] = _make_tank_enemy(top_left)
                return

        var free_positions: Array[Vector2i] = []
        for y in range(1, GRID_H - 3):
            for x in range(1, GRID_W - 3):
                var top_left := Vector2i(x, y)
                if _tank_can_occupy(top_left, occupied):
                    free_positions.append(top_left)
        if not free_positions.is_empty():
            free_positions.shuffle()
            enemies[index] = _make_tank_enemy(free_positions[0])
            return

func _random_card_excluding(excluded: Array[String]) -> String:
    var candidates: Array[String] = []
    for card_id in CardCatalog.POOL:
        if not excluded.has(card_id):
            candidates.append(card_id)
    if candidates.is_empty():
        return ""
    return candidates[rng.randi_range(0, candidates.size() - 1)]

func _draw_new_hand() -> void:
    var excluded: Array[String] = []
    _draw_new_hand_excluding(excluded)

func _draw_new_hand_excluding(excluded: Array[String]) -> void:
    hand.clear()
    while hand.size() < 3:
        var blocked: Array[String] = []
        for card_id in excluded:
            if not blocked.has(card_id):
                blocked.append(card_id)
        for card_id in hand:
            if not blocked.has(card_id):
                blocked.append(card_id)

        var card_id: String = _random_card_excluding(blocked)
        if card_id == "":
            break
        hand.append(card_id)

func _replace_hand_slot(slot: int) -> void:
    if slot < 0 or slot >= hand.size():
        return

    # スキル使用後の補充では、使用直前の手札3種をすべて抽選対象から外す。
    # つまり「今使ったカード」も「残っている他2枚」も連続では出ない。
    # 6種中、使用直前の手札に無かった残り3種だけから1枚を補充する。
    var excluded: Array[String] = []
    for card_id in hand:
        if not excluded.has(card_id):
            excluded.append(card_id)

    var card_id: String = _random_card_excluding(excluded)
    if card_id != "":
        hand[slot] = card_id

func _title_exit_available() -> bool:
    # ブラウザではページ/タブをゲーム側から閉じられないためEXITを出さない。
    return not OS.has_feature("web")

func _handle_title_input(keycode: Key) -> void:
    if title_exit_pending:
        return
    match keycode:
        KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
            # Web版はSTARTのみ。存在しないEXITへカーソルを動かさない。
            if not _title_exit_available():
                title_menu_index = 0
                return
            title_menu_index = 1 - title_menu_index
            _play_sfx(SFX_UI_MENU_MOVE)
            queue_redraw()
        KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
            _play_sfx(SFX_UI_MENU_DECIDE)
            if title_menu_index == 0 or not _title_exit_available():
                _start_run_from_title()
            else:
                _quit_from_title_after_sfx()
        _:
            return

func _quit_from_title_after_sfx() -> void:
    # EXITでも決定音が途中で切れないよう、短いSE分だけ終了を待つ。
    title_exit_pending = true
    await get_tree().create_timer(0.14).timeout
    get_tree().quit()

func _start_run_from_title() -> void:
    reset_run()
    if web_analytics != null:
        web_analytics.track("game_start", _analytics_run_payload())
    _track_floor_start_event()
    title_screen_active = false
    title_menu_index = 0
    queue_redraw()

func _draw_title_screen() -> void:
    var font: Font = ui_font
    var center_x := WINDOW_SIZE.x * 0.5

    # 本編と同じ電気色を使った、情報量を抑えたタイトル画面。
    for x in range(0, int(WINDOW_SIZE.x) + CELL, CELL):
        draw_line(Vector2(x, 0), Vector2(x, WINDOW_SIZE.y), Color(0.10, 0.17, 0.23, 0.20), 1.0)
    for y in range(0, int(WINDOW_SIZE.y) + CELL, CELL):
        draw_line(Vector2(0, y), Vector2(WINDOW_SIZE.x, y), Color(0.10, 0.17, 0.23, 0.20), 1.0)

    var pulse := (sin(float(Time.get_ticks_msec()) * 0.0026) + 1.0) * 0.5
    var title_color := C_CHARGED_INNER.darkened(0.08).lerp(Color.WHITE, pulse * 0.20)
    draw_string(font, Vector2(center_x - 260.0, 205.0), "VOLT PATH", HORIZONTAL_ALIGNMENT_CENTER, 520.0, 58, title_color)
    draw_string(font, Vector2(center_x - 220.0, 244.0), "CHARGE  /  CONNECT  /  SURVIVE", HORIZONTAL_ALIGNMENT_CENTER, 440.0, 15, C_DIM)

    _draw_title_menu_item(Rect2(center_x - 150.0, 330.0, 300.0, 58.0), "START", true if not _title_exit_available() else title_menu_index == 0)
    if _title_exit_available():
        _draw_title_menu_item(Rect2(center_x - 150.0, 404.0, 300.0, 58.0), "EXIT", title_menu_index == 1)
        draw_string(font, Vector2(center_x - 220.0, 530.0), "↑↓  SELECT    Z / ENTER  DECIDE", HORIZONTAL_ALIGNMENT_CENTER, 440.0, 16, C_DIM)
    else:
        draw_string(font, Vector2(center_x - 220.0, 475.0), "Z / ENTER  START", HORIZONTAL_ALIGNMENT_CENTER, 440.0, 16, C_DIM)

    draw_string(font, Vector2(center_x - 100.0, 675.0), "ver 0.949", HORIZONTAL_ALIGNMENT_CENTER, 200.0, 14, C_DIM.darkened(0.12))

func _draw_title_menu_item(rect: Rect2, label: String, selected: bool) -> void:
    var font: Font = ui_font
    var fill := C_PANEL_ACTIVE if selected else C_PANEL
    var edge := C_CHARGED_INNER if selected else C_FLOOR_EDGE
    draw_rect(rect, fill, true)
    draw_rect(rect, edge, false, 2.0 if selected else 1.0)
    if selected:
        var marker := Rect2(rect.position + Vector2(12.0, 13.0), Vector2(5.0, rect.size.y - 26.0))
        draw_rect(marker, C_CHARGED_INNER, true)
    draw_string(font, rect.position + Vector2(0.0, 38.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22, C_TEXT if selected else C_DIM)

func _card_name(card_id: String) -> String:
    return CardCatalog.display_name(card_id)

func _card_cost(card_id: String) -> int:
    return CardCatalog.cost(card_id)

func _card_short_info(card_id: String) -> String:
    return CardCatalog.short_info(card_id)

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if not event.pressed or event.echo:
        return

    if title_screen_active:
        _handle_title_input(event.keycode)
        return

    if restart_confirm_active:
        _handle_restart_confirm_input(event.keycode)
        return

    if run_clear:
        if event.keycode == KEY_Z:
            _play_sfx(SFX_UI_MENU_DECIDE)
            _return_to_title()
        return

    if game_over:
        match event.keycode:
            KEY_Z:
                _play_sfx(SFX_UI_MENU_DECIDE)
                _restart_current_stage_from_snapshot("retry")
            KEY_X:
                _play_sfx(SFX_UI_MENU_DECIDE)
                _return_to_title()
        return

    if event.keycode == KEY_R:
        # 通常プレイ中だけ現在階層のリスタート確認を開く。GAME OVER後はZ RETRY / X TITLE。
        if not stage_clear:
            _open_restart_confirm()
        return

    if stage_clear:
        return

    if auto_pass_pending:
        return

    if reroll_anim_active:
        return

    if card_replace_anim_active:
        return

    if skill_fx != null and bool(skill_fx.active):
        return

    if aim_mode != "":
        _handle_aim_input(event.keycode)
        queue_redraw()
        return

    match event.keycode:
        KEY_UP:
            _try_move(Vector2i.UP)
        KEY_DOWN:
            _try_move(Vector2i.DOWN)
        KEY_LEFT:
            _try_move(Vector2i.LEFT)
        KEY_RIGHT:
            _try_move(Vector2i.RIGHT)
        KEY_1:
            _play_hand_slot(0)
        KEY_2:
            _play_hand_slot(1)
        KEY_3:
            _play_hand_slot(2)
        KEY_0:
            _reroll_hand()
        _:
            return
    queue_redraw()

func _play_hand_slot(slot: int) -> void:
    if slot < 0 or slot >= hand.size():
        return
    var card_id: String = hand[slot]
    var cost := _card_cost(card_id)
    if bat < cost:
        _play_sfx(SFX_UI_BAT_DENIED)
        message = "%sにはBATが%d必要です。" % [_card_name(card_id), cost]
        return

    active_hand_slot = slot
    match card_id:
        CARD_ARC:
            _begin_arc()
        CARD_SURGE:
            _begin_surge()
        CARD_BOMB:
            _begin_bomb()
        CARD_WARP:
            _begin_warp()
        CARD_DASH:
            _begin_dash()
        CARD_LOOP:
            _begin_loop()

func _reroll_hand() -> void:
    if bat < REROLL_COST:
        _play_sfx(SFX_UI_BAT_DENIED)
        message = "リロールにはBATが%d必要です。" % REROLL_COST
        return
    _spend_bat(REROLL_COST)
    _play_sfx(SFX_UI_REROLL)

    # 旧手札を残したまま新手札を先に抽選し、短い切替演出の後で確定する。
    reroll_old_hand.clear()
    for card_id in hand:
        reroll_old_hand.append(card_id)
    # リロールでは旧手札3枚をすべて抽選対象から外す。
    # 6種中、現在手札にない残り3種へ完全に入れ替わる。
    _draw_new_hand_excluding(reroll_old_hand)
    reroll_new_hand.clear()
    for card_id in hand:
        reroll_new_hand.append(card_id)
    hand = reroll_old_hand.duplicate()

    reroll_anim_active = true
    reroll_anim_time = 0.0
    reroll_new_committed = false
    last_attack_cells.clear()
    message = ""

func _handle_aim_input(keycode: int) -> void:
    var d: Vector2i = Vector2i.ZERO
    match keycode:
        KEY_UP:
            d = Vector2i.UP
        KEY_DOWN:
            d = Vector2i.DOWN
        KEY_LEFT:
            d = Vector2i.LEFT
        KEY_RIGHT:
            d = Vector2i.RIGHT
        KEY_X, KEY_ESCAPE:
            aim_mode = ""
            active_hand_slot = -1
            dash_path_preview.clear()
            dash_branch_options.clear()
            dash_route_customized = false
            loop_candidates.clear()
            loop_candidate_index = 0
            message = "カードをキャンセルしました。"
            _schedule_auto_pass_if_needed()
            return
        KEY_Z, KEY_ENTER, KEY_SPACE:
            if aim_mode == CARD_ARC:
                _confirm_arc()
            elif aim_mode == CARD_SURGE:
                _confirm_surge()
            elif aim_mode == CARD_BOMB:
                _confirm_bomb()
            elif aim_mode == CARD_WARP:
                _confirm_warp()
            elif aim_mode == CARD_DASH:
                _confirm_dash()
            elif aim_mode == CARD_LOOP:
                _confirm_loop()
            return
        _:
            return

    if aim_mode == CARD_ARC:
        aim_dir = d
    elif aim_mode == CARD_DASH:
        _handle_dash_direction_input(d)
    elif aim_mode == CARD_BOMB:
        var next: Vector2i = bomb_cursor + d
        if _in_bounds(next):
            bomb_cursor = next
    elif aim_mode == CARD_WARP:
        var next: Vector2i = warp_cursor + d
        if _in_bounds(next):
            warp_cursor = next
    elif aim_mode == CARD_LOOP:
        _cycle_loop_candidate(d)

func _try_move(d: Vector2i) -> void:
    last_attack_cells.clear()
    player_facing = d
    var target: Vector2i = player_pos + d
    if not _is_floor(target):
        message = "その方向には進めません。"
        return
    if _enemy_index_at(target) != -1:
        message = "敵がいて進めません。カードで攻撃してください。"
        return

    player_pos = target
    step_count += 1
    if charged.has(player_pos):
        _play_sfx(SFX_STEP_CHARGED)
        message = ""
    else:
        charged[player_pos] = true
        var _gain := _gain_bat(1)
        _play_sfx(SFX_STEP_CHARGE)
        message = ""

    var overload_damage: int = _apply_full_charge_movement_damage()
    if overload_damage > 0:
        message = "全面帯電：移動ダメージ HP -%d" % overload_damage
    _finish_player_turn()

func _start_arc_fx(path: Array[Vector2i]) -> void:
    skill_turn_pending = true
    skill_fx_finished = false
    skill_fx.start_arc(path, player_pos)
    last_attack_cells.clear()

func _start_surge_fx(region: Dictionary) -> void:
    skill_turn_pending = true
    skill_fx_finished = false
    skill_fx.start_surge(region, player_pos)
    last_attack_cells.clear()

func _start_bomb_fx(blast: Array[Vector2i], origin: Vector2i) -> void:
    skill_turn_pending = true
    skill_fx_finished = false
    skill_fx.start_bomb(blast, origin)
    last_attack_cells.clear()

func _start_warp_fx(origin: Vector2i, target: Vector2i) -> void:
    skill_turn_pending = true
    skill_fx_finished = false
    skill_fx.start_warp(origin, target)
    last_attack_cells.clear()

func _start_dash_fx(origin: Vector2i, path: Array[Vector2i], target: Vector2i) -> void:
    skill_turn_pending = true
    skill_fx_finished = false
    skill_fx.start_dash(origin, path, target)
    last_attack_cells.clear()

func _start_loop_fx(boundary: Array[Vector2i], inside: Array[Vector2i]) -> void:
    skill_turn_pending = true
    skill_fx_finished = false
    skill_fx.start_loop(boundary, inside, player_pos)
    last_attack_cells.clear()

func _draw_skill_fx() -> void:
    if skill_fx == null:
        return
    skill_fx.draw(self, Callable(self, "_cell_center"), Callable(self, "_cell_rect"), Callable(self, "_player_pulse_color"), player_facing)


func _begin_arc() -> void:
    aim_mode = CARD_ARC
    aim_dir = Vector2i.RIGHT
    message = ""

func _confirm_arc() -> void:
    var cost := _card_cost(CARD_ARC)
    if bat < cost:
        aim_mode = ""
        active_hand_slot = -1
        message = "BATが足りません。"
        return
    _spend_bat(cost)
    _play_sfx(SFX_CARD_ARC)
    last_attack_cells.clear()
    var path := _arc_path(aim_dir)
    var hit := false
    for p in path:
        last_attack_cells.append(p)
        var idx := _enemy_index_at(p)
        if idx != -1:
            _damage_enemy(idx, GameBalance.ARC_DAMAGE, [p])
            hit = true
            break
    if hit:
        _play_sfx(SFX_ENEMY_HIT)
    _remove_dead_enemies()
    _consume_active_card()
    aim_mode = ""
    active_hand_slot = -1
    message = "直線伝導が命中しました。%dダメージ。" % GameBalance.ARC_DAMAGE if hit else "帯電した直線上に敵がいません。"
    _start_arc_fx(last_attack_cells)

func _arc_path(d: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    var p: Vector2i = player_pos + d
    var steps := 0
    while steps < 7 and _is_floor(p) and charged.has(p):
        out.append(p)
        p += d
        steps += 1
    return out

func _begin_surge() -> void:
    aim_mode = CARD_SURGE
    message = ""

func _confirm_surge() -> void:
    var cost := _card_cost(CARD_SURGE)
    if bat < cost:
        aim_mode = ""
        active_hand_slot = -1
        message = "一斉放電にはBATが%d必要です。" % cost
        return
    _spend_bat(cost)
    _play_sfx(SFX_CARD_SURGE)
    last_attack_cells.clear()
    var region := _connected_charged_region(player_pos)
    var hit_count := 0
    var total_damage := 0
    for key in region.keys():
        var p: Vector2i = Vector2i(key)
        last_attack_cells.append(p)
    for i in range(enemies.size()):
        var covered_cells: int = _enemy_covered_region_count(enemies[i], region)
        if covered_cells <= 0:
            continue
        var damage: int = GameBalance.SURGE_DAMAGE_PER_CELL * covered_cells
        var hit_cells: Array[Vector2i] = _enemy_hit_cells_from_region(enemies[i], region)
        _damage_enemy(i, damage, hit_cells)
        hit_count += 1
        total_damage += damage
    if hit_count > 0:
        _play_sfx(SFX_ENEMY_HIT)
    _remove_dead_enemies()
    _consume_active_card()
    aim_mode = ""
    active_hand_slot = -1
    message = "一斉放電：%d体に合計%dダメージ。" % [hit_count, total_damage]
    _start_surge_fx(region)

func _connected_charged_region(start: Vector2i) -> Dictionary:
    var seen: Dictionary = {}
    if not charged.has(start):
        return seen
    var open: Array[Vector2i] = [start]
    seen[start] = true
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    while not open.is_empty():
        var cur: Vector2i = open.pop_front()
        for d in dirs:
            var n: Vector2i = cur + d
            if charged.has(n) and not seen.has(n):
                seen[n] = true
                open.push_back(n)
    return seen

func _begin_bomb() -> void:
    aim_mode = CARD_BOMB
    bomb_cursor = player_pos
    message = ""

func _confirm_bomb() -> void:
    var cost := _card_cost(CARD_BOMB)
    if not _is_floor(bomb_cursor) or not charged.has(bomb_cursor):
        message = "爆弾は帯電マスを爆心にしてください。"
        return
    if bat < cost:
        aim_mode = ""
        active_hand_slot = -1
        message = "BATが足りません。"
        return
    _spend_bat(cost)
    _play_sfx(SFX_CARD_BOMB)
    last_attack_cells.clear()
    var blast: Array[Vector2i] = []
    for oy in range(-1, 2):
        for ox in range(-1, 2):
            var p: Vector2i = bomb_cursor + Vector2i(ox, oy)
            if _is_floor(p):
                blast.append(p)
                last_attack_cells.append(p)
                # 新仕様: 爆発した床はすべて帯電する。
                # 強い攻撃ほど、将来BATを得られる未帯電床を先に使い切る。
                charged[p] = true

    var hit_count: int = 0
    var total_damage: int = 0
    for i in range(enemies.size()):
        var covered_cells: int = _enemy_covered_cell_count(enemies[i], blast)
        if covered_cells <= 0:
            continue
        # すべての敵で、爆発に入った占有マス数ぶんダメージが重なる。
        var damage: int = GameBalance.BOMB_DAMAGE_PER_CELL * covered_cells
        var hit_cells: Array[Vector2i] = _enemy_hit_cells_from_list(enemies[i], blast)
        _damage_enemy(i, damage, hit_cells)
        hit_count += 1
        total_damage += damage
    if hit_count > 0:
        _play_sfx(SFX_ENEMY_HIT)
    _remove_dead_enemies()
    _consume_active_card()
    aim_mode = ""
    active_hand_slot = -1
    message = "爆弾：%d体に合計%dダメージ。" % [hit_count, total_damage]
    _start_bomb_fx(blast, bomb_cursor)

func _begin_warp() -> void:
    aim_mode = CARD_WARP
    warp_cursor = player_pos
    message = ""

func _confirm_warp() -> void:
    var cost: int = _card_cost(CARD_WARP)
    if warp_cursor == player_pos:
        message = "別の帯電マスを選んでください。"
        return
    if not _is_floor(warp_cursor) or not charged.has(warp_cursor):
        message = "帯電マスを選んでください。"
        return
    if _enemy_index_at(warp_cursor) != -1:
        message = "敵がいるマスにはワープできません。"
        return
    if bat < cost:
        aim_mode = ""
        active_hand_slot = -1
        message = "BATが足りません。"
        return

    _spend_bat(cost)
    _play_sfx(SFX_CARD_WARP)
    var warp_origin: Vector2i = player_pos
    var warp_target: Vector2i = warp_cursor
    player_pos = warp_target
    var overload_damage: int = _apply_full_charge_movement_damage()
    _consume_active_card()
    aim_mode = ""
    message = "全面帯電：ワープ移動 HP -%d" % overload_damage if overload_damage > 0 else ""
    _start_warp_fx(warp_origin, warp_target)

func _begin_dash() -> void:
    aim_mode = CARD_DASH
    aim_dir = Vector2i.RIGHT
    dash_path_preview.clear()
    dash_branch_options.clear()
    dash_branch_origin = player_pos
    dash_route_customized = false
    message = "ラインダッシュ：方向キーで1マスずつ選択。直前のマスへ戻ると1マス取消。Zで発動 / Xでキャンセル。"

func _handle_dash_direction_input(d: Vector2i) -> void:
    # ver0.948: 方向キー1入力につき経路を1マス追加する。
    # 現在の終端から直前のマスへ戻る入力だけは「1手戻す」として最後の1マスを取り消す。
    var cur: Vector2i = player_pos
    if not dash_path_preview.is_empty():
        cur = dash_path_preview[dash_path_preview.size() - 1]

    var next: Vector2i = cur + d

    # 直前の経路マス（最初の1マスなら開始地点）へ戻った場合は、最後の1マスだけ取り消す。
    if not dash_path_preview.is_empty():
        var previous: Vector2i = player_pos
        if dash_path_preview.size() >= 2:
            previous = dash_path_preview[dash_path_preview.size() - 2]
        if next == previous:
            dash_path_preview.pop_back()
            dash_branch_origin = player_pos if dash_path_preview.is_empty() else dash_path_preview[dash_path_preview.size() - 1]
            dash_branch_options.clear()
            dash_route_customized = not dash_path_preview.is_empty()
            if dash_path_preview.is_empty():
                message = "ラインダッシュ：経路を開始地点まで戻しました。方向キーで1マス選択。"
            else:
                message = "ラインダッシュ：1マス戻しました。経路 %dマス。" % dash_path_preview.size()
            return

    if not _is_floor(next) or not charged.has(next):
        message = "その方向には帯電路がありません。"
        return
    if next == player_pos or dash_path_preview.has(next):
        message = "直前以外の選択済みマスには戻れません。"
        return

    dash_path_preview.append(next)
    dash_branch_origin = next
    dash_branch_options.clear()
    dash_route_customized = true
    aim_dir = d
    message = "ラインダッシュ：経路 %dマス。方向キーで1マス追加 / 直前へ戻って取消 / Zで発動。" % dash_path_preview.size()

func _confirm_dash() -> void:
    # 方向キーで1マスずつ積み上げた現在のプレビュー経路を、そのまま発動する。
    var path: Array[Vector2i] = []
    for p in dash_path_preview:
        path.append(p)
    if path.is_empty():
        message = "その方向には走れる帯電路がありません。"
        return

    var dash_origin: Vector2i = player_pos
    var cost: int = _card_cost(CARD_DASH)
    if bat < cost:
        aim_mode = ""
        active_hand_slot = -1
        message = "BATが足りません。"
        return

    _spend_bat(cost)
    _play_sfx(SFX_CARD_DASH)
    last_attack_cells.clear()
    for p in path:
        last_attack_cells.append(p)

    # 経路上の敵をすべて貫通攻撃する。敵の占有マスを何マス通過したかだけダメージが重なる。
    var hit_count: int = 0
    var total_damage: int = 0
    for i in range(enemies.size()):
        var covered_cells: int = _enemy_covered_cell_count(enemies[i], path)
        if covered_cells <= 0:
            continue
        var damage: int = GameBalance.DASH_DAMAGE_PER_CELL * covered_cells
        var hit_cells: Array[Vector2i] = _enemy_hit_cells_from_list(enemies[i], path)
        _damage_enemy(i, damage, hit_cells)
        hit_count += 1
        total_damage += damage
    if hit_count > 0:
        _play_sfx(SFX_ENEMY_HIT)
    _remove_dead_enemies()

    # 生き残った敵とは同じマスに止まれないので、経路の末尾から空きマスを探す。
    var destination: Vector2i = player_pos
    for i in range(path.size() - 1, -1, -1):
        if _enemy_index_at(path[i]) == -1:
            destination = path[i]
            break
    if destination != player_pos:
        var previous_pos: Vector2i = player_pos
        for dash_cell in path:
            if dash_cell == destination:
                player_facing = dash_cell - previous_pos
                break
            previous_pos = dash_cell
    player_pos = destination
    # ラインダッシュは経路上を実際に走ったマス数を歩数として記録する。
    step_count += path.size()
    # 全面帯電中も「1回の移動行動」として1ダメージだけ受ける。
    # 通過マス数ぶんの多重ダメージにはしない。
    var overload_damage: int = _apply_full_charge_movement_damage()

    _consume_active_card()
    aim_mode = ""
    dash_path_preview.clear()
    dash_branch_options.clear()
    dash_route_customized = false
    if hit_count > 0:
        message = "ラインダッシュ：%d体を貫通し、合計%dダメージ。" % [hit_count, total_damage]
    else:
        message = "ラインダッシュ：帯電路を%dマス走り抜けました。" % path.size()
    if overload_damage > 0:
        message += "  全面帯電：HP -%d" % overload_damage
    _start_dash_fx(dash_origin, path, destination)

func _begin_loop() -> void:
    aim_mode = CARD_LOOP
    loop_candidates = _loop_candidates()
    loop_candidate_index = 0
    if loop_candidates.size() > 1:
        message = "ループ候補 1 / %d" % loop_candidates.size()
    else:
        message = ""

func _cycle_loop_candidate(d: Vector2i) -> void:
    if loop_candidates.size() <= 1:
        return
    var step := 1
    if d == Vector2i.LEFT or d == Vector2i.UP:
        step = -1
    loop_candidate_index = posmod(loop_candidate_index + step, loop_candidates.size())
    message = "ループ候補 %d / %d" % [loop_candidate_index + 1, loop_candidates.size()]

func _selected_loop_candidate() -> Dictionary:
    if loop_candidates.is_empty():
        loop_candidates = _loop_candidates()
        loop_candidate_index = 0
    if loop_candidates.is_empty():
        return {}
    loop_candidate_index = clampi(loop_candidate_index, 0, loop_candidates.size() - 1)
    return loop_candidates[loop_candidate_index]

func _selected_loop_inside_cells() -> Array[Vector2i]:
    var candidate := _selected_loop_candidate()
    if candidate.is_empty():
        var empty: Array[Vector2i] = []
        return empty
    var out: Array[Vector2i] = candidate["inside"]
    return out

func _selected_loop_boundary_cells() -> Array[Vector2i]:
    var candidate := _selected_loop_candidate()
    if candidate.is_empty():
        var empty: Array[Vector2i] = []
        return empty
    var out: Array[Vector2i] = candidate["boundary"]
    return out

func _confirm_loop() -> void:
    var cost: int = _card_cost(CARD_LOOP)
    if bat < cost:
        aim_mode = ""
        active_hand_slot = -1
        loop_candidates.clear()
        loop_candidate_index = 0
        message = "ループ内爆破にはBATが%d必要です。" % cost
        return

    var inside: Array[Vector2i] = _selected_loop_inside_cells()
    var boundary: Array[Vector2i] = _selected_loop_boundary_cells()
    if inside.is_empty():
        message = "帯電した道で閉じたループがありません。"
        return

    _spend_bat(cost)
    _play_sfx(SFX_CARD_LOOP)
    last_attack_cells.clear()
    for p in inside:
        charged[p] = true

    # LOOPの攻撃判定は、閉領域の内側だけでなく輪を構成する帯電PATHにもある。
    var attack_cells: Array[Vector2i] = []
    var attack_set: Dictionary = {}
    for p in inside:
        if not attack_set.has(p):
            attack_set[p] = true
            attack_cells.append(p)
    for p in boundary:
        if not attack_set.has(p):
            attack_set[p] = true
            attack_cells.append(p)

    var hit_count: int = 0
    var total_damage: int = 0
    for i in range(enemies.size()):
        var covered_cells: int = _enemy_covered_cell_count(enemies[i], attack_cells)
        if covered_cells <= 0:
            continue
        var damage: int = GameBalance.LOOP_DAMAGE_PER_CELL * covered_cells
        var hit_cells: Array[Vector2i] = _enemy_hit_cells_from_list(enemies[i], attack_cells)
        _damage_enemy(i, damage, hit_cells)
        hit_count += 1
        total_damage += damage

    if hit_count > 0:
        _play_sfx(SFX_ENEMY_HIT)
    _remove_dead_enemies()
    _consume_active_card()
    aim_mode = ""
    active_hand_slot = -1
    loop_candidates.clear()
    loop_candidate_index = 0
    message = "ループ内爆破：%d体に合計%dダメージ。内側%dマスが帯電しました。" % [hit_count, total_damage, inside.size()]
    _start_loop_fx(boundary, inside)

func _loop_boundary_cells(inside: Array[Vector2i]) -> Array[Vector2i]:
    var path_region: Dictionary = _connected_charged_region(player_pos)
    if path_region.is_empty():
        var empty: Array[Vector2i] = []
        return empty
    var inside_set: Dictionary = {}
    for p in inside:
        inside_set[p] = true
    var boundary_set: Dictionary = {}
    # 輪の角も攻撃・演出対象に含めるため8近傍を見る。
    # 3x3の最小ループなら中心1マスを囲う8マスすべてがboundaryになる。
    var boundary_dirs: Array[Vector2i] = [
        Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
        Vector2i(-1, 0),                    Vector2i(1, 0),
        Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1),
    ]
    for p in inside:
        for d in boundary_dirs:
            var n: Vector2i = p + d
            if path_region.has(n) and not inside_set.has(n):
                boundary_set[n] = true
    var out: Array[Vector2i] = []
    for key in boundary_set.keys():
        out.append(Vector2i(key))
    return out

func _loop_interior_cells() -> Array[Vector2i]:
    # 選択中は現在候補を返す。通常時は先頭（プレイヤーに近い候補）を返す。
    if aim_mode == CARD_LOOP:
        return _selected_loop_inside_cells()
    var candidates: Array[Dictionary] = _loop_candidates()
    if candidates.is_empty():
        var empty: Array[Vector2i] = []
        return empty
    var out: Array[Vector2i] = candidates[0]["inside"]
    return out

func _loop_candidates() -> Array[Dictionary]:
    # LOOPは「現在プレイヤーと4方向でつながっている帯電PATH」だけを境界に使う。
    # 閉じ込められた領域を成分ごとに分け、複数あればプレイヤーが選択できる。
    var result: Array[Dictionary] = []
    var path_region: Dictionary = _connected_charged_region(player_pos)
    if path_region.is_empty():
        return result

    # 通常壁はLOOPの境界として数えない。外側探索は壁も通過し、
    # player-connectedな帯電PATHだけを越えられない境界として扱う。
    var outside: Dictionary = {}
    var open: Array[Vector2i] = []
    for x in range(GRID_W):
        _loop_seed_outside_for_region(Vector2i(x, 0), path_region, outside, open)
        _loop_seed_outside_for_region(Vector2i(x, GRID_H - 1), path_region, outside, open)
    for y in range(1, GRID_H - 1):
        _loop_seed_outside_for_region(Vector2i(0, y), path_region, outside, open)
        _loop_seed_outside_for_region(Vector2i(GRID_W - 1, y), path_region, outside, open)

    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    var read_index := 0
    while read_index < open.size():
        var cur: Vector2i = open[read_index]
        read_index += 1
        for d in dirs:
            var n: Vector2i = cur + d
            if not _in_bounds(n) or path_region.has(n) or outside.has(n):
                continue
            outside[n] = true
            open.append(n)

    var enclosed_seen: Dictionary = {}
    for y in range(GRID_H):
        for x in range(GRID_W):
            var seed := Vector2i(x, y)
            if path_region.has(seed) or outside.has(seed) or enclosed_seen.has(seed):
                continue

            var component_queue: Array[Vector2i] = [seed]
            var component_read := 0
            enclosed_seen[seed] = true
            var component_floor: Array[Vector2i] = []
            var component_distance := 999999
            var sort_anchor := Vector2i(999999, 999999)
            while component_read < component_queue.size():
                var cur_component: Vector2i = component_queue[component_read]
                component_read += 1
                if _is_floor(cur_component):
                    component_floor.append(cur_component)
                    component_distance = mini(component_distance, _manhattan(player_pos, cur_component))
                    if cur_component.y < sort_anchor.y or (cur_component.y == sort_anchor.y and cur_component.x < sort_anchor.x):
                        sort_anchor = cur_component
                for d in dirs:
                    var n_component: Vector2i = cur_component + d
                    if not _in_bounds(n_component):
                        continue
                    if path_region.has(n_component) or outside.has(n_component) or enclosed_seen.has(n_component):
                        continue
                    enclosed_seen[n_component] = true
                    component_queue.append(n_component)

            if component_floor.is_empty():
                continue

            var boundary: Array[Vector2i] = _loop_boundary_cells(component_floor)
            if boundary.is_empty():
                continue
            result.append({
                "inside": component_floor,
                "boundary": boundary,
                "distance": component_distance,
                "anchor": sort_anchor,
            })

    # 既存挙動との連続性のため、初期候補はプレイヤーに近い順。
    # 同距離なら盤面上→左の順で固定し、毎回候補順が揺れないようにする。
    for i in range(result.size()):
        var best := i
        for j in range(i + 1, result.size()):
            var a: Dictionary = result[j]
            var b: Dictionary = result[best]
            var ad: int = int(a["distance"])
            var bd: int = int(b["distance"])
            var aa: Vector2i = a["anchor"]
            var ba: Vector2i = b["anchor"]
            if ad < bd or (ad == bd and (aa.y < ba.y or (aa.y == ba.y and aa.x < ba.x))):
                best = j
        if best != i:
            var temp: Dictionary = result[i]
            result[i] = result[best]
            result[best] = temp
    return result

func _loop_seed_outside_for_region(p: Vector2i, path_region: Dictionary, outside: Dictionary, open: Array[Vector2i]) -> void:
    if path_region.has(p) or outside.has(p):
        return
    outside[p] = true
    open.append(p)

func _start_card_replace_animation(slot: int) -> void:
    if slot < 0 or slot >= hand.size():
        return

    card_replace_slot = slot
    card_replace_old_card = hand[slot]
    _replace_hand_slot(slot)
    card_replace_new_card = hand[slot]
    hand[slot] = card_replace_old_card
    card_replace_anim_active = true
    card_replace_anim_time = 0.0
    card_replace_committed = false

func _consume_active_card() -> void:
    if active_hand_slot >= 0:
        _start_card_replace_animation(active_hand_slot)
    active_hand_slot = -1

func _has_legal_player_action() -> bool:
    if game_over or run_clear or stage_clear:
        return false

    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for d in dirs:
        var target: Vector2i = player_pos + d
        if _is_floor(target) and _enemy_index_at(target) == -1:
            return true

    if bat >= REROLL_COST:
        return true

    for card_id in hand:
        if _card_has_legal_use(card_id):
            return true
    return false

func _card_has_legal_use(card_id: String) -> bool:
    if bat < _card_cost(card_id):
        return false

    if card_id == CARD_ARC:
        return _arc_has_effective_target()
    if card_id == CARD_SURGE:
        return _surge_has_effective_target()
    if card_id == CARD_BOMB:
        return _bomb_has_effective_target()
    if card_id == CARD_WARP:
        for key in charged.keys():
            var p: Vector2i = Vector2i(key)
            if _is_floor(p) and p != player_pos and _enemy_index_at(p) == -1:
                return true
        return false
    if card_id == CARD_DASH:
        var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
        for d in dirs:
            var first: Vector2i = player_pos + d
            if _is_floor(first) and charged.has(first):
                return true
        return false
    if card_id == CARD_LOOP:
        return not _loop_interior_cells().is_empty()
    return false

func _arc_has_effective_target() -> bool:
    # 直線伝導は、4方向のどこかで帯電PATH上の敵へ実際に届く時だけ
    # 自動待機を止める「使用可能スキル」とみなす。
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for d in dirs:
        for p in _arc_path(d):
            if _enemy_index_at(p) != -1:
                return true
    return false

func _surge_has_effective_target() -> bool:
    # 一斉放電は、現在接続している帯電領域に敵がいる時だけ有効。
    var region: Dictionary = _connected_charged_region(player_pos)
    if region.is_empty():
        return false
    for e in enemies:
        if _enemy_intersects_region(e, region):
            return true
    return false

func _bomb_has_effective_target() -> bool:
    # 爆弾は盤面上の任意の帯電マスを爆心にできる。敵へのダメージだけでなく、
    # 周囲の未帯電床を帯電させること自体もボードへ作用するため有効行動として数える。
    for key in charged.keys():
        var cursor: Vector2i = Vector2i(key)
        if not _is_floor(cursor):
            continue
        var blast: Array[Vector2i] = []
        var changes_floor: bool = false
        for oy in range(-1, 2):
            for ox in range(-1, 2):
                var p: Vector2i = cursor + Vector2i(ox, oy)
                if not _is_floor(p):
                    continue
                blast.append(p)
                if not charged.has(p):
                    changes_floor = true
        if changes_floor:
            return true
        for e in enemies:
            if _enemy_intersects_cells(e, blast):
                return true
    return false

func _schedule_auto_pass_if_needed() -> void:
    auto_pass_pending = false
    auto_pass_timer = 0.0
    if skill_fx != null and bool(skill_fx.active):
        return
    if game_over or run_clear or stage_clear or aim_mode != "":
        return
    if _has_legal_player_action():
        return
    auto_pass_pending = true
    auto_pass_timer = AUTO_PASS_DELAY
    message = "行動不能：自動待機します。"

func _analytics_run_payload() -> Dictionary:
    return {
        "floor": current_floor,
    }

func _analytics_floor_metrics() -> Dictionary:
    return {
        "floor_time_seconds": snappedf(maxf(0.0, run_elapsed_seconds - floor_start_run_time_seconds), 0.001),
        "floor_turns": maxi(0, turn - floor_start_turn),
        "floor_damage_taken": maxi(0, damage_taken - floor_start_damage_taken),
        "hits_taken": maxi(0, floor_hits_taken),
        "hp_remaining": hp,
    }

func _merge_analytics_payload(base: Dictionary, extra: Dictionary) -> Dictionary:
    var payload := base.duplicate(true)
    for key in extra.keys():
        payload[key] = extra[key]
    return payload

func _track_run_event(event_name: String, extra: Dictionary = {}) -> void:
    if web_analytics != null:
        web_analytics.track(event_name, _merge_analytics_payload(_analytics_run_payload(), extra))

func _track_floor_event(event_name: String, extra: Dictionary = {}) -> void:
    var payload := _merge_analytics_payload(_analytics_run_payload(), _analytics_floor_metrics())
    payload = _merge_analytics_payload(payload, extra)
    if web_analytics != null:
        web_analytics.track(event_name, payload)

func _reset_floor_analytics_baseline() -> void:
    floor_start_run_time_seconds = run_elapsed_seconds
    floor_start_turn = turn
    floor_start_damage_taken = damage_taken
    floor_hits_taken = 0

func _track_floor_start_event() -> void:
    _track_run_event("floor_start")

func _gain_bat(amount: int) -> int:
    if amount <= 0:
        return 0
    var before := bat
    bat = min(MAX_BAT, bat + amount)
    return maxi(0, bat - before)

func _spend_bat(amount: int) -> int:
    if amount <= 0:
        return 0
    var before := bat
    bat = max(0, bat - amount)
    return maxi(0, before - bat)

func _track_damage_taken_event(amount: int, source: String, enemy_type: String) -> void:
    var payload := {
        "source": source,
        "amount": amount,
        "hp_after": hp,
    }
    if enemy_type != "":
        payload["enemy_type"] = enemy_type
    _track_run_event("damage_taken", payload)

func _track_game_over_event() -> void:
    var cause := game_over_reason
    if cause == "":
        cause = "contact"
    var extra := {"cause": cause}
    if last_player_damage_enemy_type != "":
        extra["enemy_type"] = last_player_damage_enemy_type
    _track_floor_event("game_over", extra)

func _finish_player_turn() -> void:
    turn += 1

    # 未帯電床を使い切っても即GAME OVERにはしない。
    # 全面帯電中は盤面が危険状態になり、プレイヤー主導の移動ごとにHPを失う。
    _refresh_full_charge_hazard_state()

    # 全面帯電の移動ダメージでHPが0になった場合は、敵ターンへ進めず停止する。
    if hp <= 0:
        hp = 0
        game_over = true
        game_over_reason = last_player_damage_source if last_player_damage_source != "" else "contact"
        auto_pass_pending = false
        auto_pass_timer = 0.0
        aim_mode = ""
        active_hand_slot = -1
        _play_sfx(SFX_GAME_OVER_HP)
        _track_game_over_event()
        message = ""
        return

    if _boss_all_legs_destroyed():
        aim_mode = ""
        active_hand_slot = -1
        run_clear = true
        auto_pass_pending = false
        auto_pass_timer = 0.0
        _play_sfx(SFX_GAME_CLEAR)
        _track_floor_event("game_clear")
        message = "四本の脚をすべて破壊しました。"
        return

    if enemies.is_empty():
        aim_mode = ""
        active_hand_slot = -1
        if current_floor >= TOTAL_FLOORS:
            run_clear = true
            auto_pass_pending = false
            auto_pass_timer = 0.0
            _play_sfx(SFX_GAME_CLEAR)
            _track_floor_event("game_clear")
            message = "全10ステージをクリアしました。"
        else:
            stage_clear = true
            stage_clear_timer = 3.0
            auto_pass_pending = false
            auto_pass_timer = 0.0
            _play_sfx(SFX_STAGE_CLEAR)
            _track_floor_event("floor_clear")
            message = "敵を全滅しました。次のステージへ進みます。"
        return
    _enemy_turn()
    # 敵ターン後も全面帯電状態を同期する。ボス踏みつけは帯電を解除しない。
    _refresh_full_charge_hazard_state()
    if hp <= 0:
        hp = 0
        game_over = true
        game_over_reason = last_player_damage_source if last_player_damage_source != "" else "contact"
        auto_pass_pending = false
        auto_pass_timer = 0.0
        _play_sfx(SFX_GAME_OVER_HP)
        _track_game_over_event()
        message = ""
        return

    _schedule_auto_pass_if_needed()

func _enemy_turn() -> void:
    if current_floor == TOTAL_FLOORS:
        _boss_take_turn()
        return
    if enemy_system != null:
        enemy_system.take_turn(self)

func _heavy_cells(top_left: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.heavy_cells(top_left)

func _heavy_can_occupy(top_left: Vector2i, occupied: Dictionary) -> bool:
    return enemy_geometry.heavy_can_occupy(top_left, occupied)

func _heavy_distance_to_player(top_left: Vector2i) -> int:
    return enemy_geometry.heavy_distance_to_player(top_left)

func _heavy_next_step(top_left: Vector2i, occupied: Dictionary) -> Vector2i:
    return enemy_geometry.heavy_next_step(top_left, occupied)

func _tank_cells(top_left: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.tank_cells(top_left)

func _tank_can_occupy(top_left: Vector2i, occupied: Dictionary) -> bool:
    return enemy_geometry.tank_can_occupy(top_left, occupied)

func _tank_distance_to_player(top_left: Vector2i) -> int:
    return enemy_geometry.tank_distance_to_player(top_left)

func _tank_next_step(top_left: Vector2i, occupied: Dictionary) -> Vector2i:
    return enemy_geometry.tank_next_step(top_left, occupied)

func _tank_aim_dir(top_left: Vector2i, target: Vector2i) -> Vector2i:
    return enemy_geometry.tank_aim_dir(top_left, target)

func _tank_beam_cells(top_left: Vector2i, d: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.tank_beam_cells(top_left, d)

func _cross_cells(center: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.cross_cells(center)

func _cross_can_occupy(center: Vector2i, occupied: Dictionary) -> bool:
    return enemy_geometry.cross_can_occupy(center, occupied)

func _cross_next_step(center: Vector2i, occupied: Dictionary) -> Vector2i:
    return enemy_geometry.cross_next_step(center, occupied)

func _cross_ray_cells(center: Vector2i, d: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.cross_ray_cells(center, d)

func _artillery_cells(left_cell: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.artillery_cells(left_cell)

func _artillery_can_occupy(left_cell: Vector2i, occupied: Dictionary) -> bool:
    return enemy_geometry.artillery_can_occupy(left_cell, occupied)

func _artillery_has_horizontal_target(left_cell: Vector2i, target: Vector2i) -> bool:
    return enemy_geometry.artillery_has_horizontal_target(left_cell, target)

func _artillery_ray_cells(left_cell: Vector2i, d: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.artillery_ray_cells(left_cell, d)

func _charger_axis_dir(start: Vector2i, target: Vector2i) -> Vector2i:
    return enemy_geometry.charger_axis_dir(start, target)

func _charger_preview_cells(start: Vector2i, d: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.charger_preview_cells(start, d)

func _turret_axis_dir(start: Vector2i, target: Vector2i) -> Vector2i:
    return enemy_geometry.turret_axis_dir(start, target)

func _turret_ray_cells(start: Vector2i, d: Vector2i) -> Array[Vector2i]:
    return enemy_geometry.turret_ray_cells(start, d)

func _apply_player_damage(amount: int, source: String = "contact", enemy_type: String = "") -> void:
    if amount <= 0 or hp <= 0:
        return
    var actual_damage: int = min(amount, hp)
    hp = max(0, hp - amount)
    damage_taken += actual_damage
    if actual_damage > 0:
        floor_hits_taken += 1
        last_player_damage_source = source
        last_player_damage_enemy_type = enemy_type
        _track_damage_taken_event(actual_damage, source, enemy_type)
        _play_sfx(SFX_PLAYER_HURT)
        _start_damage_feedback(actual_damage)
        message = "HP -%d" % actual_damage

func _start_damage_feedback(amount: int) -> void:
    # 被弾演出はpresentationだけを担当し、ターン進行や入力を止めない。
    # 連続被弾では最新hitで時間を戻し、強さだけ少し加算する。
    var hit_strength: float = clampf(0.9 + float(maxi(1, amount)) * 0.1, 1.0, 1.5)
    if damage_fx_time_left > 0.0:
        damage_fx_intensity = minf(1.5, maxf(damage_fx_intensity, hit_strength) + 0.18)
    else:
        damage_fx_intensity = hit_strength
    damage_fx_time_left = DAMAGE_FEEDBACK_DURATION
    damage_fx_sequence += 1
    queue_redraw()

func _damage_feedback_envelope() -> float:
    if damage_fx_time_left <= 0.0 or DAMAGE_FEEDBACK_DURATION <= 0.0:
        return 0.0
    var remaining_ratio: float = clampf(damage_fx_time_left / DAMAGE_FEEDBACK_DURATION, 0.0, 1.0)
    # 最初の衝撃を強くし、その後すばやく復帰する。
    return remaining_ratio * remaining_ratio

func _boss_shake_offset() -> Vector2:
    if spider_boss == null:
        return Vector2.ZERO
    return spider_boss.shake_offset()

func _draw_boss_action_fx() -> void:
    if spider_boss.stomp_fx_time > 0.0 and not spider_boss.stomp_fx_cells.is_empty():
        var progress: float = 1.0 - clampf(spider_boss.stomp_fx_time / SpiderBoss.STOMP_FX_DURATION, 0.0, 1.0)
        var fade: float = (1.0 - progress) * (1.0 - progress)
        for cell in spider_boss.stomp_fx_cells:
            if not _is_floor(cell):
                continue
            var r: Rect2 = _cell_rect(cell).grow(-3.0)
            # 踏みつけ範囲だけを短い白い衝撃光で示す。床の帯電状態は変化させない。
            draw_rect(r, Color(1.0, 1.0, 1.0, 0.20 * fade))
            if progress < 0.18:
                draw_rect(r.grow(-4.0), Color(1.0, 1.0, 1.0, 0.58 * (1.0 - progress / 0.18)))
        var top_left: Vector2 = _cell_rect(spider_boss.stomp_fx_origin).position
        var bottom_right: Vector2 = _cell_rect(spider_boss.stomp_fx_origin + Vector2i(2, 2)).end
        var shock_rect := Rect2(top_left, bottom_right - top_left).grow(2.0 + progress * 12.0)
        draw_rect(shock_rect, Color(0.92, 0.99, 1.0, 0.85 * fade), false, 3.0)

    if spider_boss.break_fx_time > 0.0:
        var progress: float = 1.0 - clampf(spider_boss.break_fx_time / SpiderBoss.BREAK_FX_DURATION, 0.0, 1.0)
        var fade: float = (1.0 - progress) * (1.0 - progress)
        var radius: float = 18.0 + progress * 58.0
        draw_arc(spider_boss.break_fx_center, radius, 0.0, TAU, 36, Color(1.0, 0.68, 0.42, 0.88 * fade), 4.0, true)
        draw_arc(spider_boss.break_fx_center, radius * 0.65, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.72 * fade), 2.0, true)
        for i in range(8):
            var a: float = float(i) * TAU / 8.0 + progress * 0.24
            var d := Vector2(cos(a), sin(a))
            draw_line(spider_boss.break_fx_center + d * 10.0, spider_boss.break_fx_center + d * (20.0 + 34.0 * progress), Color(1.0, 0.82, 0.62, 0.75 * fade), 3.0)
        if spider_boss.break_destroyed_count > 0:
            var label := "LEG DESTROYED  %d / 4" % spider_boss.break_destroyed_count
            var font: Font = ui_font
            var size: int = 26
            var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
            var plate := Rect2(Vector2(GRID_ORIGIN.x + GRID_W * CELL * 0.5 - text_size.x * 0.5 - 18.0, 485.0), Vector2(text_size.x + 36.0, 44.0))
            draw_rect(plate, Color(0.04, 0.07, 0.10, 0.92 * fade))
            draw_rect(plate, Color(1.0, 0.72, 0.50, 0.82 * fade), false, 2.0)
            draw_string(font, plate.position + Vector2(18.0, 31.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.96, 0.92, fade))

func _damage_feedback_shake_offset() -> Vector2:
    var envelope: float = _damage_feedback_envelope()
    if envelope <= 0.0:
        return Vector2.ZERO
    var progress: float = 1.0 - clampf(damage_fx_time_left / DAMAGE_FEEDBACK_DURATION, 0.0, 1.0)
    var phase: float = progress * 42.0 + float(damage_fx_sequence) * 1.37
    var amplitude: float = DAMAGE_SHAKE_PIXELS * damage_fx_intensity * envelope
    return Vector2(sin(phase) * amplitude, cos(phase * 1.31) * amplitude * 0.65)

func _draw_damage_hud_flash() -> void:
    var envelope: float = _damage_feedback_envelope()
    if envelope <= 0.0:
        return
    var alpha: float = clampf(DAMAGE_HUD_FLASH_ALPHA * envelope * damage_fx_intensity, 0.0, 0.58)
    var fill := Color(1.0, 0.05, 0.08, alpha)
    var edge := Color(1.0, 0.16, 0.20, minf(0.95, alpha + 0.30))

    var left_panel := Rect2(Vector2(14, 14), Vector2(232, 692))
    var right_panel := Rect2(Vector2(1058, 14), Vector2(208, 692))
    var message_box := Rect2(Vector2(323, 532), Vector2(674, 96))
    for panel in [left_panel, right_panel, message_box]:
        draw_rect(panel, fill)
        draw_rect(panel.grow(-2.0), edge, false, 2.0)

func _draw_damage_frame() -> void:
    var envelope: float = _damage_feedback_envelope()
    if envelope <= 0.0:
        return
    var alpha: float = clampf((0.48 + 0.30 * envelope) * damage_fx_intensity, 0.0, 0.92)
    var outer := Rect2(Vector2(5, 5), WINDOW_SIZE - Vector2(10, 10))
    var inner := Rect2(Vector2(13, 13), WINDOW_SIZE - Vector2(26, 26))
    draw_rect(outer, Color(1.0, 0.03, 0.05, alpha), false, DAMAGE_FRAME_THICKNESS, true)
    draw_rect(inner, Color(1.0, 0.22, 0.24, alpha * 0.36), false, 2.0, true)

func _format_clear_time(seconds: float) -> String:
    var total_seconds: int = max(0, int(floor(seconds)))
    var minutes: int = int(total_seconds / 60)
    var secs: int = total_seconds % 60
    return "%02d:%02d" % [minutes, secs]

func _next_step_toward(start: Vector2i, goal: Vector2i, occupied: Dictionary) -> Vector2i:
    return enemy_geometry.next_step_toward(start, goal, occupied)

func _enemy_covered_cell_count(enemy: Dictionary, cells: Array[Vector2i]) -> int:
    if cells.is_empty():
        return 0
    var cell_set: Dictionary = {}
    for p in cells:
        cell_set[p] = true
    var count := 0
    for enemy_cell in _enemy_cells(enemy):
        if cell_set.has(enemy_cell):
            count += 1
    return count

func _enemy_covered_region_count(enemy: Dictionary, region: Dictionary) -> int:
    if region.is_empty():
        return 0
    var count := 0
    for enemy_cell in _enemy_cells(enemy):
        if region.has(enemy_cell):
            count += 1
    return count

func _enemy_hit_cells_from_list(enemy: Dictionary, attack_cells: Array[Vector2i]) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if attack_cells.is_empty():
        return result
    var attack_set: Dictionary = {}
    for p in attack_cells:
        attack_set[p] = true
    for enemy_cell in _enemy_cells(enemy):
        if attack_set.has(enemy_cell):
            result.append(enemy_cell)
    return result

func _enemy_hit_cells_from_region(enemy: Dictionary, region: Dictionary) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if region.is_empty():
        return result
    for enemy_cell in _enemy_cells(enemy):
        if region.has(enemy_cell):
            result.append(enemy_cell)
    return result

func _enemy_hit_tier(amount: int) -> int:
    if amount >= 6:
        return 3
    if amount >= 3:
        return 2
    return 1

func _damage_enemy(index: int, amount: int, impacted_cells: Array[Vector2i] = []) -> void:
    if index < 0 or index >= enemies.size() or amount <= 0:
        return
    var enemy_before: Dictionary = enemies[index]
    var hit_cells: Array[Vector2i] = []
    if impacted_cells.is_empty():
        # 明示されない古い呼び出しだけは敵全体を被弾セルとして扱う。
        for p in _enemy_cells(enemy_before):
            hit_cells.append(p)
    else:
        for p in impacted_cells:
            hit_cells.append(p)
    var bounds: Rect2 = _enemy_bounds_rect(enemy_before)
    var hit_center: Vector2 = bounds.get_center() if bounds.size != Vector2.ZERO else _cell_center(Vector2i(enemy_before["pos"]))
    var tier: int = _enemy_hit_tier(amount)
    var reaction_duration: float = 0.14 if tier == 1 else (0.18 if tier == 2 else 0.22)
    var local_strength: float = 0.82 if tier == 1 else (1.18 if tier == 2 else 1.55)

    enemies[index]["hp"] = int(enemies[index]["hp"]) - amount
    enemies[index]["hit_fx_time"] = reaction_duration
    enemies[index]["hit_fx_duration"] = reaction_duration
    enemies[index]["hit_fx_sequence"] = int(enemies[index].get("hit_fx_sequence", 0)) + 1
    enemies[index]["hit_fx_strength"] = local_strength
    enemy_hit_flashes.append({
        "cells": hit_cells,
        "time": reaction_duration,
        "duration": reaction_duration,
        "tier": tier,
        "sequence": int(enemies[index].get("hit_fx_sequence", 0)),
    })
    enemy_damage_numbers.append({
        "center": hit_center,
        "amount": amount,
        "tier": tier,
        "time": ENEMY_DAMAGE_NUMBER_DURATION,
        "duration": ENEMY_DAMAGE_NUMBER_DURATION,
    })

    # 中ダメージ以上は盤面全体にも短い衝撃を返す。6DMG以上だけ0.06秒停止する。
    if tier >= 2:
        enemy_impact_shake_time = ENEMY_IMPACT_SHAKE_DURATION
        enemy_impact_shake_strength = maxf(enemy_impact_shake_strength, 0.55 if tier == 2 else 1.0)
        enemy_impact_shake_sequence += 1
    if tier >= 3:
        enemy_impact_freeze_time = maxf(enemy_impact_freeze_time, ENEMY_IMPACT_FREEZE_DURATION)

    # 通常敵は直後に配列から消えるため、撃破位置を独立した短命FXへ退避する。
    # ボス脚は既存の専用破壊演出を使うので重ねない。
    if int(enemies[index]["hp"]) <= 0 and str(enemy_before.get("type", "")) != "boss_leg":
        enemy_destroy_fx.append({
            "cells": hit_cells,
            "center": hit_center,
            "time": ENEMY_DESTROY_FX_DURATION,
            "duration": ENEMY_DESTROY_FX_DURATION,
            "sequence": int(enemies[index].get("hit_fx_sequence", 0)),
        })

func _process_enemy_hit_reactions(delta: float) -> bool:
    var active := false
    for i in range(enemies.size()):
        var time_left: float = float(enemies[i].get("hit_fx_time", 0.0))
        if time_left <= 0.0:
            continue
        time_left = maxf(0.0, time_left - delta)
        enemies[i]["hit_fx_time"] = time_left
        if time_left > 0.0:
            active = true

    for i in range(enemy_hit_flashes.size() - 1, -1, -1):
        var flash_time: float = float(enemy_hit_flashes[i].get("time", 0.0))
        flash_time = maxf(0.0, flash_time - delta)
        if flash_time <= 0.0:
            enemy_hit_flashes.remove_at(i)
        else:
            enemy_hit_flashes[i]["time"] = flash_time
            active = true

    for i in range(enemy_damage_numbers.size() - 1, -1, -1):
        var number_time: float = float(enemy_damage_numbers[i].get("time", 0.0))
        number_time = maxf(0.0, number_time - delta)
        if number_time <= 0.0:
            enemy_damage_numbers.remove_at(i)
        else:
            enemy_damage_numbers[i]["time"] = number_time
            active = true

    for i in range(enemy_destroy_fx.size() - 1, -1, -1):
        var destroy_time: float = float(enemy_destroy_fx[i].get("time", 0.0))
        destroy_time = maxf(0.0, destroy_time - delta)
        if destroy_time <= 0.0:
            enemy_destroy_fx.remove_at(i)
        else:
            enemy_destroy_fx[i]["time"] = destroy_time
            active = true
    return active

func _enemy_hit_reaction_offset(enemy: Dictionary) -> Vector2:
    var time_left: float = float(enemy.get("hit_fx_time", 0.0))
    if time_left <= 0.0:
        return Vector2.ZERO
    var duration: float = maxf(0.001, float(enemy.get("hit_fx_duration", ENEMY_HIT_REACTION_DURATION)))
    var envelope: float = clampf(time_left / duration, 0.0, 1.0)
    var strength: float = float(enemy.get("hit_fx_strength", 1.0))
    var seq: float = float(int(enemy.get("hit_fx_sequence", 0)))
    var progress: float = 1.0 - envelope
    var phase: float = progress * 34.0 + seq * 1.73
    var amplitude: float = ENEMY_HIT_SHAKE_PIXELS * strength * envelope
    return Vector2(sin(phase), cos(phase * 1.31)) * amplitude

func _enemy_impact_shake_offset() -> Vector2:
    if enemy_impact_freeze_time > 0.0:
        return Vector2.ZERO
    if enemy_impact_shake_time <= 0.0 or ENEMY_IMPACT_SHAKE_DURATION <= 0.0:
        return Vector2.ZERO
    var remain: float = clampf(enemy_impact_shake_time / ENEMY_IMPACT_SHAKE_DURATION, 0.0, 1.0)
    var progress: float = 1.0 - remain
    var phase: float = progress * 38.0 + float(enemy_impact_shake_sequence) * 1.47
    var amplitude: float = 4.0 * enemy_impact_shake_strength * remain * remain
    return Vector2(sin(phase) * amplitude, cos(phase * 1.29) * amplitude * 0.62)

func _enemy_bounds_rect(enemy: Dictionary) -> Rect2:
    return enemy_geometry.enemy_bounds_rect(enemy)

func _remove_dead_enemies() -> void:
    var removed_count := 0
    var boss_removed_count := 0
    for i in range(enemies.size() - 1, -1, -1):
        if int(enemies[i]["hp"]) > 0:
            continue
        if str(enemies[i].get("type", "")) == "boss_leg":
            if spider_boss != null and bool(spider_boss.mark_leg_destroyed(enemies, i, Callable(self, "_cell_center"))):
                boss_removed_count += 1
            continue
        enemies.remove_at(i)
        removed_count += 1
    if boss_removed_count > 0:
        _play_sfx(SFX_BOSS_LEG_BREAK)
    elif removed_count > 0:
        _play_sfx(SFX_ENEMY_DESTROY)

func _enemy_cells(enemy: Dictionary) -> Array[Vector2i]:
    return enemy_geometry.enemy_cells(enemy)

func _enemy_intersects_cells(enemy: Dictionary, cells: Array[Vector2i]) -> bool:
    return enemy_geometry.enemy_intersects_cells(enemy, cells)

func _enemy_intersects_region(enemy: Dictionary, region: Dictionary) -> bool:
    return enemy_geometry.enemy_intersects_region(enemy, region)

func _enemy_index_at(p: Vector2i) -> int:
    return enemy_geometry.enemy_index_at(p)

func _is_floor(p: Vector2i) -> bool:
    return _in_bounds(p) and not walls.has(p)

func _in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < GRID_W and p.y < GRID_H

func _manhattan(a: Vector2i, b: Vector2i) -> int:
    return abs(a.x - b.x) + abs(a.y - b.y)

func _cell_rect(p: Vector2i) -> Rect2:
    return Rect2(GRID_ORIGIN + Vector2(p.x * CELL, p.y * CELL), Vector2(CELL - 2, CELL - 2))

func _cell_center(p: Vector2i) -> Vector2:
    return GRID_ORIGIN + Vector2(p.x * CELL + (CELL - 2) * 0.5, p.y * CELL + (CELL - 2) * 0.5)

func _floor_count() -> int:
    # Every in-bounds cell is either floor or present in walls, so no grid scan is needed.
    return maxi(0, GRID_W * GRID_H - walls.size())

func _uncharged_count() -> int:
    return maxi(0, _floor_count() - charged.size())

func _uncharged_ratio() -> float:
    var total: int = _floor_count()
    if total <= 0:
        return 0.0
    var uncharged: int = maxi(0, total - charged.size())
    return clampf(float(uncharged) / float(total), 0.0, 1.0)

func _refresh_full_charge_hazard_state() -> void:
    var should_be_active: bool = _floor_count() > 0 and _uncharged_count() <= 0
    if full_charge_hazard_active == should_be_active:
        return
    full_charge_hazard_active = should_be_active
    if full_charge_hazard_active:
        message = "全面帯電：移動するたびHP -%d" % FULL_CHARGE_MOVE_DAMAGE
    queue_redraw()

func _apply_full_charge_movement_damage() -> int:
    # 移動によって最後の未帯電床を踏んだ場合も、その移動から危険状態へ入る。
    _refresh_full_charge_hazard_state()
    if not full_charge_hazard_active or hp <= 0:
        return 0
    var before_hp: int = hp
    _apply_player_damage(FULL_CHARGE_MOVE_DAMAGE, "overcharge")
    var actual_damage: int = maxi(0, before_hp - hp)
    # 全面帯電はプレイヤー被弾を引き金に盤面全体が放電する。
    # 通常敵だけを1ダメージずつ巻き込み、FLOOR 10のボス脚は攻略を崩さないため対象外。
    if actual_damage > 0:
        _apply_full_charge_enemy_discharge()
    return actual_damage

func _apply_full_charge_enemy_discharge() -> int:
    var hit_count: int = 0
    for i in range(enemies.size()):
        if int(enemies[i].get("hp", 0)) <= 0:
            continue
        if str(enemies[i].get("type", "")) == "boss_leg":
            continue
        _damage_enemy(i, FULL_CHARGE_ENEMY_DAMAGE)
        hit_count += 1
    if hit_count > 0:
        _play_sfx(SFX_ENEMY_HIT)
        _remove_dead_enemies()
    return hit_count

func _full_charge_flash_fill_color() -> Color:
    var phase: int = int(floor(float(Time.get_ticks_msec()) / (FULL_CHARGE_FLASH_INTERVAL * 1000.0))) % 2
    return C_FULL_CHARGE_RED if phase == 0 else C_FULL_CHARGE_BLUE

func _full_charge_flash_edge_color() -> Color:
    var phase: int = int(floor(float(Time.get_ticks_msec()) / (FULL_CHARGE_FLASH_INTERVAL * 1000.0))) % 2
    return C_FULL_CHARGE_EDGE_RED if phase == 0 else C_FULL_CHARGE_EDGE_BLUE

func _enemy_telegraph_is_imminent(e: Dictionary) -> bool:
    if not bool(e.get("telegraph_active", false)):
        return false
    if str(e.get("type", "chaser")) == "tank":
        return int(e.get("telegraph_turns", 0)) <= 1
    return true

func _telegraph_flash_edge_color() -> Color:
    var phase: int = int(floor(float(Time.get_ticks_msec()) / (TELEGRAPH_FLASH_INTERVAL * 1000.0))) % 2
    return C_TELEGRAPH_FLASH_WHITE if phase == 0 else C_TELEGRAPH_FLASH_RED

func _critical_text_color() -> Color:
    # 暗いHUD上の危険数字・警告文は、元の赤より明るい赤に統一する。
    return C_HP.lerp(Color.WHITE, 0.42)

func _player_pulse_color() -> Color:
    var t: float = float(Time.get_ticks_msec()) / 1000.0
    var pulse01: float = (sin(t * TAU / PLAYER_PULSE_INTERVAL) + 1.0) * 0.5
    var dark_color: Color = C_PLAYER.darkened(0.22)
    var bright_color: Color = C_PLAYER.lightened(0.28)
    return dark_color.lerp(bright_color, pulse01)

func _draw() -> void:
    # 背景と赤い外周フレームは画面座標へ固定し、ゲーム本体/HUDだけを短く揺らす。
    draw_rect(Rect2(Vector2.ZERO, WINDOW_SIZE), C_BG)
    if title_screen_active:
        _draw_title_screen()
        return

    draw_set_transform(_damage_feedback_shake_offset() + _boss_shake_offset() + _enemy_impact_shake_offset())

    hud_renderer.draw_side_panels()
    board_renderer.draw_board()
    board_renderer.draw_telegraphs()
    board_renderer.draw_last_attack_cells()

    _draw_boss_action_fx()
    _draw_skill_fx()

    board_renderer.draw_aim_overlay()
    board_renderer.draw_enemies()
    board_renderer.draw_enemy_hit_flashes()
    board_renderer.draw_player()
    board_renderer.draw_enemy_hp_labels()

    hud_renderer.draw_hud()
    _draw_damage_hud_flash()

    # 外周フレームは揺らさず、被弾した瞬間の画面境界として残す。
    draw_set_transform(Vector2.ZERO)
    _draw_damage_frame()
    hud_renderer.draw_restart_confirm()

