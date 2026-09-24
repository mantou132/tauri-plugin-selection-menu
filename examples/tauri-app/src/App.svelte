<script>
  import { onMount } from 'svelte';
  import {
    setMenuItems,
    getMenuItems,
    clearMenuItems,
    onMenuItemClick,
    onMenuDismiss,
  } from 'tauri-plugin-selection-menu-api';

  let logs = $state([]);
  let currentActiveItems = $state([]);
  let removeNativeEnabled = $state(false);

  function addLog(msg) {
    const time = new Date().toLocaleTimeString();
    logs = [{ id: Date.now() + Math.random(), text: `[${time}] ${msg}` }, ...logs.slice(0, 19)];
  }

  onMount(() => {
    let unlistenClick;
    let unlistenDismiss;

    (async () => {
      try {
        unlistenClick = await onMenuItemClick((event) => {
          addLog(`👉 点击自定义菜单: ID="${event.id}", 选中文字="${event.text}"`);
        });

        unlistenDismiss = await onMenuDismiss(() => {
          addLog(`🔒 菜单已关闭 (Dismiss)`);
        });

        addLog('✅ selection-menu 事件监听器已就绪');
      } catch (err) {
        addLog(`❌ 注册监听器失败: ${err}`);
      }
    })();

    const onSelectionChange = () => {
      const selection = window.getSelection();
      if (!selection || selection.isCollapsed || !selection.toString().trim()) return;
      const anchorNode = selection.anchorNode;
      const specialCard = document.querySelector('.special-card');
      if (specialCard && anchorNode && specialCard.contains(anchorNode)) {
        handleCardLongPressOrContext();
      }
    };
    document.addEventListener('selectionchange', onSelectionChange);

    return () => {
      if (unlistenClick) unlistenClick.then((u) => u());
      if (unlistenDismiss) unlistenDismiss.then((u) => u());
      document.removeEventListener('selectionchange', onSelectionChange);
    };
  });

  // 场景 A：长按或划词自动注入专享菜单，直接使用 onClick 回调，关闭自动清理
  async function handleCardLongPressOrContext(e) {
    try {
      await setMenuItems(
        [
          {
            label: 'Ask in New Session',
            onClick: ({ text }) => {
              addLog(`💬 [onClick] 发往新会话: "${text}"`);
            },
          },
          {
            label: 'Search in Notes',
            onClick: ({ text }) => {
              addLog(`🔍 [onClick] 搜索笔记: "${text}"`);
            },
          },
          {
            label: 'Quote Selection',
            onClick: ({ text }) => {
              addLog(`📝 [onClick] 引用内容: "${text}"`);
            },
          },
        ],
        {
          removeNative: removeNativeEnabled,
          autoClear: true,
          onDismiss: () => {
            addLog(`🔒 [onDismiss] 专享菜单已关闭`);
          },
        },
      );
      addLog('✨ 已注入专享菜单 (带 onClick 回调)');
      checkCurrentItems();
    } catch (err) {
      addLog(`❌ 注入菜单失败: ${err}`);
    }
  }

  async function checkCurrentItems() {
    try {
      const items = await getMenuItems();
      currentActiveItems = items;
      addLog(`📋 当前生效自定义项目: ${items.map((i) => i.label).join(', ') || '(空)'}`);
    } catch (err) {
      addLog(`❌ 获取项目失败: ${err}`);
    }
  }

  async function handleClear() {
    try {
      await clearMenuItems();
      currentActiveItems = [];
      addLog('🧹 已手动清空自定义菜单 (clearMenuItems)');
    } catch (err) {
      addLog(`❌ 清空菜单失败: ${err}`);
    }
  }

  async function handleGlobalSet() {
    try {
      await setMenuItems({
        items: [
          { id: 'global-translate', label: 'My Translate' },
          { id: 'global-export', label: 'Export Text' },
        ],
        removeNative: removeNativeEnabled,
        autoClear: false,
      });
      addLog('🌐 已设置全局常驻菜单 (autoClear=false)');
      checkCurrentItems();
    } catch (err) {
      addLog(`❌ 设置全局失败: ${err}`);
    }
  }
</script>

