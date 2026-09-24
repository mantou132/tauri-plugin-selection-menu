import { invoke, addPluginListener, type PluginListener } from '@tauri-apps/api/core';

export interface SelectionMenuItem {
  /**
   * Unique identifier for the menu item.
   */
  id: string;
  /**
   * Display label shown in the selection menu.
   */
  label: string;
  /**
   * Optional icon name or resource identifier.
   */
  icon?: string;
}

export interface SetMenuItemsOptions {
  /**
   * List of custom menu items to inject into the selection menu.
   */
  items: SelectionMenuItem[];
  /**
   * Whether to remove/minimize native menu items (e.g. Look Up, Share, Translate).
   * Default: false
   */
  removeNative?: boolean;
  /**
   * Automatically clear custom menu items when the menu closes or an item is clicked.
   * Default: true
   */
  autoClear?: boolean;
}

export interface SelectionMenuItemClickEvent {
  /**
   * ID of the clicked menu item.
   */
  id: string;
  /**
   * Currently selected text extracted from the webview.
   */
  text: string;
}

export type MenuItemClickHandler = (event: SelectionMenuItemClickEvent) => void;
export type MenuDismissHandler = () => void;

/**
 * Configure custom items to display in the native text selection floating menu.
 *
 * @param options Menu configuration options or array of menu items.
 */
export async function setMenuItems(
  options: SetMenuItemsOptions | SelectionMenuItem[]
): Promise<void> {
  const opts: SetMenuItemsOptions = Array.isArray(options) ? { items: options } : options;
  const payload: SetMenuItemsOptions = {
    items: opts.items || [],
    removeNative: !!opts.removeNative,
    autoClear: opts.autoClear ?? true,
  };

  await invoke('plugin:selection-menu|set_menu_items', {
    ...payload,
    payload,
  });
}

/**
 * Get currently active custom selection menu items.
 */
export async function getMenuItems(): Promise<SelectionMenuItem[]> {
  return await invoke<SelectionMenuItem[]>('plugin:selection-menu|get_menu_items');
}

/**
 * Clear all custom menu items immediately.
 */
export async function clearMenuItems(): Promise<void> {
  await invoke('plugin:selection-menu|clear_menu_items');
}

/**
 * Listen for selection menu item click events.
 *
 * @param handler Callback invoked when a custom menu item is tapped, receiving `{ id, text }`.
 * @returns A promise that resolves to a `PluginListener` to unsubscribe.
 */
export async function onMenuItemClick(
  handler: MenuItemClickHandler
): Promise<PluginListener> {
  return await addPluginListener<SelectionMenuItemClickEvent>(
    'selection-menu',
    'click',
    handler
  );
}

/**
 * Listen for selection menu dismiss/close events.
 *
 * @param handler Callback invoked when the selection menu closes.
 * @returns A promise that resolves to a `PluginListener` to unsubscribe.
 */
export async function onMenuDismiss(
  handler: MenuDismissHandler
): Promise<PluginListener> {
  return await addPluginListener<void>(
    'selection-menu',
    'dismiss',
    handler
  );
}

export { type PluginListener };
