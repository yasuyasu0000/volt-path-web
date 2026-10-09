extends RefCounted

const CardCatalog = preload("res://systems/card_catalog.gd")

const CARD_ARC := CardCatalog.ARC
const CARD_SURGE := CardCatalog.SURGE
const CARD_BOMB := CardCatalog.BOMB
const CARD_WARP := CardCatalog.WARP
const CARD_DASH := CardCatalog.DASH
const CARD_LOOP := CardCatalog.LOOP

# VOLT PATH HUD renderer.
# This helper draws onto the main Node2D only while main.gd is inside _draw().
# It owns no Node and runs no _process(), keeping the prototype lightweight.

var h = null

func setup(host) -> void:
    h = host

func draw_side_panels() -> void:
    if h == null:
        return
    _draw_side_panels()

func draw_hud() -> void:
    if h == null:
        return
    _draw_hud()

func draw_restart_confirm() -> void:
    if h == null or not h.restart_confirm_active:
        return
    _draw_restart_confirm()

func _draw_side_panels() -> void:
    # 左=カード、中央=盤面、右=必要な状態だけ。見出しやタイトルは置かない。
    var left_panel := Rect2(Vector2(14, 14), Vector2(232, 692))
    var right_panel := Rect2(Vector2(1058, 14), Vector2(208, 692))
    h.draw_rect(left_panel, h.C_PANEL)
    h.draw_rect(left_panel, h.C_FLOOR_EDGE, false, 1.0)
    h.draw_rect(right_panel, h.C_PANEL)
    h.draw_rect(right_panel, h.C_FLOOR_EDGE, false, 1.0)

    # 上部タイトルを廃止した分、盤面を40px上へ広げる。
    var stage_frame := Rect2(Vector2(323, 36), Vector2(674, 444))
    h.draw_rect(stage_frame, Color("#0d151d"))
    h.draw_rect(stage_frame, h.C_FLOOR_EDGE, false, 1.0)

