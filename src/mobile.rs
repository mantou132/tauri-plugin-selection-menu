use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::models::*;

#[cfg(target_os = "ios")]
tauri::ios_plugin_binding!(init_plugin_selection_menu);

pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> crate::Result<SelectionMenu<R>> {
    #[cfg(target_os = "android")]
    let handle = api.register_android_plugin("com.plugin.selection_menu", "SelectionMenuPlugin")?;
    #[cfg(target_os = "ios")]
    let handle = api.register_ios_plugin(init_plugin_selection_menu)?;
    Ok(SelectionMenu(handle))
}

pub struct SelectionMenu<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> SelectionMenu<R> {
    pub fn set_menu_items(&self, payload: SetMenuItemsOptions) -> crate::Result<()> {
        self.0
            .run_mobile_plugin("set_menu_items", payload)
            .map_err(Into::into)
    }

    pub fn get_menu_items(&self) -> crate::Result<Vec<SelectionMenuItem>> {
        self.0
            .run_mobile_plugin("get_menu_items", ())
            .map_err(Into::into)
    }

    pub fn clear_menu_items(&self) -> crate::Result<()> {
        self.0
            .run_mobile_plugin("clear_menu_items", ())
            .map_err(Into::into)
    }
}
