use tauri::{
  plugin::{Builder, TauriPlugin},
  Manager, Runtime,
};

pub use models::*;

#[cfg(desktop)]
mod desktop;
#[cfg(mobile)]
mod mobile;

mod commands;
mod error;
mod models;

pub use error::{Error, Result};

#[cfg(desktop)]
use desktop::SelectionMenu;
#[cfg(mobile)]
use mobile::SelectionMenu;

/// Extensions to [`tauri::App`], [`tauri::AppHandle`] and [`tauri::Window`] to access the selection-menu APIs.
pub trait SelectionMenuExt<R: Runtime> {
  fn selection_menu(&self) -> &SelectionMenu<R>;
}

impl<R: Runtime, T: Manager<R>> crate::SelectionMenuExt<R> for T {
  fn selection_menu(&self) -> &SelectionMenu<R> {
    self.state::<SelectionMenu<R>>().inner()
  }
}

/// Initializes the plugin.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
  Builder::new("selection-menu")
    .invoke_handler(tauri::generate_handler![commands::ping])
    .setup(|app, api| {
      #[cfg(mobile)]
      let selection_menu = mobile::init(app, api)?;
      #[cfg(desktop)]
      let selection_menu = desktop::init(app, api)?;
      app.manage(selection_menu);
      Ok(())
    })
    .build()
}
