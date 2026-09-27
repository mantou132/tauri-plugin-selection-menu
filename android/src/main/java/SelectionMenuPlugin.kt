package com.plugin.selection_menu

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ActionMode
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import app.tauri.annotation.Command
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin

@TauriPlugin
class SelectionMenuPlugin(private val activity: Activity) : Plugin(activity) {

    companion object {
        private const val TAG = "SelectionMenuPlugin"
    }

    private var webView: WebView? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var currentItems: List<SelectionMenuItem> = emptyList()

    @Volatile
    var removeNative: Boolean = false

    @Volatile
    var autoClear: Boolean = true

    @Volatile
    var activeActionMode: ActionMode? = null

    private var pendingDismissRunnable: Runnable? = null
    private var wasItemClicked: Boolean = false
    private var clickPending = false
    private var dismissRevision = 0
    private var configurationRevision = 0
    private var sessionActive = false

    override fun load(webView: WebView) {
        this.webView = webView
        activity.runOnUiThread {
            attachSelectionLayout(webView)
        }
    }

    private fun attachSelectionLayout(targetWebView: WebView) {
        val parent = targetWebView.parent as? ViewGroup
        if (parent != null && parent !is SelectionActionModeLayout) {
            val index = parent.indexOfChild(targetWebView)
            val layoutParams = targetWebView.layoutParams
            parent.removeView(targetWebView)

            val layout = SelectionActionModeLayout(targetWebView.context, this)
            if (layoutParams != null) {
                layout.layoutParams = layoutParams
            } else {
                layout.layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            }

            layout.addView(
                targetWebView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )

            parent.addView(layout, index)
        } else if (parent == null) {
            targetWebView.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) {
                    targetWebView.removeOnAttachStateChangeListener(this)
                    attachSelectionLayout(targetWebView)
                }

                override fun onViewDetachedFromWindow(v: View) {}
            })
        }
    }

    @Command
    fun set_menu_items(invoke: Invoke) {
        try {
            val args = invoke.parseArgs(SetMenuItemsArgs::class.java)
            activity.runOnUiThread {
                configurationRevision++
                currentItems = args.resolvedItems
                removeNative = args.resolvedRemoveNative
                autoClear = args.resolvedAutoClear
                cancelDismissCheck()
                try {
                    activeActionMode?.invalidate()
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to invalidate ActionMode", e)
                }
                invoke.resolve()
            }
        } catch (e: Exception) {
            invoke.reject(e.message, null, e, null)
        }
    }

    @Command
    fun setMenuItems(invoke: Invoke) {
        set_menu_items(invoke)
    }

    @Command
    fun get_menu_items(invoke: Invoke) {
        activity.runOnUiThread { invoke.resolveObject(currentItems) }
    }

    @Command
    fun getMenuItems(invoke: Invoke) {
        get_menu_items(invoke)
    }

    @Command
    fun clear_menu_items(invoke: Invoke) {
        activity.runOnUiThread {
            configurationRevision++
            cancelDismissCheck()
            currentItems = emptyList()
            try {
                activeActionMode?.invalidate()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to invalidate ActionMode", e)
            }
            invoke.resolve()
        }
    }

    @Command
    fun clearMenuItems(invoke: Invoke) {
        clear_menu_items(invoke)
    }

    fun handleActionModeStarting() {
        cancelDismissCheck()
    }

    fun handleActionModeStarted(mode: ActionMode) {
        cancelDismissCheck()
        // A prepare after a native action (e.g. Select All) continues selection.
        // Only a custom click still waiting for its text must survive a prepare.
        wasItemClicked = clickPending
        activeActionMode = mode
        sessionActive = true
    }

    fun handleNativeItemClicked(itemId: Int) {
        wasItemClicked = itemId != android.R.id.selectAll
    }

    fun cancelDismissCheck() {
        dismissRevision++
        pendingDismissRunnable?.let {
            mainHandler.removeCallbacks(it)
            pendingDismissRunnable = null
        }
    }

    fun handleActionModeDestroyed(mode: ActionMode) {
        if (activeActionMode !== mode) return
        activeActionMode = null
        scheduleDismissCheck(if (wasItemClicked) 100L else 350L)
    }

    private fun scheduleDismissCheck(delayMs: Long, wasCollapsed: Boolean = false) {
        cancelDismissCheck()
        val revision = dismissRevision
        val runnable = Runnable {
            if (revision != dismissRevision || !sessionActive || clickPending) return@Runnable
            pendingDismissRunnable = null
            if (activeActionMode != null) {
                return@Runnable
            }

            if (wasItemClicked) {
                wasItemClicked = false
                performDismissCleanup()
                return@Runnable
            }

            val wv = webView
            if (wv != null) {
                wv.evaluateJavascript("""
                    (() => {
                        const el = document.activeElement;
                        if (el && typeof el.selectionStart === 'number' && el.selectionStart !== el.selectionEnd) return false;
                        const selection = window.getSelection();
                        return !selection || selection.isCollapsed;
                    })()
                """.trimIndent()) { result ->
                    if (revision != dismissRevision || activeActionMode != null || !sessionActive) return@evaluateJavascript
                    val collapsed = result?.trim() == "true"
                    if (collapsed && wasCollapsed) {
                        performDismissCleanup()
                    } else {
                        // A long handle drag must not time out and clear the items.
                        scheduleDismissCheck(350L, collapsed)
                    }
                }
            } else {
                performDismissCleanup()
            }
        }
        pendingDismissRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun performDismissCleanup() {
        if (!sessionActive) return
        sessionActive = false
        cancelDismissCheck()
        if (autoClear) {
            currentItems = emptyList()
        }
        trigger("dismiss", JSObject())
    }

    fun handleItemClick(item: SelectionMenuItem, mode: ActionMode?) {
        if (clickPending) return
        clickPending = true
        wasItemClicked = true
        cancelDismissCheck()
        val configuration = configurationRevision
        val finishClick: (String) -> Unit = { text ->
            trigger("click", JSObject().apply {
                put("id", item.id)
                put("text", text)
            })
            clickPending = false
            if (configuration == configurationRevision) {
                performDismissCleanup()
            }
            try {
                mode?.finish()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to finish ActionMode", e)
            }
        }
        val wv = webView
        if (wv == null) {
            finishClick("")
        } else {
            wv.evaluateJavascript("""
                (() => {
                    const el = document.activeElement;
                    if (el && typeof el.selectionStart === 'number' && el.selectionStart !== el.selectionEnd)
                        return el.value.substring(el.selectionStart, el.selectionEnd);
                    return window.getSelection()?.toString() || '';
                })()
            """.trimIndent()) { finishClick(cleanJsResult(it)) }
        }
    }

    private fun cleanJsResult(raw: String?): String {
        if (raw == null || raw == "null") return ""
        return try {
            org.json.JSONTokener(raw).nextValue() as? String ?: ""
        } catch (e: Exception) {
            raw
        }
    }
}
