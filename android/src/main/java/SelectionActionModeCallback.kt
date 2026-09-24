package com.plugin.selection_menu

import android.graphics.Rect
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.View

class SelectionActionModeCallback(
    private val wrapped: ActionMode.Callback,
    private val plugin: SelectionMenuPlugin
) : ActionMode.Callback2() {

    companion object {
        const val CUSTOM_GROUP_ID = 889900
        const val CUSTOM_ITEM_ID_OFFSET = 500000
    }

    override fun onGetContentRect(mode: ActionMode?, view: View?, outRect: Rect?) {
        if (wrapped is ActionMode.Callback2) {
            wrapped.onGetContentRect(mode, view, outRect)
        } else {
            super.onGetContentRect(mode, view, outRect)
        }
    }

    override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
        plugin.handleActionModeStarted(mode)
        val result = wrapped.onCreateActionMode(mode, menu)
        val items = plugin.currentItems
        if (items.isNotEmpty()) {
            if (plugin.removeNative) {
                menu.clear()
            }
            populateCustomItems(menu, items)
            return true
        }
        return result
    }

    override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean {
        plugin.handleActionModeStarted(mode)
        val result = wrapped.onPrepareActionMode(mode, menu)
        val items = plugin.currentItems
        menu.removeGroup(CUSTOM_GROUP_ID)
        if (items.isNotEmpty()) {
            if (plugin.removeNative) {
                val toRemove = mutableListOf<Int>()
                for (i in 0 until menu.size()) {
                    val item = menu.getItem(i)
                    if (item.groupId != CUSTOM_GROUP_ID) {
                        toRemove.add(item.itemId)
                    }
                }
                for (id in toRemove) {
                    menu.removeItem(id)
                }
            }
            populateCustomItems(menu, items)
            return true
        }
        return result
    }

    private fun populateCustomItems(menu: Menu, items: List<SelectionMenuItem>) {
        menu.removeGroup(CUSTOM_GROUP_ID)
        for ((index, item) in items.withIndex()) {
            val menuItem = menu.add(
                CUSTOM_GROUP_ID,
                CUSTOM_ITEM_ID_OFFSET + index,
                Menu.NONE,
                item.label
            )
            menuItem.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        }
    }

    override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
        if (item.groupId == CUSTOM_GROUP_ID) {
            val index = item.itemId - CUSTOM_ITEM_ID_OFFSET
            val items = plugin.currentItems
            if (index in items.indices) {
                plugin.handleItemClick(items[index], mode)
            } else {
                mode.finish()
            }
            return true
        }
        plugin.handleNativeItemClicked()
        return wrapped.onActionItemClicked(mode, item)
    }

    override fun onDestroyActionMode(mode: ActionMode) {
        wrapped.onDestroyActionMode(mode)
        plugin.handleActionModeDestroyed(mode)
    }
}
