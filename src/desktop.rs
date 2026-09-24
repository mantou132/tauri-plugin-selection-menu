use std::sync::Mutex;
use serde::de::DeserializeOwned;
use tauri::{AppHandle, Runtime};

use crate::models::*;

pub struct SelectionMenu<R: Runtime> {
    #[allow(dead_code)]
    app: AppHandle<R>,
    items: Mutex<Vec<SelectionMenuItem>>,
}

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: tauri::plugin::PluginApi<R, C>,
) -> crate::Result<SelectionMenu<R>> {
    Ok(SelectionMenu {
        app: app.clone(),
        items: Mutex::new(Vec::new()),
    })
}

impl<R: Runtime> SelectionMenu<R> {
    pub fn set_menu_items(&self, payload: SetMenuItemsOptions) -> crate::Result<()> {
        let mut items = self.items.lock().unwrap();
        *items = payload.items;
        Ok(())
    }

    pub fn get_menu_items(&self) -> crate::Result<Vec<SelectionMenuItem>> {
        let items = self.items.lock().unwrap();
        Ok(items.clone())
    }

    pub fn clear_menu_items(&self) -> crate::Result<()> {
        let mut items = self.items.lock().unwrap();
        items.clear();
        Ok(())
    }
}
