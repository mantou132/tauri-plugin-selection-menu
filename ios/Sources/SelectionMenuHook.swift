import UIKit
import WebKit
import ObjectiveC
import Tauri

private var selectionMenuContextKey: UInt8 = 0

struct MenuItemClickPayload: Encodable {
    let id: String
    let text: String
}

class SelectionMenuContext: NSObject {
    weak var plugin: SelectionMenuPlugin?
    var items: [SelectionMenuItem] = []
    var removeNative: Bool = false
    var autoClear: Bool = true

    init(plugin: SelectionMenuPlugin) {
        self.plugin = plugin
    }

    func update(items: [SelectionMenuItem], removeNative: Bool, autoClear: Bool) {
        self.items = items
        self.removeNative = removeNative
        self.autoClear = autoClear
    }

    func clear() {
        self.items.removeAll()
    }

    func modify(builder: UIMenuBuilder, webview: WKWebView) {
        guard !items.isEmpty else { return }

        let customMenuIdentifier = UIMenu.Identifier("com.plugin.selection_menu.custom_actions")
        if builder.menu(for: customMenuIdentifier) != nil {
            return
        }

        var customActions = [UIMenuElement]()
        for item in items {
            let action = UIAction(title: item.label) { [weak webview, weak self] _ in
                guard let webview = webview else { return }
                webview.evaluateJavaScript("window.getSelection() ? window.getSelection().toString() : ''") { result, error in
                    let text = result as? String ?? ""
                    let payload = MenuItemClickPayload(id: item.id, text: text)
                    try? self?.plugin?.trigger("click", data: payload)
                    try? self?.plugin?.trigger("menuItemClick", data: payload)
                    if self?.autoClear == true {
                        self?.clear()
                    }
                }
            }
            customActions.append(action)
        }

        let customMenu = UIMenu(title: "", identifier: customMenuIdentifier, options: .displayInline, children: customActions)

        if !removeNative {
            if builder.menu(for: .standardEdit) != nil {
                builder.insertSibling(customMenu, afterMenu: .standardEdit)
            } else {
                builder.insertChild(customMenu, atEndOfMenu: .root)
            }
        } else {
            builder.remove(menu: .standardEdit)
            builder.remove(menu: .lookup)
            builder.remove(menu: .share)
            builder.remove(menu: .replace)
            builder.insertChild(customMenu, atEndOfMenu: .root)
        }
    }
}

class SelectionMenuHook {
    private static var isHookInstalled = false
    private static let lock = NSLock()

    static func attach(webview: WKWebView, plugin: SelectionMenuPlugin) {
        installHookOnce()
        let context = SelectionMenuContext(plugin: plugin)
        objc_setAssociatedObject(
            webview,
            &selectionMenuContextKey,
            context,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    static func context(for webview: WKWebView) -> SelectionMenuContext? {
        return objc_getAssociatedObject(webview, &selectionMenuContextKey) as? SelectionMenuContext
    }

    private static func installHookOnce() {
        lock.lock()
        defer { lock.unlock() }

        guard !isHookInstalled else { return }
        isHookInstalled = true

        swizzle(
            cls: WKWebView.self,
            originalSelector: #selector(WKWebView.buildMenu(with:)),
            swizzledSelector: #selector(WKWebView.tauri_selectionMenu_buildMenu(with:))
        )

        swizzle(
            cls: UIViewController.self,
            originalSelector: #selector(UIViewController.buildMenu(with:)),
            swizzledSelector: #selector(UIViewController.tauri_selectionMenu_vc_buildMenu(with:))
        )
    }

    private static func swizzle(cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
            return
        }

        let didAddMethod = class_addMethod(
            cls,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            class_replaceMethod(
                cls,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

extension WKWebView {
    @objc func tauri_selectionMenu_buildMenu(with builder: UIMenuBuilder) {
        self.tauri_selectionMenu_buildMenu(with: builder)

        guard let context = SelectionMenuHook.context(for: self) else {
            return
        }

        guard builder.system == .context else {
            return
        }

        context.modify(builder: builder, webview: self)
    }
}

extension UIViewController {
    @objc func tauri_selectionMenu_vc_buildMenu(with builder: UIMenuBuilder) {
        self.tauri_selectionMenu_vc_buildMenu(with: builder)

        guard builder.system == .context else {
            return
        }

        guard let webview = tauri_selectionMenu_findWKWebView(in: self.view) else {
            return
        }

        guard let context = SelectionMenuHook.context(for: webview) else {
            return
        }

        context.modify(builder: builder, webview: webview)
    }

    private func tauri_selectionMenu_findWKWebView(in root: UIView?) -> WKWebView? {
        guard let root = root else { return nil }
        if let wk = root as? WKWebView {
            return wk
        }
        for subview in root.subviews {
            if let found = tauri_selectionMenu_findWKWebView(in: subview) {
                return found
            }
        }
        return nil
    }
}
