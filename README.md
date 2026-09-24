# Tauri Plugin Selection Menu

[![npm version](https://img.shields.io/npm/v/tauri-plugin-selection-menu-api.svg)](https://www.npmjs.com/package/tauri-plugin-selection-menu-api)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE)

[English](README.md) | [简体中文](README.zh-CN.md)

Customize native text selection floating menus (capsule toolbar / context menu) on **iOS** and **Android** in Tauri v2.

Inject actions like **"Ask AI"**, **"Quote"**, or **"Search Notes"** directly into the system selection menu.

---

## 📦 Supported Platforms

| Platform | Min Version | Implementation |
| :--- | :--- | :--- |
| **iOS** | iOS 14.0+ | `UIMenuBuilder` + standard edit menu |
| **Android** | Android 6.0+ (API 23+) | `ActionMode.TYPE_FLOATING` |
| **Desktop** | macOS / Windows / Linux | Graceful no-op fallback |

---

## 🚀 Installation

### 1. Install npm package

```bash
pnpm add tauri-plugin-selection-menu-api
# or npm install tauri-plugin-selection-menu-api
```

### 2. Add Cargo dependency

In `src-tauri/Cargo.toml`:

```toml
[dependencies]
tauri-plugin-selection-menu = "0.1"
```

### 3. Register plugin in Rust

In `src-tauri/src/lib.rs`:

```rust
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_selection_menu::init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 4. Add permission

In `src-tauri/capabilities/default.json`:

```json
{
  "permissions": [
    "core:default",
    "selection-menu:default"
  ]
}
```

---

## 💡 Quick Start

Pass custom menu items with `onClick` handlers. The selected text is provided directly:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    {
      label: 'Ask AI',
      onClick: ({ text }) => {
        console.log('Selected text:', text);
      },
    },
    {
      label: 'Search Notes',
      onClick: ({ text }) => {
        searchInNotes(text);
      },
    },
  ],
});
```

---

## 🎯 Common Examples

### Contextual Menu for Specific Card (Auto-clean)

Update menu items dynamically on selection. With `autoClear: true` (default), custom items automatically reset when the menu closes:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

document.addEventListener('selectionchange', () => {
  const selection = window.getSelection();
  if (!selection || selection.isCollapsed || !selection.toString().trim()) return;

  const targetCard = document.querySelector('.ai-card');
  if (targetCard && targetCard.contains(selection.anchorNode)) {
    setMenuItems({
      items: [
        { label: 'Ask AI', onClick: ({ text }) => askAI(text) },
        { label: 'Quote', onClick: ({ text }) => quoteText(text) },
      ],
      autoClear: true, // cleans up automatically on menu dismiss
    });
  }
});
```

### Hide System Actions (`removeNative: true`)

Show **only** your custom actions, hiding system defaults (Copy, Look Up, Share, etc.):

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { label: 'Send to Session', onClick: ({ text }) => send(text) },
    { label: 'Clean Copy', onClick: ({ text }) => copy(text) },
  ],
  removeNative: true, // hides native items
});
```

### Global Persistent Menu

Keep custom menu items active across all text selections throughout the app:

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { label: 'Translate', onClick: ({ text }) => translate(text) },
    { label: 'Explain', onClick: ({ text }) => explain(text) },
  ],
  autoClear: false, // keep items persistent
});
```

### Manual Reset

```typescript
import { clearMenuItems } from 'tauri-plugin-selection-menu-api';

await clearMenuItems();
```

---

## 📖 API Reference

### `setMenuItems(options)`

Configures the native selection menu items.

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `items` | `SelectionMenuItemInput[]` | **Required** | Array of items to display. |
| `removeNative` | `boolean` | `false` | Whether to hide native system items (Copy, Share, etc.). |
| `autoClear` | `boolean` | `true` | Reset to default when menu closes or item is clicked. |
| `onDismiss` | `() => void` | `undefined` | Callback invoked when the selection menu closes. |

#### `SelectionMenuItemInput`

| Field | Type | Description |
| :--- | :--- | :--- |
| `label` | `string` | Button text shown in the menu. |
| `id` | `string?` | Optional unique ID (auto-generated if omitted). |
| `onClick` | `(event: { id: string, text: string }) => void` | Callback triggered with selected text. |

### Other Functions

| Function | Signature | Description |
| :--- | :--- | :--- |
| `clearMenuItems` | `() => Promise<void>` | Clears all custom items immediately. |
| `getMenuItems` | `() => Promise<SelectionMenuItem[]>` | Gets currently configured items. |
| `onMenuItemClick` | `(handler) => Promise<PluginListener>` | Global click listener (alternative to `onClick`). |
| `onMenuDismiss` | `(handler) => Promise<PluginListener>` | Global dismiss listener (alternative to `onDismiss`). |

---

## 📄 License

Dual-licensed under MIT or Apache-2.0.
