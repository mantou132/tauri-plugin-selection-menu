import SwiftRs
import Tauri
import UIKit
import WebKit

struct SelectionMenuItem: Codable {
    let id: String
    let label: String
}

struct SetMenuItemsPayload: Codable {
    let items: [SelectionMenuItem]?
    let removeNative: Bool?
    let autoClear: Bool?
}

struct SetMenuItemsArgs: Codable {
    let items: [SelectionMenuItem]?
    let removeNative: Bool?
    let autoClear: Bool?
    let payload: SetMenuItemsPayload?

    var resolvedItems: [SelectionMenuItem] {
        return items ?? payload?.items ?? []
    }

    var resolvedRemoveNative: Bool {
        return removeNative ?? payload?.removeNative ?? false
    }

    var resolvedAutoClear: Bool {
        return autoClear ?? payload?.autoClear ?? true
    }
}

class SelectionMenuPlugin: Plugin {
    weak var webview: WKWebView?

    @objc override public func load(webview: WKWebView) {
        self.webview = webview
        SelectionMenuHook.attach(webview: webview, plugin: self)
    }

    @objc public func set_menu_items(_ invoke: Invoke) throws {
        let args = try invoke.parseArgs(SetMenuItemsArgs.self)
        guard let webview = self.webview,
              let context = SelectionMenuHook.context(for: webview) else {
            invoke.resolve()
            return
        }
        context.update(
            items: args.resolvedItems,
            removeNative: args.resolvedRemoveNative,
            autoClear: args.resolvedAutoClear
        )
        invoke.resolve()
    }

    @objc public func setMenuItems(_ invoke: Invoke) throws {
        try set_menu_items(invoke)
    }

    @objc public func get_menu_items(_ invoke: Invoke) throws {
        guard let webview = self.webview,
              let context = SelectionMenuHook.context(for: webview) else {
            invoke.resolve([SelectionMenuItem]())
            return
        }
        invoke.resolve(context.items)
    }

    @objc public func getMenuItems(_ invoke: Invoke) throws {
        try get_menu_items(invoke)
    }

    @objc public func clear_menu_items(_ invoke: Invoke) throws {
        guard let webview = self.webview,
              let context = SelectionMenuHook.context(for: webview) else {
            invoke.resolve()
            return
        }
        context.clear()
        invoke.resolve()
    }

    @objc public func clearMenuItems(_ invoke: Invoke) throws {
        try clear_menu_items(invoke)
    }
}

@_cdecl("init_plugin_selection_menu")
func initPlugin() -> Plugin {
    return SelectionMenuPlugin()
}
