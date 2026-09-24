package com.plugin.selection_menu

import android.app.Activity
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

    private var webView: WebView? = null

    @Volatile
    var currentItems: List<SelectionMenuItem> = emptyList()

    @Volatile
    var removeNative: Boolean = false

    @Volatile
    var autoClear: Boolean = true

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
        invoke.resolve()
    }

    @Command
    fun clearMenuItems(invoke: Invoke) {
        clear_menu_items(invoke)
    }

    fun handleItemClick(item: SelectionMenuItem) {
        val wv = webView ?: return
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
            }
        }
    }

    fun handleActionModeDestroyed() {
        if (autoClear) {
            currentItems = emptyList()
        }
        trigger("dismiss", JSObject())
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
