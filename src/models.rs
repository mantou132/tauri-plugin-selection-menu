use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SelectionMenuItem {
    pub id: String,
    pub label: String,
}

fn default_auto_clear() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SetMenuItemsOptions {
    pub items: Vec<SelectionMenuItem>,
    #[serde(default)]
    pub remove_native: bool,
    #[serde(default = "default_auto_clear")]
    pub auto_clear: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MenuItemClickPayload {
    pub id: String,
    pub text: String,
}
