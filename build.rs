const COMMANDS: &[&str] = &[
    "set_menu_items",
    "get_menu_items",
    "clear_menu_items",
    "register_listener",
    "remove_listener",
];

fn main() {
    tauri_plugin::Builder::new(COMMANDS)
        .android_path("android")
        .ios_path("ios")
        .build();
}
