import UIKit
import WebKit
import ObjectiveC
import Tauri

private var selectionMenuContextKey: UInt8 = 0
private var uiDelegateProxyKey: UInt8 = 0

struct MenuItemClickPayload: Encodable {
    let id: String
    let text: String
}

class SelectionMenuContext: NSObject {
    weak var plugin: SelectionMenuPlugin?
    var items: [SelectionMenuItem] = []
    var removeNative: Bool = false
    var autoClear: Bool = true
    var wasItemClicked: Bool = false

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

    func performDismissCleanup() {
        if autoClear {
            clear()
        }
        try? plugin?.trigger("dismiss", data: [String: String]())
    }

    func handleMenuDismissed(webview: WKWebView) {
        if wasItemClicked {
            wasItemClicked = false
            performDismissCleanup()
            return
        }

        // Check if webview selection is actually collapsed
        webview.evaluateJavaScript("window.getSelection() ? window.getSelection().isCollapsed : true") { [weak self] result, _ in
            let isCollapsed = (result as? Bool) ?? true
            if isCollapsed {
                self?.performDismissCleanup()
            }
        }
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
                guard let webview = webview, let self = self else { return }
                self.wasItemClicked = true
                webview.evaluateJavaScript("window.getSelection() ? window.getSelection().toString() : ''") { result, error in
                    let text = result as? String ?? ""
                    let payload = MenuItemClickPayload(id: item.id, text: text)
                    try? self.plugin?.trigger("click", data: payload)
                    try? self.plugin?.trigger("menuItemClick", data: payload)
                    if self.autoClear {
                        self.clear()
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
            // Apple recommended way to customize standard edit menu
            if builder.menu(for: .standardEdit) != nil {
                builder.replaceChildren(ofMenu: .standardEdit) { _ in
                    [customMenu]
                }
            } else {
                builder.insertChild(customMenu, atEndOfMenu: .root)
            }
            builder.remove(menu: .lookup)
            builder.remove(menu: .share)
            builder.remove(menu: .replace)
        }
    }
}

class SelectionMenuUIDelegateProxy: NSObject, WKUIDelegate {
    weak var originalDelegate: WKUIDelegate?
    weak var webview: WKWebView?
    private static let willDismissSelector = NSSelectorFromString("webView:willDismissEditMenuWithAnimator:")

    init(originalDelegate: WKUIDelegate?, webview: WKWebView) {
        self.originalDelegate = originalDelegate
        self.webview = webview
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if #available(iOS 16.4, *), aSelector == Self.willDismissSelector {
            return true
        }
        if let original = originalDelegate {
            return original.responds(to: aSelector)
        }
        return super.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original = originalDelegate, original.responds(to: aSelector) {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }

    @available(iOS 16.4, *)
    func webView(_ webView: WKWebView, willDismissEditMenuWithAnimator animator: UIEditMenuInteractionAnimating) {
        originalDelegate?.webView?(webView, willDismissEditMenuWithAnimator: animator)
        animator.addCompletion { [weak webView] in
            guard let webView = webView,
                  let context = SelectionMenuHook.context(for: webView) else { return }
            context.handleMenuDismissed(webview: webView)
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

        setupUIDelegateProxy(for: webview)

        // Support iOS < 16.4 via UIMenuController notification
        NotificationCenter.default.addObserver(
            forName: UIMenuController.didHideMenuNotification,
            object: nil,
            queue: .main
        ) { [weak webview] _ in
            guard let webview = webview,
                  let context = SelectionMenuHook.context(for: webview) else { return }
            context.handleMenuDismissed(webview: webview)
        }
    }

    static func setupUIDelegateProxy(for webview: WKWebView) {
        if let existing = objc_getAssociatedObject(webview, &uiDelegateProxyKey) as? SelectionMenuUIDelegateProxy {
            if webview.uiDelegate !== existing {
                existing.originalDelegate = webview.uiDelegate
                webview.uiDelegate = existing
            }
            return
        }
        let proxy = SelectionMenuUIDelegateProxy(originalDelegate: webview.uiDelegate, webview: webview)
        objc_setAssociatedObject(
            webview,
            &uiDelegateProxyKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        webview.uiDelegate = proxy
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
            cls: WKWebView.self,
            originalSelector: #selector(setter: WKWebView.uiDelegate),
            swizzledSelector: #selector(WKWebView.tauri_selectionMenu_setUIDelegate(_:))
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

    @objc func tauri_selectionMenu_setUIDelegate(_ delegate: WKUIDelegate?) {
        if let proxy = objc_getAssociatedObject(self, &uiDelegateProxyKey) as? SelectionMenuUIDelegateProxy {
            if delegate === proxy {
                self.tauri_selectionMenu_setUIDelegate(delegate)
            } else {
                proxy.originalDelegate = delegate
                self.tauri_selectionMenu_setUIDelegate(proxy)
            }
        } else {
            self.tauri_selectionMenu_setUIDelegate(delegate)
        }
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