func _draw_hud() -> void:
    var font := ThemeDB.fallback_font

    # 見出しを置かず、カードそのものを上から見せる。
    for i in range(h.hand.size()):
        _draw_card_panel_animated(i, Rect2(Vector2(28, 28 + i * 148), Vector2(204, 132)))

    h.draw_line(Vector2(28, 477), Vector2(232, 477), h.C_FLOOR_EDGE, 1.0)
    _draw_reroll_panel(Rect2(Vector2(28, 496), Vector2(204, 78)))

    # 右HUDも見出し「状態」を廃止し、数値と資源を上から直接並べる。
    h.draw_string(font, Vector2(1074, 51), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, h.C_DIM)
    _draw_hp_icons(Vector2(1074, 76))
    # 正確な値は色分けせず、暗い専用プレート上の白文字で読む。
    var hp_value_plate := Rect2(Vector2(1070, 92), Vector2(174, 36))
    h.draw_rect(hp_value_plate, h.C_HUD_VALUE_BG)
    h.draw_rect(hp_value_plate, h.C_FLOOR_EDGE, false, 1.0)
    var hp_pulse: float = h._damage_feedback_envelope()
    var hp_font_size: int = 26 + int(round(3.0 * hp_pulse))
    h.draw_string(font, Vector2(1080, 120), "%d / %d" % [h.hp, h.MAX_HP], HORIZONTAL_ALIGNMENT_LEFT, -1, hp_font_size, h.C_HUD_VALUE)

    h.draw_string(font, Vector2(1074, 163), "BAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, h.C_DIM)
    _draw_bat_icons(Vector2(1074, 185))
    var bat_value_plate := Rect2(Vector2(1070, 226), Vector2(174, 36))
    h.draw_rect(bat_value_plate, h.C_HUD_VALUE_BG)
    h.draw_rect(bat_value_plate, h.C_FLOOR_EDGE, false, 1.0)
    h.draw_string(font, Vector2(1080, 254), "%d / %d" % [h.bat, h.MAX_BAT], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, h.C_HUD_VALUE)

    h.draw_string(font, Vector2(1074, 310), "FLOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, h.C_DIM)
    h.draw_string(font, Vector2(1074, 342), "%02d / %02d" % [h.current_floor, h.TOTAL_FLOORS], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, h.C_TEXT)

    var uncharged: int = h._uncharged_count()
    var floor_total: int = h._floor_count()
    var remain_ratio: float = h._uncharged_ratio()
    # 正確な残数は他の主要数値と同じく常に白で読む。
    # 危険度はバーと警告文だけで色分けする。
    var remain_bar_color: Color = h.C_CHARGED_INNER
    if remain_ratio <= 0.10:
        remain_bar_color = h._critical_text_color()
    elif remain_ratio <= 0.25:
        remain_bar_color = h.C_WARNING

    h.draw_string(font, Vector2(1074, 392), "未帯電", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, h.C_DIM)
    h.draw_string(font, Vector2(1074, 420), "%d / %d" % [uncharged, floor_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, h.C_HUD_VALUE)
    var remain_bar := Rect2(Vector2(1074, 436), Vector2(170, 12))
    h.draw_rect(remain_bar, h.C_RESOURCE_EMPTY)
    if remain_ratio > 0.0:
        h.draw_rect(Rect2(remain_bar.position, Vector2(remain_bar.size.x * remain_ratio, remain_bar.size.y)), remain_bar_color)
    h.draw_rect(remain_bar, h.C_FLOOR_EDGE, false, 1.0)
    if remain_ratio <= 0.10:
        h.draw_string(font, Vector2(1074, 474), "残りわずか", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, h._critical_text_color())
    elif remain_ratio <= 0.25:
        h.draw_string(font, Vector2(1074, 474), "注意", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, h.C_WARNING)

    # 通常操作は右下へ弱く残す。カード選択中は専用ガイドへ切り替える。
    if h.aim_mode == "":
        h.draw_string(font, Vector2(1074, 580), "矢印  移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, h.C_DIM)
        h.draw_string(font, Vector2(1074, 605), "1〜3  カード", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, h.C_DIM)
        h.draw_string(font, Vector2(1074, 630), "0  リロール", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, h.C_DIM)

    if h.aim_mode != "":
        _draw_context_action_guide()

    # メッセージは重要な結果・エラーだけ。文字を大きくし、1〜2行で読ませる。
    if h.message != "":
        var message_box := Rect2(Vector2(323, 532), Vector2(674, 96))
        h.draw_rect(message_box, h.C_PANEL)
        h.draw_rect(message_box, h.C_FLOOR_EDGE, false, 1.0)
        h.draw_multiline_string(font, Vector2(341, 566), h.message, HORIZONTAL_ALIGNMENT_LEFT, 638, 21, 19, h.C_TEXT)

    if h.stage_clear:
        h.draw_rect(Rect2(Vector2(437, 205), Vector2(446, 142)), Color(0, 0, 0, 0.88))
        h.draw_string(font, Vector2(492, 260), "STAGE CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, h.C_CHARGED_INNER)
        h.draw_string(font, Vector2(524, 302), "次のステージへ", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, h.C_TEXT)


    if h.run_clear:
        h.draw_rect(Rect2(Vector2(437, 148), Vector2(446, 285)), Color(0, 0, 0, 0.92))
        h.draw_string(font, Vector2(505, 199), "GAME CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, h.C_CHARGED_INNER)
        h.draw_string(font, Vector2(506, 231), "全10ステージ踏破", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, h.C_TEXT)

        h.draw_string(font, Vector2(493, 282), "クリア時間", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, h.C_DIM)
        h.draw_string(font, Vector2(701, 282), h._format_clear_time(h.run_elapsed_seconds), HORIZONTAL_ALIGNMENT_RIGHT, 118, 22, h.C_TEXT)
        h.draw_string(font, Vector2(493, 322), "歩数", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, h.C_DIM)
        h.draw_string(font, Vector2(701, 322), str(h.step_count), HORIZONTAL_ALIGNMENT_RIGHT, 118, 22, h.C_TEXT)
        h.draw_string(font, Vector2(493, 362), "被ダメージ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, h.C_DIM)
        h.draw_string(font, Vector2(701, 362), str(h.damage_taken), HORIZONTAL_ALIGNMENT_RIGHT, 118, 22, h.C_TEXT)

        h.draw_line(Vector2(493, 384), Vector2(827, 384), h.C_FLOOR_EDGE, 1.0)
        h.draw_string(font, Vector2(590, 414), "Rでやり直す", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, h.C_TEXT)

    if h.game_over:
        h.draw_rect(Rect2(Vector2(437, 205), Vector2(446, 142)), Color(0, 0, 0, 0.88))
        h.draw_string(font, Vector2(535, 263), "機体停止", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, h.C_ENEMY)
        h.draw_string(font, Vector2(494, 321), "R  この階層をやり直す", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, h.C_TEXT)

func _draw_restart_confirm() -> void:
    var font := ThemeDB.fallback_font
    # 盤面/HUD全体を暗くし、確認だけを画面座標の最前面へ固定する。
    h.draw_rect(Rect2(Vector2.ZERO, h.WINDOW_SIZE), Color(0.0, 0.0, 0.0, 0.60))

    var panel := Rect2(Vector2(382, 220), Vector2(516, 250))
    h.draw_rect(panel, Color(0.025, 0.045, 0.065, 0.98))
    h.draw_rect(panel, Color.WHITE, false, 2.0)
    h.draw_string(font, Vector2(421, 281), "この階層を始めからやり直しますか？", HORIZONTAL_ALIGNMENT_CENTER, 438, 24, h.C_TEXT)

    var yes_rect := Rect2(Vector2(447, 326), Vector2(150, 58))
    var no_rect := Rect2(Vector2(683, 326), Vector2(150, 58))
    _draw_restart_choice(yes_rect, "はい", h.restart_confirm_yes)
    _draw_restart_choice(no_rect, "いいえ", not h.restart_confirm_yes)

    h.draw_string(font, Vector2(458, 429), "←→ 選択    Z 決定    X キャンセル", HORIZONTAL_ALIGNMENT_CENTER, 364, 16, h.C_DIM)

func _draw_restart_choice(rect: Rect2, label: String, selected: bool) -> void:
    var font := ThemeDB.fallback_font
    var fill: Color = Color(0.12, 0.18, 0.24, 1.0) if selected else Color(0.045, 0.065, 0.085, 1.0)
    var edge: Color = Color.WHITE if selected else Color(h.C_FLOOR_EDGE)
    h.draw_rect(rect, fill)
    h.draw_rect(rect, edge, false, 2.0 if selected else 1.0)
    h.draw_string(font, rect.position + Vector2(0, 38), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 21, h.C_TEXT if selected else h.C_DIM)

func _context_action_guide_text() -> String:
    match h.aim_mode:
        CARD_ARC:
            return "↑↓←→ 方向選択    Z 決定    X キャンセル"
        CARD_BOMB, CARD_WARP:
            return "↑↓←→ 照準    Z 決定    X キャンセル"
        CARD_DASH:
            if h.dash_branch_options.size() > 1:
                return "↑↓←→ 分岐選択    Z ここで発動    X キャンセル"
            return "Z 発動    X キャンセル"
        CARD_SURGE:
            return "Z 発動    X キャンセル"
        CARD_LOOP:
            if h.loop_candidates.size() > 1:
                return "←→ 候補選択    Z 発動    X キャンセル"
            return "Z 発動    X キャンセル"
    return "Z 決定    X キャンセル"

func _draw_context_action_guide() -> void:
    var font := ThemeDB.fallback_font
    var guide_rect := Rect2(Vector2(418, 488), Vector2(500, 34))
    h.draw_rect(guide_rect, Color(0.02, 0.05, 0.08, 0.94))
    h.draw_rect(guide_rect, Color.WHITE, false, 1.0)
    h.draw_string(font, guide_rect.position + Vector2(16, 24), _context_action_guide_text(), HORIZONTAL_ALIGNMENT_CENTER, guide_rect.size.x - 32.0, 16, h.C_TEXT)

func _reroll_card_scale(slot: int) -> float:
    if not h.reroll_anim_active:
        return 1.0
    if h.reroll_anim_time < h.REROLL_SHRINK_END:
        var q: float = clampf(h.reroll_anim_time / h.REROLL_SHRINK_END, 0.0, 1.0)
        q = q * q * (3.0 - 2.0 * q)
        return lerpf(1.0, 0.18, q)
    if h.reroll_anim_time < h.REROLL_NOISE_END:
        return 0.0
    var local_t: float = h.reroll_anim_time - h.REROLL_NOISE_END - float(slot) * h.REROLL_CARD_STAGGER
    if local_t <= 0.0:
        return 0.0
    var q: float = clampf(local_t / h.REROLL_POP_DURATION, 0.0, 1.0)
    # 少しだけオーバーシュートして収束する短いポップ。
    var overshoot: float = 1.0 + 0.10 * sin(q * PI)
    return q * overshoot

func _draw_reroll_noise(card_rect: Rect2) -> void:
    if not h.reroll_anim_active or h.reroll_anim_time < h.REROLL_SHRINK_END or h.reroll_anim_time >= h.REROLL_NOISE_END:
        return
    var phase: int = int(floor(h.reroll_anim_time * 1000.0 / 16.0))
    h.draw_rect(card_rect, Color(0.80, 0.96, 1.0, 0.08))
    for i in range(5):
        var y: float = card_rect.position.y + 12.0 + float((i * 23 + phase * 7) % 106)
        var inset: float = float((i * 17 + phase * 11) % 26)
        h.draw_line(Vector2(card_rect.position.x + 8.0 + inset, y), Vector2(card_rect.end.x - 8.0, y), Color(0.85, 0.98, 1.0, 0.52), 2.0)

func _card_replace_scale(slot: int) -> float:
    if not h.card_replace_anim_active or slot != h.card_replace_slot:
        return 1.0
    if h.card_replace_anim_time < h.CARD_REPLACE_SHRINK_END:
        var q: float = clampf(h.card_replace_anim_time / h.CARD_REPLACE_SHRINK_END, 0.0, 1.0)
        q = q * q * (3.0 - 2.0 * q)
        return lerpf(1.0, 0.12, q)
    if h.card_replace_anim_time < h.CARD_REPLACE_NOISE_END:
        return 0.0
    var local_t: float = h.card_replace_anim_time - h.CARD_REPLACE_NOISE_END
    var q: float = clampf(local_t / h.CARD_REPLACE_POP_DURATION, 0.0, 1.0)
    var overshoot: float = 1.0 + 0.08 * sin(q * PI)
    return q * overshoot

func _draw_card_replace_noise(slot: int, card_rect: Rect2) -> void:
    if not h.card_replace_anim_active or slot != h.card_replace_slot:
        return
    if h.card_replace_anim_time < h.CARD_REPLACE_SHRINK_END or h.card_replace_anim_time >= h.CARD_REPLACE_NOISE_END:
        return
    var phase: int = int(floor(h.card_replace_anim_time * 1000.0 / 16.0))
    h.draw_rect(card_rect, Color(0.80, 0.96, 1.0, 0.10))
    for i in range(5):
        var y: float = card_rect.position.y + 12.0 + float((i * 23 + phase * 7) % 106)
        var inset: float = float((i * 17 + phase * 11) % 26)
        h.draw_line(Vector2(card_rect.position.x + 8.0 + inset, y), Vector2(card_rect.end.x - 8.0, y), Color(0.85, 0.98, 1.0, 0.58), 2.0)

func _draw_card_panel_animated(slot: int, rect: Rect2) -> void:
    var scale_value: float = 1.0
    if h.reroll_anim_active:
        _draw_reroll_noise(rect)
        scale_value = _reroll_card_scale(slot)
    elif h.card_replace_anim_active and slot == h.card_replace_slot:
        _draw_card_replace_noise(slot, rect)
        scale_value = _card_replace_scale(slot)
    else:
        _draw_card_panel(slot, rect)
        return

    if scale_value <= 0.01:
        return
    var center: Vector2 = rect.position + rect.size * 0.5
    var shake: Vector2 = h._damage_feedback_shake_offset()
    h.draw_set_transform(shake + center - center * scale_value, 0.0, Vector2(scale_value, scale_value))
    _draw_card_panel(slot, rect)
    h.draw_set_transform(shake)

func _draw_card_panel(slot: int, rect: Rect2) -> void:
    var font := ThemeDB.fallback_font
    var card_id: String = h.hand[slot]
    var cost: int = h._card_cost(card_id)
    var affordable: bool = h.bat >= cost
    var selecting: bool = h.aim_mode != ""
    var active: bool = slot == h.active_hand_slot and selecting
    var subdued: bool = selecting and not active

    var fill: Color = h.C_PANEL_INNER if affordable else h.C_PANEL_DISABLED
    var border: Color = h.C_FLOOR_EDGE
    var border_width: float = 1.0
    var main_text: Color = h.C_TEXT if affordable else h.C_DIM
    var dim_text: Color = h.C_DIM

    if active:
        fill = h.C_PANEL_ACTIVE.lerp(Color.WHITE, 0.08)
        border = Color.WHITE
        border_width = 4.0
    elif subdued:
        fill = h.C_PANEL_DISABLED
        border = h.C_FLOOR_EDGE.lerp(h.C_BG, 0.35)
        main_text = h.C_DIM.lerp(h.C_BG, 0.08)
        dim_text = h.C_DIM.lerp(h.C_BG, 0.12)

    h.draw_rect(rect, fill)
    h.draw_rect(rect, border, false, border_width)

    # 左上は入力キー、中央上はカード名。選択中は右上へ状態だけを置く。
    var key_rect := Rect2(rect.position + Vector2(10, 9), Vector2(30, 30))
    # 入力キー表示は「暗い背景＋明るい文字」に固定して、カード背景の明暗に左右されないようにする。
    var key_fill: Color = Color("#08131d")
    var key_edge: Color = Color.WHITE if active else (h.C_CHARGED_INNER if affordable and not subdued else h.C_DIM)
    var key_text: Color = Color.WHITE if not subdued else h.C_DIM.lightened(0.18)
    h.draw_rect(key_rect, key_fill)
    h.draw_rect(key_rect, key_edge, false, 2.0 if active else 1.0)
    h.draw_string(font, key_rect.position + Vector2(9, 22), str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, key_text)

    h.draw_string(font, rect.position + Vector2(50, 29), h._card_name(card_id), HORIZONTAL_ALIGNMENT_LEFT, 100, 18, main_text)
    if active:
        h.draw_string(font, rect.position + Vector2(148, 29), "選択中", HORIZONTAL_ALIGNMENT_LEFT, 50, 16, Color.WHITE)

    # コストは「BAT」という共通語と青い四角だけにして、読み方を全カードで揃える。
    h.draw_string(font, rect.position + Vector2(12, 59), "BAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dim_text)
    _draw_cost_squares(rect.position + Vector2(45, 47), cost, affordable and not subdued)

    # 中央はカードの形を示す記号。慣れれば文字を読まずに判別できる。
    _draw_card_symbol(card_id, rect.position + Vector2(rect.size.x * 0.5, 82), main_text)

    # 下端は役割と数値だけの一行要約。長文説明は常時表示しない。
    var info_rect := Rect2(rect.position + Vector2(6, 106), Vector2(rect.size.x - 12.0, 20))
    h.draw_rect(info_rect, Color(0.02, 0.05, 0.08, 0.46))
    h.draw_string(font, info_rect.position + Vector2(4, 16), h._card_short_info(card_id), HORIZONTAL_ALIGNMENT_CENTER, info_rect.size.x - 8.0, 15, main_text)

func _draw_reroll_panel(rect: Rect2) -> void:
    var font := ThemeDB.fallback_font
    var affordable: bool = h.bat >= h.REROLL_COST
    var locked_by_selection: bool = h.aim_mode != ""
    var usable: bool = affordable and not locked_by_selection
    h.draw_rect(rect, h.C_PANEL_INNER if usable else h.C_PANEL_DISABLED)
    h.draw_rect(rect, h.C_FLOOR_EDGE.lerp(h.C_BG, 0.30) if locked_by_selection else h.C_FLOOR_EDGE, false, 1.0)

    var key_rect := Rect2(rect.position + Vector2(10, 10), Vector2(30, 30))
    h.draw_rect(key_rect, Color("#08131d"))
    h.draw_rect(key_rect, h.C_CHARGED_INNER if usable else h.C_DIM, false, 1.0)
    h.draw_string(font, key_rect.position + Vector2(8, 22), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE if usable else h.C_DIM.lightened(0.18))

    h.draw_string(font, rect.position + Vector2(50, 29), "リロール", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, h.C_TEXT if usable else h.C_DIM)
    _draw_cost_squares(rect.position + Vector2(50, 44), h.REROLL_COST, usable)
    h.draw_string(font, rect.position + Vector2(102, 59), "3枚交換", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, h.C_DIM)

func _draw_cost_squares(origin: Vector2, count: int, enabled: bool) -> void:
    var size := 11.0
    var gap := 5.0
    for i in range(count):
        var r := Rect2(origin + Vector2(float(i) * (size + gap), 0.0), Vector2(size, size))
        if enabled:
            h.draw_rect(r, h.C_BAT)
        else:
            h.draw_rect(r, h.C_RESOURCE_EMPTY)
            h.draw_rect(r, h.C_DIM, false, 1.0)

func _draw_card_symbol(card_id: String, center: Vector2, color: Color) -> void:
    # 一行要約と共存できるよう、記号はカード中央へ小さくまとめる。
    var s := 0.70
    var accent: Color = h.C_CHARGED_INNER if color != h.C_DIM else h.C_DIM
    match card_id:
        CARD_ARC:
            h.draw_line(center + Vector2(-48, 0) * s, center + Vector2(36, 0) * s, color, 2.0)
            h.draw_line(center + Vector2(36, 0) * s, center + Vector2(24, -8) * s, color, 2.0)
            h.draw_line(center + Vector2(36, 0) * s, center + Vector2(24, 8) * s, color, 2.0)
            for x in [-34.0, -12.0, 10.0]:
                h.draw_rect(Rect2(center + Vector2((x - 4.0) * s, -4.0 * s), Vector2(8, 8) * s), accent)
        CARD_SURGE:
            h.draw_circle(center, 7.0 * s, color)
            var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
                Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, 0.7)]
            for d in dirs:
                h.draw_line(center + d * (11.0 * s), center + d * (31.0 * s), color, 1.5)
                h.draw_circle(center + d * (35.0 * s), 3.0 * s, color)
        CARD_BOMB:
            h.draw_circle(center, 12.0 * s, color)
            h.draw_arc(center, 26.0 * s, 0.0, TAU, 32, color, 1.5, true)
            h.draw_line(center + Vector2(8, -12) * s, center + Vector2(18, -25) * s, color, 1.5)
            h.draw_circle(center + Vector2(20, -28) * s, 3.0 * s, color)
        CARD_WARP:
            h.draw_circle(center + Vector2(-28, 0) * s, 7.0 * s, color)
            h.draw_circle(center + Vector2(28, 0) * s, 7.0 * s, color)
            h.draw_line(center + Vector2(-17, 0) * s, center + Vector2(16, 0) * s, color, 1.5)
            h.draw_line(center + Vector2(16, 0) * s, center + Vector2(7, -7) * s, color, 1.5)
            h.draw_line(center + Vector2(16, 0) * s, center + Vector2(7, 7) * s, color, 1.5)
        CARD_DASH:
            for x in [-34.0, -12.0, 10.0]:
                h.draw_rect(Rect2(center + Vector2((x - 4.0) * s, -4.0 * s), Vector2(8, 8) * s), accent)
            h.draw_circle(center + Vector2(20, 0) * s, 6.0 * s, color, false, 1.5)
            h.draw_line(center + Vector2(-42, 16) * s, center + Vector2(38, 16) * s, color, 2.0)
            h.draw_line(center + Vector2(38, 16) * s, center + Vector2(25, 7) * s, color, 2.0)
            h.draw_line(center + Vector2(38, 16) * s, center + Vector2(25, 25) * s, color, 2.0)
        CARD_LOOP:
            h.draw_arc(center, 28.0 * s, 0.0, TAU, 32, color, 2.0, true)
            h.draw_circle(center, 14.0 * s, accent)
            h.draw_circle(center, 6.0 * s, h.C_PANEL_INNER if color != h.C_DIM else h.C_PANEL_DISABLED)

func _draw_bat_icons(origin: Vector2) -> void:
    # 右パネル幅に収めるため5個×2段。
    var size := 14.0
    var gap := 7.0
    for i in range(h.MAX_BAT):
        var col := i % 5
        var row := i / 5
        var rect := Rect2(origin + Vector2(float(col) * (size + gap), float(row) * (size + gap)), Vector2(size, size))
        if i < h.bat:
            h.draw_rect(rect, h.C_BAT)
            h.draw_rect(rect, Color.WHITE, false, 2.0)
        else:
            h.draw_rect(rect, h.C_RESOURCE_EMPTY)
            h.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.30), false, 1.0)

func _hp_icon_pulse_color() -> Color:
    var t: float = float(Time.get_ticks_msec()) / 1000.0
    var pulse01: float = (sin(t * TAU / h.HP_ICON_PULSE_INTERVAL) + 1.0) * 0.5
    # 残っているHPだけを、明るい赤の範囲内でゆっくり呼吸させる。
    # 暗くなりすぎると読みにくいため、最低輝度も高めに保つ。
    var dim_red: Color = h.C_HP.darkened(0.14)
    var bright_red: Color = h.C_HP.lerp(Color.WHITE, 0.28)
    return dim_red.lerp(bright_red, pulse01)

func _draw_hp_icons(origin: Vector2) -> void:
    var base_radius := 8.0
    var draw_radius: float = base_radius + 2.0 * h._damage_feedback_envelope()
    var gap := 9.0
    var hp_color: Color = _hp_icon_pulse_color()
    for i in range(h.MAX_HP):
        var center := origin + Vector2(base_radius + float(i) * (base_radius * 2.0 + gap), 0.0)
        if i < h.hp:
            h.draw_circle(center, draw_radius, hp_color)
            h.draw_arc(center, draw_radius, 0.0, TAU, 24, Color.WHITE, 2.0, true)
        else:
            h.draw_circle(center, base_radius, h.C_RESOURCE_EMPTY)
            h.draw_arc(center, base_radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.30), 1.0, true)
