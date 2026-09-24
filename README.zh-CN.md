# Tauri Plugin Selection Menu

[![npm version](https://img.shields.io/npm/v/tauri-plugin-selection-menu-api.svg)](https://www.npmjs.com/package/tauri-plugin-selection-menu-api)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE)

[English](README.md) | [简体中文](README.zh-CN.md)

专为 Tauri v2 打造的移动端原生划词菜单插件，支持在 **iOS** 与 **Android** 系统的原生文本选中气泡（胶囊工具栏 / Context Menu）中注入自定义操作项。

在原生选中菜单中直接加入 **“问 AI”**、**“引用文本”**、**“笔记搜索”** 等功能，原生质感，绝非网页模拟层。

---

## 📦 支持平台

| 平台 | 最低版本要求 | 底层实现方式 |
| :--- | :--- | :--- |
| **iOS** | iOS 14.0+ | `UIMenuBuilder` + 官方标准编辑菜单 |
| **Android** | Android 6.0+ (API 23+) | `ActionMode.TYPE_FLOATING` |
| **Desktop** | macOS / Windows / Linux | 状态安全回退（无报错） |

---

## 🚀 安装配置

### 1. 安装前端 NPM 包

```bash
pnpm add tauri-plugin-selection-menu-api
# 或 npm install tauri-plugin-selection-menu-api
```

### 2. 添加 Rust 依赖

在 `src-tauri/Cargo.toml` 中添加：

```toml
[dependencies]
tauri-plugin-selection-menu = "0.1"
```

### 3. 在 Rust 中注册插件

在 `src-tauri/src/lib.rs`（或 `main.rs`）中：

```rust
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_selection_menu::init())
        .run(tauri::generate_context!())
        .expect("运行 Tauri 应用出错");
}
```

### 4. 配置权限 Permissions

在 `src-tauri/capabilities/default.json` 中加入权限：

```json
{
  "permissions": [
    "core:default",
    "selection-menu:default"
  ]
}
```

---

## 💡 快速上手

直接配置菜单项与 `onClick` 回调，选中文本 `{ text }` 直接获取：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    {
      label: '问 AI',
      onClick: ({ text }) => {
        console.log('选中文本:', text);
      },
    },
    {
      label: '搜索笔记',
      onClick: ({ text }) => {
        searchInNotes(text);
      },
    },
  ],
});
```

---

## 🎯 常用场景

### 1. 局部卡片划词（自动清理）

在特定卡片或区域选中文本时动态设置。配合 `autoClear: true`（默认），菜单关闭后自动恢复系统默认：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

document.addEventListener('selectionchange', () => {
  const selection = window.getSelection();
  if (!selection || selection.isCollapsed || !selection.toString().trim()) return;

  const targetCard = document.querySelector('.ai-card');
  if (targetCard && targetCard.contains(selection.anchorNode)) {
    setMenuItems({
      items: [
        { label: '问 AI', onClick: ({ text }) => askAI(text) },
        { label: '引用', onClick: ({ text }) => quoteText(text) },
      ],
      autoClear: true, // 菜单关闭时自动清理，恢复系统默认
    });
  }
});
```

### 2. 隐藏系统默认操作（`removeNative: true`）

仅展示自定义按钮，隐藏系统默认项（复制、查询、分享等）：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { label: '发往会话', onClick: ({ text }) => send(text) },
    { label: '纯文本复制', onClick: ({ text }) => copy(text) },
  ],
  removeNative: true, // 隐藏原生复制/分享等项
});
```

### 3. 全局常驻菜单

在整个 App 内所有选中文本的位置都显示固定操作：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { label: '即时翻译', onClick: ({ text }) => translate(text) },
    { label: 'AI 解释', onClick: ({ text }) => explain(text) },
  ],
  autoClear: false, // 持续生效，不自动清理
});
```

### 4. 手动清空

```typescript
import { clearMenuItems } from 'tauri-plugin-selection-menu-api';

await clearMenuItems();
```

---

## 📖 API 参考

### `setMenuItems(options)`

配置原生划词菜单项。

| 参数 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `items` | `SelectionMenuItemInput[]` | **必填** | 菜单项列表。 |
| `removeNative` | `boolean` | `false` | 是否隐藏系统默认操作（复制、分享等）。 |
| `autoClear` | `boolean` | `true` | 菜单关闭或点击后是否自动重置回系统默认。 |
| `onDismiss` | `() => void` | `undefined` | 划词菜单关闭时的回调函数。 |

#### `SelectionMenuItemInput`

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `label` | `string` | 菜单按钮上展示的文案（必填）。 |
| `id` | `string?` | 菜单项唯一标识（可选，不传会自动生成）。 |
| `onClick` | `(event: { id: string, text: string }) => void` | 点击回调，参数直接包含选中文本 `{ text }`。 |

### 辅助方法

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `clearMenuItems` | `() => Promise<void>` | 立即清空所有自定义菜单项。 |
| `getMenuItems` | `() => Promise<SelectionMenuItem[]>` | 获取当前已配置的自定义菜单项。 |
| `onMenuItemClick` | `(handler) => Promise<PluginListener>` | 全局点击监听（除 `onClick` 外的备选方式）。 |
| `onMenuDismiss` | `(handler) => Promise<PluginListener>` | 全局关闭监听（除 `onDismiss` 外的备选方式）。 |

---

## 📄 开源许可

基于 MIT 或 Apache-2.0 协议双重授权。
