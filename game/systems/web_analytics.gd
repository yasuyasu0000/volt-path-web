extends RefCounted

# Web-only GA4 event bridge.
# GA4 itself is initialized in the Web export preset via html/head_include.
const GAME_VERSION := "0.941"

var enabled := false
var measurement_id := ""

func setup() -> void:
    if not OS.has_feature("web"):
        return

    # Head Include runs before the Godot engine starts. Read the ID and verify that
    # the standard gtag bootstrap is available before enabling game events.
    measurement_id = String(JavaScriptBridge.eval("window.__voltPathGa4Id || ''", true)).strip_edges()
    var gtag_ready = JavaScriptBridge.eval("typeof window.gtag === 'function'", true)
    if measurement_id == "" or not measurement_id.begins_with("G-") or gtag_ready != true:
        push_warning("GA4 Head Include was not initialized; analytics events are disabled.")
        return

    enabled = true

func track(event_name: String, params: Dictionary = {}) -> void:
    if not enabled or event_name == "":
        return
    var payload := params.duplicate(true)
    payload["game_version"] = GAME_VERSION
    var event_json := JSON.stringify(event_name)
    var payload_json := JSON.stringify(payload)
    var code := "if (window.gtag) { window.gtag('event', %s, %s); }" % [event_json, payload_json]
    JavaScriptBridge.eval(code, true)