<main class="container">
  <h1>Tauri Selection Menu 插件演示</h1>

  <!-- 场景 A：卡片专享菜单 (对应用户原图设计) -->
  <div
    class="demo-card special-card"
    role="region"
    aria-label="场景 A 专享测试卡片"
    oncontextmenu={handleCardLongPressOrContext}
    onpointerdown={handleCardLongPressOrContext}
    ontouchstart={handleCardLongPressOrContext}
  >
    <div class="card-header">
      <span class="icon">🎯</span>
      <strong>场景 A: 在 Web 的 contextmenu (长按自动注入，关闭自动清理)</strong>
    </div>
    <p class="card-content">
      在此卡片区域内长按或右键选择文本，将自动注入卡片专享菜单（包含 <em>Ask in New Session</em>, <em>Search in Notes</em>）。菜单关闭或点击后会自动清理恢复默认，不影响其他普通区域！
    </p>
  </div>

  <!-- 普通文本对比区域 -->
  <div class="demo-card normal-card">
    <div class="card-header">
      <span class="icon">📄</span>
      <strong>普通区域 (默认系统行为)</strong>
    </div>
    <p class="card-content">
      这里的文本供对比测试：在此区域长按选择文本时，如果场景 A 已经自动清理，则只会展示系统默认的 Copy、Share、Select all 等标准胶囊菜单。
    </p>
  </div>

  <!-- 控制与配置 -->
  <div class="controls-panel">
    <h3>⚙️ 配置与控制</h3>
    <div class="switch-row">
      <label>
        <input type="checkbox" bind:checked={removeNativeEnabled} />
        尽可能移除原生选项 (removeNative: true)
      </label>
    </div>

    <div class="button-row">
      <button onclick={handleGlobalSet}>设置常驻菜单</button>
      <button onclick={handleClear}>清空菜单 (clearMenuItems)</button>
      <button onclick={checkCurrentItems}>查看当前菜单</button>
    </div>
  </div>

  <!-- 实时日志 -->
  <div class="log-panel">
    <div class="log-header">
      <h3>📡 实时事件与回调</h3>
      <button onclick={() => (logs = [])}>清空日志</button>
    </div>
    <div class="log-list">
      {#if logs.length === 0}
        <div class="log-empty">等待操作中... 在上方卡片内长按或选择文字测试</div>
      {/if}
      {#each logs as log (log.id)}
        <div class="log-item">{log.text}</div>
      {/each}
    </div>
  </div>
</main>

<style>
  :global(body) {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background-color: #f7f9fc;
    color: #1a1a1a;
    -webkit-user-select: none;
    user-select: none;
  }

  .container {
    max-width: 600px;
    margin: 0 auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  h1 {
    font-size: 1.3rem;
    text-align: center;
    margin: 8px 0;
  }

  h3 {
    margin: 0 0 8px 0;
    font-size: 1rem;
  }

  .demo-card {
    background: #ffffff;
    border-radius: 12px;
    padding: 16px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
    /* 允许文本选中以便测试 */
    -webkit-user-select: text;
    user-select: text;
  }

  .special-card {
    border: 2px dashed #4b70e2;
    background-color: #f0f4ff;
  }

  .normal-card {
    border: 1px solid #e2e8f0;
  }

  .card-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
    font-size: 0.95rem;
  }

  .card-content {
    margin: 0;
    line-height: 1.6;
    font-size: 0.95rem;
  }

  .controls-panel {
    background: #ffffff;
    border-radius: 12px;
    padding: 16px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  }

  .switch-row {
    margin-bottom: 12px;
    font-size: 0.9rem;
  }

  .switch-row label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }

  .button-row {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  button {
    background: #4b70e2;
    color: white;
    border: none;
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 0.85rem;
    cursor: pointer;
    font-weight: 500;
  }

  button:active {
    background: #3655b3;
  }

  .log-panel {
    background: #1e1e2e;
    color: #cdd6f4;
    border-radius: 12px;
    padding: 14px;
    font-family: monospace;
    font-size: 0.82rem;
  }

  .log-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }

  .log-header h3 {
    margin: 0;
    color: #89b4fa;
  }

  .log-header button {
    background: #313244;
    padding: 4px 8px;
    font-size: 0.75rem;
  }

  .log-list {
    max-height: 180px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .log-item {
    word-break: break-all;
    line-height: 1.4;
  }

  .log-empty {
    color: #6c7086;
    font-style: italic;
  }
</style>
