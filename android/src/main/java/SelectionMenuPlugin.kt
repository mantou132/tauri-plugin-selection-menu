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
            this.currentItems = args.resolvedItems
            this.removeNative = args.resolvedRemoveNative
            this.autoClear = args.resolvedAutoClear
            cancelDismissCheck()
            activity.runOnUiThread {
                try {
                    activeActionMode?.invalidate()
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to invalidate ActionMode", e)
                }
            }
            invoke.resolve()
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
        invoke.resolveObject(this.currentItems)
    }

    @Command
    fun getMenuItems(invoke: Invoke) {
        get_menu_items(invoke)
    }

    @Command
    fun clear_menu_items(invoke: Invoke) {
        this.currentItems = emptyList()
        activity.runOnUiThread {
            try {
                activeActionMode?.invalidate()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to invalidate ActionMode", e)
            }
        }
        invoke.resolve()
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
        activeActionMode = mode
        wasItemClicked = false
    }

    fun handleNativeItemClicked() {
        wasItemClicked = true
    }

    fun cancelDismissCheck() {
        pendingDismissRunnable?.let {
            mainHandler.removeCallbacks(it)
            pendingDismissRunnable = null
        }
    }

    fun handleActionModeDestroyed(mode: ActionMode) {
        if (activeActionMode === mode) {
            activeActionMode = null
        }
        scheduleDismissCheck(if (wasItemClicked) 100L else 350L)
    }

    private fun scheduleDismissCheck(delayMs: Long, retryCount: Int = 0) {
        cancelDismissCheck()
        val runnable = Runnable {
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
                wv.evaluateJavascript("window.getSelection() ? !window.getSelection().isCollapsed : false") { hasSelectionRaw ->
                    val hasSelection = hasSelectionRaw?.trim() == "true"
                    if (activeActionMode == null) {
                        if (!hasSelection || retryCount >= 3) {
                            performDismissCleanup()
                        } else {
                            scheduleDismissCheck(500L, retryCount + 1)
                        }
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
        if (autoClear) {
            currentItems = emptyList()
        }
        trigger("dismiss", JSObject())
    }

    fun handleItemClick(item: SelectionMenuItem, mode: ActionMode?) {
        wasItemClicked = true
        val wv = webView
        if (wv != null) {
            activity.runOnUiThread {
                wv.evaluateJavascript("window.getSelection() ? window.getSelection().toString() : ''") { rawResult ->
                    val text = cleanJsResult(rawResult)
                    val payload = JSObject().apply {
                        put("id", item.id)
                        put("text", text)
                    }
                    trigger("click", payload)
                    trigger("menuItemClick", payload)
                    if (autoClear) {
                        currentItems = emptyList()
                    }
                    try {
                        mode?.finish()
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to finish ActionMode", e)
                    }
                }
            }
        } else {
            val payload = JSObject().apply {
                put("id", item.id)
                put("text", "")
            }
            trigger("click", payload)
            trigger("menuItemClick", payload)
            if (autoClear) {
                currentItems = emptyList()
            }
            try {
                mode?.finish()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to finish ActionMode", e)
            }
        }
    }

    private fun cleanJsResult(raw: String?): String {
        if (raw == null || raw == "null") return ""
        var str = raw.trim()
        if (str.startsWith("\"") && str.endsWith("\"") && str.length >= 2) {
            str = str.substring(1, str.length - 1)
            str = str.replace("\\\"", "\"")
                .replace("\\n", "\n")
                .replace("\\r", "\r")
                .replace("\\t", "\t")
                .replace("\\\\", "\\")
        }
        return str
    }
}
