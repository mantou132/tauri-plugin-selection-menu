# Tauri Plugin Selection Menu

[![npm version](https://img.shields.io/npm/v/tauri-plugin-selection-menu-api.svg)](https://www.npmjs.com/package/tauri-plugin-selection-menu-api)
[![License](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](LICENSE)

[English](README.md) | [简体中文](README.zh-CN.md)

专为 Tauri v2 打造的高性能移动端插件，用于在 **iOS** 与 **Android** 系统的原生划词选择浮层菜单（胶囊工具栏 / Contextual Menu）中注入自定义操作项。

适用于 AI 问答应用、笔记软件、电子书阅读器及翻译工具，直接在原生选中文本胶囊菜单中添加 **“发往新会话”**、**“笔记搜索”**、**“AI 解释”** 等功能项。

---

## ✨ 核心特性

- 📱 **纯正原生视觉与体验**：
  - **iOS**：通过官方 `UIMenuBuilder` 与 `UIAction` 注入系统 Edit Menu。
  - **Android**：基于原生 `ActionMode.TYPE_FLOATING`（悬浮工具栏）深度集成。
  - 完美继承系统的胶囊圆角、字体、触觉反馈、分页动画与无障碍辅助，绝无网页模拟层（Web Overlay）的卡顿与位移。
- 🔄 **完整支持水滴手柄拖动选区**：
  - 完美适配 Android Chromium 与 iOS WebKit 在拖动手柄时销毁并重建 Action Mode 的瞬态生命周期，拖动手柄扩展/缩小选区时自定义菜单项平滑保持，不会被系统原生菜单覆盖。
- 🧹 **自动清理机制 (`autoClear: true`)**：
  - 胶囊菜单关闭时（点击空白区域、滚动页面、点击复制或点击自定义项后）自动恢复系统默认菜单，保证页面其他未配置区域体验纯净。
- 🚫 **可选择隐藏系统原生操作 (`removeNative: true`)**：
  - 支持仅展示自定义菜单项，隐藏 Copy、Look Up、Share、Translate 等系统默认项目。
- 🎯 **可靠的选中文本提取**：
  - 在菜单项点击的原生事件触发时，第一时间从 WebView DOM 异步提取选区内容，避免因焦点转移或选区先清空导致的文本读取丢失。
- ⚡ **完备的事件体系**：
  - `onMenuItemClick`：自定义菜单项点击时接收 `{ id, text }`。
  - `onMenuDismiss`：原生浮层关闭时接收通知。

---

## 📦 支持平台

| 平台 | 最低版本要求 | 核心实现方案 |
| :--- | :--- | :--- |
| **iOS** | iOS 14.0+ (iOS 16+ 深度优化) | `UIMenuBuilder` + `WKUIDelegateProxy` |
| **Android** | API 23+ (Android 6.0+) | `ActionMode.TYPE_FLOATING` + `SelectionActionModeLayout` |
| **Desktop** | macOS / Windows / Linux | 回退状态管理 |

---

## 🚀 安装步骤

### 1. 安装前端 NPM 包

```bash
# 使用 pnpm
pnpm add tauri-plugin-selection-menu-api

# 使用 npm
npm install tauri-plugin-selection-menu-api

# 使用 yarn
yarn add tauri-plugin-selection-menu-api
```

### 2. 添加 Rust 依赖

在你的 `src-tauri/Cargo.toml` 中添加：

```toml
[dependencies]
tauri-plugin-selection-menu = "0.1"
```

或使用 Git 地址引用：

```toml
[dependencies]
tauri-plugin-selection-menu = { git = "https://github.com/mantou132/tauri-plugin-selection-menu" }
```

### 3. 在 Rust 中注册插件

在 `src-tauri/src/lib.rs`（或 `main.rs`）中注册：

```rust
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_selection_menu::init())
        .run(tauri::generate_context!())
        .expect("运行 Tauri 应用时出错");
}
```

### 4. 配置权限 Capabilities

在 Tauri 的权限配置文件中（例如 `src-tauri/capabilities/default.json`）：

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "主窗口权限配置",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "selection-menu:default"
  ]
}
```

---

## 📖 使用指南

### 1. 监听菜单点击与关闭事件

```typescript
import { onMenuItemClick, onMenuDismiss } from 'tauri-plugin-selection-menu-api';

// 监听自定义项点击
const unlistenClick = await onMenuItemClick((event) => {
  console.log(`点击菜单 ID: ${event.id}`);
  console.log(`选中的文本: "${event.text}"`);
});

// 监听原生胶囊菜单关闭
const unlistenDismiss = await onMenuDismiss(() => {
  console.log('划词菜单已关闭');
});

// 组件卸载时释放监听
// unlistenClick();
// unlistenDismiss();
```

---

### 2. 局部卡片上下文菜单（自动清理推荐用法）

在特定卡片或文本区域选中时动态配置自定义菜单，菜单关闭后自动恢复默认：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

document.addEventListener('selectionchange', () => {
  const selection = window.getSelection();
  if (!selection || selection.isCollapsed || !selection.toString().trim()) return;

  const targetCard = document.querySelector('.ai-message-card');
  if (targetCard && targetCard.contains(selection.anchorNode)) {
    // 仅在当前卡片选中文本时注入 AI 快捷操作
    setMenuItems({
      items: [
        { id: 'ask-ai', label: '发往新会话' },
        { id: 'search-notes', label: '搜索笔记' },
        { id: 'quote', label: '引用文本' },
      ],
      removeNative: false, // 保留系统的复制、分享等
      autoClear: true,     // 菜单关闭后自动清理自定义项
    });
  }
});
```

---

### 3. 全局常驻菜单

如果希望在整个 App 选中文本时始终显示固定的自定义操作：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { id: 'translate', label: '即时翻译' },
    { id: 'explain', label: 'AI 解释' },
  ],
  removeNative: false,
  autoClear: false, // 每次划词都持续生效，不自动清理
});
```

---

### 4. 隐藏系统默认项 (`removeNative: true`)

在沉浸式阅读或安全要求较高的界面中，仅展示自定义菜单：

```typescript
import { setMenuItems } from 'tauri-plugin-selection-menu-api';

