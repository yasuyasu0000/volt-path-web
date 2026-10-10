extends RefCounted

# Web-only GA4 bridge. Empty measurement ID = completely disabled.
# Set [analytics] ga4_measurement_id in project.godot when analytics should go live.
const GAME_VERSION := "0.940"

var enabled := false
var measurement_id := ""

func setup() -> void:
    measurement_id = String(ProjectSettings.get_setting("analytics/ga4_measurement_id", "")).strip_edges()
    if not OS.has_feature("web"):
        return
    if measurement_id == "" or not measurement_id.begins_with("G-"):
        return

    var id_json := JSON.stringify(measurement_id)
    var bootstrap := """
(function() {
    const id = %s;
    if (!id || window.__voltPathGa4Ready) return;
    window.dataLayer = window.dataLayer || [];
    window.gtag = window.gtag || function(){ window.dataLayer.push(arguments); };
    window.gtag('js', new Date());
    window.gtag('config', id, { send_page_view: true });
    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id);
    document.head.appendChild(script);
    window.__voltPathGa4Ready = true;
})();
""" % id_json
    JavaScriptBridge.eval(bootstrap, true)
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
