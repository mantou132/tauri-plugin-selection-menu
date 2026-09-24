# Tauri Plugin Selection Menu

[![npm version](https://img.shields.io/npm/v/tauri-plugin-selection-menu-api.svg)](https://www.npmjs.com/package/tauri-plugin-selection-menu-api)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE)

[English](README.md) | [简体中文](README.zh-CN.md)

A high-performance Tauri v2 plugin to customize the native text selection floating menu (capsule toolbar / context menu) on **iOS** and **Android**.

Allows apps (such as AI chat apps, note-taking apps, e-readers, and translation tools) to inject custom actions directly into the native text selection capsule (e.g. **"Ask AI"**, **"Quote Selection"**, **"Search Notes"**).

---

## ✨ Features

- 📱 **Native Look & Feel**:
  - **iOS**: Injects into the native system edit menu via Apple's official `UIMenuBuilder` and `UIAction`.
  - **Android**: Hooks into native `ActionMode.TYPE_FLOATING` (Floating Toolbar).
  - Matches the OS theme, typography, haptics, pagination, and accessibility without any web overlay hacks.
- 🔄 **Selection Handle Dragging Support**:
  - Handles the transient destruction and recreation lifecycle in Android Chromium and iOS WebKit when users drag selection handles (water drops / teardrop pins). Custom items persist smoothly.
- 🧹 **Auto Clear (`autoClear: true`)**:
  - Automatically cleans up custom menu items when the selection menu closes (tapping outside, scrolling, clicking Copy, or clicking a custom action), returning other text areas to default system behavior.
- 🚫 **Optionally Remove Native Actions (`removeNative: true`)**:
  - Replaces native system actions (Copy, Look Up, Share, Translate) to present only your custom actions.
- 🎯 **Safe Selection Extraction**:
  - Reads the selected text from the WebView DOM right before the menu dismisses, avoiding race conditions where the selection collapses too early.
- ⚡ **Event Listeners**:
  - `onMenuItemClick`: Receive `{ id, text }` when a custom action is tapped.
  - `onMenuDismiss`: Receive an event when the capsule menu is closed.

---

## 📦 Supported Platforms

| Platform | Minimum Version | Technology |
| :--- | :--- | :--- |
| **iOS** | iOS 14.0+ (Optimized for iOS 16+) | `UIMenuBuilder` + `WKUIDelegateProxy` |
| **Android** | API 23+ (Android 6.0+) | `ActionMode.TYPE_FLOATING` + `SelectionActionModeLayout` |
| **Desktop** | macOS / Windows / Linux | Fallback state management |

---

## 🚀 Installation

### 1. Install JavaScript / TypeScript Package

```bash
# Using pnpm
pnpm add tauri-plugin-selection-menu-api

# Using npm
npm install tauri-plugin-selection-menu-api

# Using yarn
yarn add tauri-plugin-selection-menu-api
```

### 2. Add Cargo Dependency

Add `tauri-plugin-selection-menu` to your `src-tauri/Cargo.toml`:

```toml
[dependencies]
tauri-plugin-selection-menu = "0.1"
```

Or add via git reference:

```toml
[dependencies]
tauri-plugin-selection-menu = { git = "https://github.com/mantou132/tauri-plugin-selection-menu" }
```

### 3. Register Plugin in Rust

In your `src-tauri/src/lib.rs` (or `main.rs`):

```rust
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_selection_menu::init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 4. Configure Permissions

In your Tauri capabilities configuration file (e.g. `src-tauri/capabilities/default.json`):

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Capability for the main window",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "selection-menu:default"
  ]
}
```

---

## 📖 Usage Guide

### 1. Direct `onClick` Handlers (Recommended)

No need for manual IDs or separate event listeners. Pass an `onClick` callback directly to each menu item, and receive the selected text `{ text }`:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    {
      label: 'Ask in New Session',
      onClick: ({ text }) => {
        openNewSession(text);
      },
    },
    {
      label: 'Search in Notes',
      onClick: ({ text }) => {
        searchInNotes(text);
      },
    },
  ],
  removeNative: false, // Set to true to hide native Copy, Share, etc.
  autoClear: true,     // Automatically reset when menu closes (default: true)
  onDismiss: () => {
    console.log('Selection menu closed');
  },
});
```

---

### 2. Contextual Menu for Specific Card (Auto-clean)

Set custom menu items dynamically (e.g. on `selectionchange` or user interaction). When the menu closes or the user clicks an action, it automatically cleans up:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

// Listen for selection inside a specific element
document.addEventListener('selectionchange', () => {
  const selection = window.getSelection();
  if (!selection || selection.isCollapsed || !selection.toString().trim()) return;

  const targetCard = document.querySelector('.my-ai-card');
  if (targetCard && targetCard.contains(selection.anchorNode)) {
    // Inject contextual items only for this card
    setMenuItems({
      items: [
        {
          label: 'Ask AI',
          onClick: ({ text }) => askAI(text),
        },
        {
          label: 'Quote Selection',
          onClick: ({ text }) => quoteSelection(text),
        },
      ],
      removeNative: false, // Keep native Copy, Share, etc.
      autoClear: true,     // Automatically clean up when dismissed
    });
  }
});
```

---

### 3. Global Event Listener Pattern (Optional)

If you prefer centralized global event handling, you can assign IDs and listen via `onMenuItemClick`:

```typescript
import { setMenuItems, onMenuItemClick, onMenuDismiss } from 'tauri-plugin-selection-menu-api';

// Listen to menu item clicks
const unlistenClick = await onMenuItemClick((event) => {
  console.log(`Action ID: ${event.id}`);
  console.log(`Selected Text: "${event.text}"`);
});

// Listen to menu dismiss (close)
const unlistenDismiss = await onMenuDismiss(() => {
  console.log('Selection capsule closed');
});
```

