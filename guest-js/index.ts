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

export type MenuItemClickHandler = (
  event: SelectionMenuItemClickEvent
) => void | Promise<void>;
export type MenuDismissHandler = () => void | Promise<void>;

export interface SelectionMenuItemInput {
  /**
   * Unique identifier for the menu item. If omitted, an ID will be generated automatically.
   */
  id?: string;
  /**
   * Display label shown in the selection menu.
   */
  label: string;
  /**
   * Optional icon name or resource identifier.
   */
  icon?: string;
  /**
   * Callback invoked when this menu item is tapped in the native selection menu.
   */
  onClick?: MenuItemClickHandler;
}

export interface SetMenuItemsConfig {
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
  /**
   * Optional callback invoked when the native selection menu closes.
   */
  onDismiss?: MenuDismissHandler;
}

export interface SetMenuItemsOptions extends SetMenuItemsConfig {
  /**
   * List of custom menu items to inject into the selection menu.
   */
  items: SelectionMenuItemInput[];
}

let idCounter = 0;
function generateItemId(label: string): string {
  idCounter = (idCounter + 1) % 1000000;
  const safeLabel = label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .slice(0, 16);
  return `${safeLabel || 'item'}_${Date.now().toString(36)}_${idCounter}`;
}

const itemCallbacks = new Map<string, MenuItemClickHandler>();
let activeDismissCallback: MenuDismissHandler | null = null;
let lastAutoClear = true;
let internalListenersPromise: Promise<void> | null = null;

function ensureInternalListeners(): Promise<void> {
  if (!internalListenersPromise) {
    internalListenersPromise = (async () => {
      try {
        await addPluginListener<SelectionMenuItemClickEvent>(
          'selection-menu',
          'click',
          (event) => {
            const callback = itemCallbacks.get(event.id);
            if (callback) {
              try {
                callback(event);
              } catch (e) {
                console.error('[selection-menu] Error in item onClick handler:', e);
              }
            }
          }
        );

        await addPluginListener<void>(
          'selection-menu',
          'dismiss',
          () => {
            if (activeDismissCallback) {
              try {
                activeDismissCallback();
              } catch (e) {
                console.error('[selection-menu] Error in onDismiss handler:', e);
              }
            }
            if (lastAutoClear) {
              itemCallbacks.clear();
              activeDismissCallback = null;
            }
          }
        );
      } catch (err) {
        internalListenersPromise = null;
        throw err;
      }
    })();
  }
  return internalListenersPromise;
}

/**
 * Configure custom items to display in the native text selection floating menu.
 *
 * ```ts
 * await setMenuItems({
 *   items: [
 *     {
 *       label: 'Ask in New Session',
 *       onClick: ({ text }) => {
 *         openNewSession(text);
 *       },
 *     },
 *   ],
 *   removeNative: false,
 * });
 * ```
 */
export async function setMenuItems(
  options: SetMenuItemsOptions
): Promise<void> {
  await ensureInternalListeners();

  const rawItems = options.items || [];

  const removeNative = !!options.removeNative;
  const autoClear = options.autoClear ?? true;
  lastAutoClear = autoClear;
  activeDismissCallback = options.onDismiss || null;

  // Clear previous callback map and register new item callbacks
  itemCallbacks.clear();

  const serializedItems: SelectionMenuItem[] = rawItems.map((item) => {
    const id = item.id || generateItemId(item.label);
    if (item.onClick) {
      itemCallbacks.set(id, item.onClick);
    }
    return {
      id,
      label: item.label,
      icon: item.icon,
    };
  });

  const payload = {
    items: serializedItems,
    removeNative,
    autoClear,
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
  itemCallbacks.clear();
  activeDismissCallback = null;
  await invoke('plugin:selection-menu|clear_menu_items');
}

/**
 * Listen for selection menu item click events globally.
 *
 * @param handler Callback invoked when any custom menu item is tapped, receiving `{ id, text }`.
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
 * Listen for selection menu dismiss/close events globally.
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
