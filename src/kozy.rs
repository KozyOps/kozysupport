// KozySupport: the custom-client config upstream reads from a custom.txt signed
// by RustDesk is compiled in instead (kozy/custom.json), and the updater reads
// from our CDN. See kozy/README.md.
use base::config::keys;
use hbb_common::{config, log};
use std::collections::HashMap;

const CUSTOM_CLIENT: &str = include_str!("../kozy/custom.json");

pub const UPDATE_BASE_URL: &str = "https://cdn.kozyops.com/public/remote-support/";

pub fn latest_url() -> String {
    format!("{UPDATE_BASE_URL}latest.json")
}

// Same application as common::read_custom_client after its signature check.
pub fn load_custom_client() -> bool {
    let Ok(mut data) = serde_json::from_str::<HashMap<String, serde_json::Value>>(CUSTOM_CLIENT)
    else {
        log::error!("Failed to parse the compiled-in KozySupport config");
        return false;
    };

    if let Some(app_name) = data.remove("app-name").and_then(|v| v.as_str().map(str::to_owned)) {
        *config::APP_NAME.write().unwrap() = app_name;
    }

    let to_map = |list: &'static [&'static str]| {
        list.iter()
            .map(|s| (s.replace('_', "-"), s))
            .collect::<HashMap<_, _>>()
    };
    let display = to_map(keys::KEYS_DISPLAY_SETTINGS);
    let local = to_map(keys::KEYS_LOCAL_SETTINGS);
    let settings = to_map(keys::KEYS_SETTINGS);
    let buildin = to_map(keys::KEYS_BUILDIN_SETTINGS);
    for (key, is_override) in [("default-settings", false), ("override-settings", true)] {
        if let Some(v) = data.remove(key) {
            crate::common::read_custom_client_advanced_settings(
                v, &display, &local, &settings, &buildin, is_override,
            );
        }
    }
    for (k, v) in data {
        if let Some(v) = v.as_str() {
            config::HARD_SETTINGS.write().unwrap().insert(k, v.to_owned());
        }
    }
    true
}

#[cfg(test)]
mod tests {
    #[test]
    fn compiled_in_config_brands_and_locks_the_server() {
        assert!(super::load_custom_client());
        assert_eq!(crate::common::get_app_name(), "KozySupport");
        assert!(crate::common::is_custom_client());
        let overrides = hbb_common::config::OVERWRITE_SETTINGS.read().unwrap();
        assert_eq!(
            overrides.get("custom-rendezvous-server").map(String::as_str),
            Some("rustdesk.kozyops.com")
        );
        assert!(overrides.contains_key("key"));
        drop(overrides);
        assert_eq!(
            crate::common::get_api_server(
                hbb_common::config::Config::get_option("api-server"),
                hbb_common::config::Config::get_option("custom-rendezvous-server"),
            ),
            "https://rustdesk.kozyops.com"
        );
    }
}
