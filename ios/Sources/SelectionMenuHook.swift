import UIKit
import WebKit
import ObjectiveC

private var selectionMenuContextKey: UInt8 = 0

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

        var customActions = [UIMenuElement]()
        for item in items {
            let action = UIAction(title: item.label) { [weak webview, weak self] _ in
                guard let webview = webview else { return }
                webview.evaluateJavaScript("window.getSelection() ? window.getSelection().toString() : ''") { result, error in
                    let text = result as? String ?? ""
                    let payload: [String: Any] = [
                        "id": item.id,
                        "text": text
                    ]
                    self?.plugin?.trigger("click", data: payload)
                    self?.plugin?.trigger("menuItemClick", data: payload)
                    if self?.autoClear == true {
                        self?.clear()
                    }
                }
            }
            customActions.append(action)
        }

        if !removeNative {
            builder.insertElements(customActions, atEndOfMenu: .standardEdit)
        } else {
            builder.replaceChildren(ofMenu: .standardEdit) { _ in
                return customActions
            }
            builder.remove(menu: .lookup)
            builder.remove(menu: .share)
            builder.remove(menu: .replace)
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

        let originalSelector = Selector(("buildMenuWithBuilder:"))
        let swizzledSelector = #selector(WKWebView.tauri_selectionMenu_buildMenu(with:))

        guard let originalMethod = class_getInstanceMethod(WKWebView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(WKWebView.self, swizzledSelector) else {
            return
        }

        let didAddMethod = class_addMethod(
            WKWebView.self,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            class_replaceMethod(
                WKWebView.self,
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
        // 1. Call original WKWebView implementation
        self.tauri_selectionMenu_buildMenu(with: builder)

        // 2. Not managed by this plugin, return
        guard let context = SelectionMenuHook.context(for: self) else {
            return
        }

        // 3. Only handle contextual menu
        guard builder.system == .context else {
            return
        }

        // 4. Modify selection menu
        context.modify(builder: builder, webview: self)
    }
}
