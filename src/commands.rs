use tauri::{command, AppHandle, Runtime};

use crate::models::*;
use crate::Result;
use crate::SelectionMenuExt;

#[command]
pub(crate) async fn set_menu_items<R: Runtime>(
    app: AppHandle<R>,
    payload: SetMenuItemsOptions,
) -> Result<()> {
    app.selection_menu().set_menu_items(payload)
}

#[command]
pub(crate) async fn get_menu_items<R: Runtime>(
    app: AppHandle<R>,
) -> Result<Vec<SelectionMenuItem>> {
    app.selection_menu().get_menu_items()
}

#[command]
pub(crate) async fn clear_menu_items<R: Runtime>(
    app: AppHandle<R>,
) -> Result<()> {
    app.selection_menu().clear_menu_items()
}
