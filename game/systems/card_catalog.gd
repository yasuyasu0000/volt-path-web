extends RefCounted

const GameBalance = preload("res://systems/game_balance.gd")

# VOLT PATH card definitions.
# Keep card identity, display text, cost, and hand-summary text in one place.

const ARC := "arc"
const SURGE := "surge"
const BOMB := "bomb"
const WARP := "warp"
const DASH := "dash"
const LOOP := "loop"

const POOL: Array[String] = [
    ARC,
    SURGE,
    BOMB,
    WARP,
    DASH,
    LOOP,
]

static func display_name(card_id: String) -> String:
    match card_id:
        ARC:
            return "ストレートボルト"
        SURGE:
            return "フロアライトニング"
        BOMB:
            return "サンダーボム"
        WARP:
            return "ボルトワープ"
        DASH:
            return "チェインダッシュ"
        LOOP:
            return "サーキットブレイク"
    return "不明"

# 左HUDでは正式名称を省略せず、意味の切れ目で2行に分けて表示する。
# メッセージ等では display_name() の1行正式名称をそのまま使う。
static func hud_name_lines(card_id: String) -> PackedStringArray:
    match card_id:
        ARC:
            return PackedStringArray(["ストレート", "ボルト"])
        SURGE:
            return PackedStringArray(["フロア", "ライトニング"])
        BOMB:
            return PackedStringArray(["サンダー", "ボム"])
        WARP:
            return PackedStringArray(["ボルト", "ワープ"])
        DASH:
            return PackedStringArray(["チェイン", "ダッシュ"])
        LOOP:
            return PackedStringArray(["サーキット", "ブレイク"])
    return PackedStringArray(["不明", ""])

static func cost(card_id: String) -> int:
    match card_id:
        ARC:
            return GameBalance.ARC_COST
        SURGE:
            return GameBalance.SURGE_COST
        BOMB:
            return GameBalance.BOMB_COST
        WARP:
            return GameBalance.WARP_COST
        DASH:
            return GameBalance.DASH_COST
        LOOP:
            return GameBalance.LOOP_COST
    return 99

static func short_info(card_id: String) -> String:
    match card_id:
        ARC:
            return "直線PATH全体  %dDMG/マス" % GameBalance.ARC_DAMAGE
        SURGE:
            return "接続PATH全体  %dDMG/マス" % GameBalance.SURGE_DAMAGE_PER_CELL
        BOMB:
            return "任意の帯電マス  3×3 / %dDMG/マス" % GameBalance.BOMB_DAMAGE_PER_CELL
        WARP:
            return "任意の帯電マスへ移動"
        DASH:
            return "PATH走破  %dDMG/マス" % GameBalance.DASH_DAMAGE_PER_CELL
        LOOP:
            return "ループ内+輪  %dDMG/マス" % GameBalance.LOOP_DAMAGE_PER_CELL
    return ""
