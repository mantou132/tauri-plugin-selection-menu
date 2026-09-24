package com.plugin.selection_menu

import app.tauri.annotation.InvokeArg

@InvokeArg
class SelectionMenuItem {
    var id: String = ""
    var label: String = ""
}

@InvokeArg
class SetMenuItemsArgs {
    var items: List<SelectionMenuItem>? = null
    var removeNative: Boolean? = null
    var autoClear: Boolean? = null

    val resolvedItems: List<SelectionMenuItem>
        get() = items ?: emptyList()

    val resolvedRemoveNative: Boolean
        get() = removeNative ?: false

    val resolvedAutoClear: Boolean
        get() = autoClear ?: true
}
