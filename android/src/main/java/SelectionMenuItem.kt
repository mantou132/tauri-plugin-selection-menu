package com.plugin.selection_menu

import app.tauri.annotation.InvokeArg

@InvokeArg
class SelectionMenuItem {
    var id: String = ""
    var label: String = ""
    var icon: String? = null
}

@InvokeArg
class SetMenuItemsPayload {
    var items: List<SelectionMenuItem>? = null
    var removeNative: Boolean? = null
    var autoClear: Boolean? = null
}

@InvokeArg
class SetMenuItemsArgs {
    var items: List<SelectionMenuItem>? = null
    var removeNative: Boolean? = null
    var autoClear: Boolean? = null
    var payload: SetMenuItemsPayload? = null

    val resolvedItems: List<SelectionMenuItem>
        get() = items ?: payload?.items ?: emptyList()

    val resolvedRemoveNative: Boolean
        get() = removeNative ?: payload?.removeNative ?: false

    val resolvedAutoClear: Boolean
        get() = autoClear ?: payload?.autoClear ?: true
}