---

### 3. Global Persistent Menu

If your application wants a consistent custom selection action throughout the entire app:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { id: 'translate', label: 'Translate' },
    { id: 'explain', label: 'Explain with AI' },
  ],
  removeNative: false,
  autoClear: false, // Persist across selections
});
```

---

### 4. Remove Native Items (`removeNative: true`)

Show **only** your custom actions in the capsule:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { id: 'session-send', label: 'Send to Session' },
    { id: 'copy-clean', label: 'Clean Copy' },
  ],
  removeNative: true, // Hides Copy, Look Up, Share, Translate
  autoClear: true,
});
```

---

### 5. Manual Clear and Inspecting Active Items

```typescript
import { clearMenuItems, getMenuItems } from 'tauri-plugin-selection-menu-api';

// Clear all custom items immediately
await clearMenuItems();

// Check which custom items are currently configured
const currentItems = await getMenuItems();
console.log('Current items:', currentItems);
```

---

## 📚 API Reference

### Methods

#### `setMenuItems(options)`
Configures custom items to display in the native text selection floating menu.

```typescript
function setMenuItems(
  options: SetMenuItemsOptions
): Promise<void>;
```

```typescript
// Set custom items with options
await setMenuItems({
  items: [
    { id: 'translate', label: 'Translate' },
    { id: 'explain', label: 'Explain with AI' },
  ],
  removeNative: false,
  autoClear: true,
  onDismiss: () => {
    console.log('Selection menu closed');
  },
});
```

#### `getMenuItems()`
Retrieves the list of currently active custom selection menu items.

```typescript
function getMenuItems(): Promise<SelectionMenuItem[]>;
```

#### `clearMenuItems()`
Clears all custom menu items immediately.

```typescript
function clearMenuItems(): Promise<void>;
```

#### `onMenuItemClick(handler)`
Listens globally for clicks on any custom menu item (optional).

```typescript
function onMenuItemClick(
  handler: (event: SelectionMenuItemClickEvent) => void | Promise<void>
): Promise<PluginListener>;
```

#### `onMenuDismiss(handler)`
Listens globally for when the native selection menu is dismissed or closed.

```typescript
function onMenuDismiss(
  handler: () => void | Promise<void>
): Promise<PluginListener>;
```

---

### Types & Interfaces

#### `SelectionMenuItemInput`
| Property | Type | Description |
| :--- | :--- | :--- |
| `label` | `string` | Label text displayed on the menu button (required). |
| `id` | `string?` | Optional unique identifier. If omitted, one is generated automatically. |
| `icon` | `string?` | Optional icon identifier. |
| `onClick` | `(event: { id: string, text: string }) => void \| Promise<void>` | Optional click callback invoked with the selected text `{ text }`. |

#### `SetMenuItemsConfig`
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `removeNative` | `boolean` | `false` | Whether to remove/replace system items (Copy, Share, Look Up). |
| `autoClear` | `boolean` | `true` | Automatically clear custom items when the menu closes or an item is clicked. |
| `onDismiss` | `() => void \| Promise<void>` | `undefined` | Optional callback invoked when the capsule menu is dismissed. |

#### `SetMenuItemsOptions`
| Property | Type | Description |
| :--- | :--- | :--- |
| `items` | `SelectionMenuItemInput[]` | Array of custom menu items. |
| Extends | `SetMenuItemsConfig` | Includes `removeNative`, `autoClear`, `onDismiss`. |

#### `SelectionMenuItemClickEvent`
| Property | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | ID of the clicked menu item. |
| `text` | `string` | The text that was selected when the item was clicked. |

---

## 🛠️ Architecture & Under the Hood

### iOS Implementation
- **Swizzled `buildMenu(with:)`**: Hooked into both `WKWebView` and `UIViewController` to ensure that contextual menu customization works reliably across iOS 14 through iOS 18+.
- **`UIMenuBuilder`**: Uses Apple's standard `insertSibling` / `replaceChildren` on `.standardEdit` to keep the app 100% App Store safe without private APIs.
- **`WKUIDelegateProxy`**: Transparently proxies `WKWebView.uiDelegate` to intercept `webView(_:willDismissEditMenuWithAnimator:)` on iOS 16.4+, and listens to `UIMenuController.didHideMenuNotification` on earlier versions for accurate dismiss detection and cleanup.

### Android Implementation
- **Zero Activity Subclassing**: Tauri's `WebView` is seamlessly wrapped inside a thin `SelectionActionModeLayout` (`FrameLayout`) inside the plugin's `load(webView)` lifecycle.
- **`startActionModeForChild` Interception**: Wraps incoming callbacks in `SelectionActionModeCallback`, intercepting `ActionMode.TYPE_FLOATING` without overriding MainActivity or modifying Android manifests.
- **Handle Dragging Resilience**: Incorporates a debounced session manager. When Chromium destroys the action mode during handle adjustments, the pending clear is cancelled upon subsequent recreation, keeping custom items visible while the user adjusts selection handles.
- **Safe Evaluation**: Queries `window.getSelection()` asynchronously prior to finishing the action mode, ensuring that selected text is never wiped before the click handler receives it.

---

## 📄 License

Dual-licensed under either:
- **MIT License** ([LICENSE-MIT](LICENSE-MIT) or [http://opensource.org/licenses/MIT](http://opensource.org/licenses/MIT))
- **Apache License, Version 2.0** ([LICENSE-APACHE](LICENSE-APACHE) or [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0))
