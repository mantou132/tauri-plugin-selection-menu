package com.plugin.selection_menu

import android.annotation.TargetApi
import android.content.Context
import android.os.Build
import android.util.AttributeSet
import android.view.ActionMode
import android.view.View
import android.widget.FrameLayout

class SelectionActionModeLayout @JvmOverloads constructor(
    context: Context,
    private val plugin: SelectionMenuPlugin? = null,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    @TargetApi(Build.VERSION_CODES.M)
    override fun startActionModeForChild(
        originalView: View,
        callback: ActionMode.Callback,
        type: Int
    ): ActionMode? {
        val activePlugin = plugin
        if (activePlugin != null && type == ActionMode.TYPE_FLOATING) {
            val wrapped = SelectionActionModeCallback(callback, activePlugin)
            return super.startActionModeForChild(originalView, wrapped, type)
        }
        return super.startActionModeForChild(originalView, callback, type)
    }

    override fun startActionModeForChild(
        originalView: View,
        callback: ActionMode.Callback
    ): ActionMode? {
        val activePlugin = plugin
        if (activePlugin != null) {
            val wrapped = SelectionActionModeCallback(callback, activePlugin)
            return super.startActionModeForChild(originalView, wrapped)
        }
        return super.startActionModeForChild(originalView, callback)
    }
}