await setMenuItems({
  items: [
    { id: 'safe-export', label: '安全导出' },
    { id: 'clean-copy', label: '纯文本复制' },
  ],
  removeNative: true, // 移除系统的 Copy、Lookup、Share 等
  autoClear: true,
});
```

---

### 5. 手动清理与状态查询

```typescript
import { clearMenuItems, getMenuItems } from 'tauri-plugin-selection-menu-api';

// 立即清空所有自定义菜单项
await clearMenuItems();

// 查询当前配置的菜单项
const current = await getMenuItems();
console.log('当前激活菜单:', current);
```

---

## 📚 API 参考

### 核心方法

#### `setMenuItems(options)`
配置划词浮层菜单中的自定义操作项。

```typescript
function setMenuItems(options: SetMenuItemsOptions | SelectionMenuItem[]): Promise<void>;
```

#### `getMenuItems()`
获取当前已配置的自定义菜单项列表。

```typescript
function getMenuItems(): Promise<SelectionMenuItem[]>;
```

#### `clearMenuItems()`
立即清除所有自定义菜单项。

```typescript
function clearMenuItems(): Promise<void>;
```

#### `onMenuItemClick(handler)`
监听自定义菜单项的点击事件。

```typescript
function onMenuItemClick(
  handler: (event: SelectionMenuItemClickEvent) => void
): Promise<PluginListener>;
```

#### `onMenuDismiss(handler)`
监听原生浮层菜单关闭/消失事件。

```typescript
function onMenuDismiss(
  handler: () => void
): Promise<PluginListener>;
```

---

### 类型定义

#### `SelectionMenuItem`
| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `string` | 菜单项唯一标识符。 |
| `label` | `string` | 按钮显示的文案。 |
| `icon` | `string?` | 可选图标标识符。 |

#### `SetMenuItemsOptions`
| 字段 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `items` | `SelectionMenuItem[]` | `[]` | 自定义菜单项列表。 |
| `removeNative` | `boolean` | `false` | 是否替换/移除系统默认操作（复制、查询、分享等）。 |
| `autoClear` | `boolean` | `true` | 是否在菜单关闭或点击后自动清空自定义菜单项。 |

#### `SelectionMenuItemClickEvent`
| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `string` | 被点击的菜单项 ID。 |
| `text` | `string` | 点击时被选中的文本内容。 |

---

## 🛠️ 底层架构实现

### iOS 架构
- **方法混淆（Method Swizzling）**：同时 Hook `WKWebView` 与 `UIViewController` 的 `buildMenu(with:)`，完美兼容 iOS 14 至 iOS 18+（兼容 Chromium 团队在 iOS 18.2 调整的 edit menu 派发路径）。
- **完全符合 App Store 规范**：使用公开公开的 `UIMenuBuilder` 与 `UIAction` API，通过在 `.standardEdit` 上使用 `insertSibling` / `replaceChildren` 修改菜单，杜绝使用任何私有 API。
- **精准的关闭检测**：通过 `WKUIDelegateProxy` 透明代理 WebView 的 UIDelegate，在 iOS 16.4+ 拦截 `webView(_:willDismissEditMenuWithAnimator:)`，并在低版本监听 `UIMenuController.didHideMenuNotification`，实现可靠的关闭感知与自动清理。

### Android 架构
- **零侵入式无缝装配**：插件在 `load(webView)` 生命周期内将 Tauri 的 WebView 包装进轻量级 `SelectionActionModeLayout`（继承自 `FrameLayout`），完全无需开发者继承或修改 `MainActivity`。
- **浮动工具栏拦截**：重写 `startActionModeForChild` 捕获 `ActionMode.TYPE_FLOATING`，注入 `SelectionActionModeCallback` 自定义菜单项。
- **拖动手柄防闪烁会话**：内置防抖会话管理器。当 Chromium 在拖动光标手柄时先触发 `onDestroyActionMode` 再重建时，会自动取消销毁延迟，确保手柄拖动过程中自定义菜单项不丢失。
- **安全的异步文本读取**：点击时先从 WebView 异步获取选中文本，待文本准备就绪后再完成 `actionMode.finish()`，防止选区提早坍缩导致获取空字符串。

---

## 📄 开源许可

本项目采用双重开源协议授权：
- **MIT License** ([LICENSE-MIT](LICENSE-MIT) 或 [http://opensource.org/licenses/MIT](http://opensource.org/licenses/MIT))
- **Apache License, Version 2.0** ([LICENSE-APACHE](LICENSE-APACHE) 或 [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0))
