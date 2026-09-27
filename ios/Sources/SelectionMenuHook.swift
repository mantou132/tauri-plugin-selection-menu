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
    weak var webview: WKWebView?
    var items: [SelectionMenuItem] = []
    var removeNative: Bool = false
    var autoClear: Bool = true
    private var dismissRevision = 0
    private var configurationRevision = 0
    private var sessionActive = false
    private var menuVisible = false
    private var clickPending = false
    private var dismissWork: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    deinit {
        dismissWork?.cancel()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func observeLegacyMenu(webview: WKWebView) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIMenuController.willShowMenuNotification,
            object: nil, queue: .main
        ) { [weak self, weak webview] _ in
            guard let webview = webview, webview.window != nil else { return }
            self?.menuPresented()
        })
        observers.append(center.addObserver(
            forName: UIMenuController.willHideMenuNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.menuVisible = false
        })
        observers.append(center.addObserver(
            forName: UIMenuController.didHideMenuNotification,
            object: nil, queue: .main
        ) { [weak self, weak webview] _ in
            guard let self = self, let webview = webview else { return }
            self.checkDismissed(webview: webview, revision: self.menuWillDismiss())
        })
    }

    init(plugin: SelectionMenuPlugin, webview: WKWebView) {
        self.plugin = plugin
        self.webview = webview
    }

    func update(items: [SelectionMenuItem], removeNative: Bool, autoClear: Bool) {
        configurationRevision += 1
        let changed = items != self.items || removeNative != self.removeNative
        self.items = items
        self.removeNative = removeNative
        self.autoClear = autoClear
        restartDismissCheck()
        if changed {
            rebuildMenu()
        }
    }

    func clear() {
        configurationRevision += 1
        cancelDismissCheck()
        let changed = !items.isEmpty
        items.removeAll()
        if changed {
            rebuildMenu()
        }
    }

    // Items usually arrive over IPC after UIKit has already built the visible
    // menu (JS reacts to selectionchange). setNeedsRebuild alone only affects
    // the next presentation, so reload the menu that is on screen right now.
    private func rebuildMenu() {
        UIMenuSystem.context.setNeedsRebuild()
        guard menuVisible, let webview = webview else { return }
        if #available(iOS 16.0, *) {
            Self.editMenuInteractions(in: webview).forEach { $0.reloadVisibleMenu() }
        } else if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.update()
        }
    }

    @available(iOS 16.0, *)
    private static func editMenuInteractions(in view: UIView) -> [UIEditMenuInteraction] {
        var result = view.interactions.compactMap { $0 as? UIEditMenuInteraction }
        for subview in view.subviews {
            result += editMenuInteractions(in: subview)
        }
        return result
    }

    // A configuration change must not clear itself through a stale check, but
    // it must not drop a pending dismissal either (e.g. setMenuItems called
    // from touchstart while the previous selection is being collapsed).
    private func restartDismissCheck() {
        let wasChecking = dismissWork != nil
        cancelDismissCheck()
        if wasChecking, let webview = webview {
            checkDismissed(webview: webview, revision: dismissRevision)
        }
    }

    private func cancelDismissCheck() {
        dismissRevision += 1
        dismissWork?.cancel()
        dismissWork = nil
    }

    func menuPresented() {
        cancelDismissCheck()
        sessionActive = true
        menuVisible = true
    }

    func menuWillDismiss() -> Int {
        cancelDismissCheck()
        menuVisible = false
        return dismissRevision
    }

    // Hiding the capsule while dragging a selection handle is not the end of
    // the selection session. Require two collapsed samples, and invalidate
    // both the timer AND any in-flight JavaScript reply on menu changes.
    func checkDismissed(webview: WKWebView, revision: Int, wasCollapsed: Bool = false) {
        guard revision == dismissRevision, sessionActive, !menuVisible, !clickPending else { return }
        let work = DispatchWorkItem { [weak self, weak webview] in
            guard let self = self, let webview = webview,
                  revision == self.dismissRevision, self.sessionActive,
                  !self.menuVisible, !self.clickPending else { return }
            webview.evaluateJavaScript("""
                (() => {
                    const el = document.activeElement;
                    if (el && typeof el.selectionStart === 'number' && el.selectionStart !== el.selectionEnd) return false;
                    const selection = window.getSelection();
                    return !selection || selection.isCollapsed;
                })()
                """) { [weak self, weak webview] result, error in
                guard let self = self, let webview = webview,
                      revision == self.dismissRevision, self.sessionActive,
                      !self.menuVisible, !self.clickPending else { return }
                // A failed query is not evidence that the selection ended.
                let collapsed = error == nil && (result as? Bool) == true
                if collapsed && wasCollapsed {
                    self.performDismissCleanup()
                } else {
                    self.checkDismissed(webview: webview, revision: revision, wasCollapsed: collapsed)
                }
            }
        }
        dismissWork?.cancel()
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func performDismissCleanup() {
        guard sessionActive else { return }
        sessionActive = false
        cancelDismissCheck()
        if autoClear {
            items.removeAll()
            UIMenuSystem.context.setNeedsRebuild()
        }
        try? plugin?.trigger("dismiss", data: [String: String]())
    }

    func handleClick(item: SelectionMenuItem, webview: WKWebView) {
        guard !clickPending else { return }
        clickPending = true
        cancelDismissCheck()
        let configuration = configurationRevision
        webview.evaluateJavaScript("""
            (() => {
                const el = document.activeElement;
                if (el && typeof el.selectionStart === 'number' && el.selectionStart !== el.selectionEnd)
                    return el.value.substring(el.selectionStart, el.selectionEnd);
                return window.getSelection()?.toString() || '';
            })()
            """) { [weak self] result, _ in
            guard let self = self else { return }
            // The JS listener must receive click before dismiss removes its callback.
            try? self.plugin?.trigger("click", data: MenuItemClickPayload(id: item.id, text: result as? String ?? ""))
            self.clickPending = false
            if configuration == self.configurationRevision {
                self.performDismissCleanup()
            }
        }
    }

    func modify(builder: UIMenuBuilder, webview: WKWebView) {
        let customMenuIdentifier = UIMenu.Identifier("com.plugin.selection_menu.custom_actions")
        if builder.menu(for: customMenuIdentifier) != nil {
            builder.remove(menu: customMenuIdentifier)
        }
        guard !items.isEmpty else { return }

        var customActions = [UIMenuElement]()
        for item in items {
            let action = UIAction(title: item.label) { [weak webview, weak self] _ in
                guard let webview = webview, let self = self else { return }
                self.handleClick(item: item, webview: webview)
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
    private static let willPresentSelector = NSSelectorFromString("webView:willPresentEditMenuWithAnimator:")
    private static let willDismissSelector = NSSelectorFromString("webView:willDismissEditMenuWithAnimator:")

    init(originalDelegate: WKUIDelegate?) {
        self.originalDelegate = originalDelegate
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if #available(iOS 16.4, *), aSelector == Self.willDismissSelector || aSelector == Self.willPresentSelector {
            return true
        }
        return super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original = originalDelegate, original.responds(to: aSelector) {
            return original
        }
        return super.forwardingTarget(for: aSelector)
    }

    @available(iOS 16.4, *)
    func webView(_ webView: WKWebView, willPresentEditMenuWithAnimator animator: UIEditMenuInteractionAnimating) {
        SelectionMenuHook.context(for: webView)?.menuPresented()
        originalDelegate?.webView?(webView, willPresentEditMenuWithAnimator: animator)
    }

    @available(iOS 16.4, *)
    func webView(_ webView: WKWebView, willDismissEditMenuWithAnimator animator: UIEditMenuInteractionAnimating) {
        if let context = SelectionMenuHook.context(for: webView) {
            let revision = context.menuWillDismiss()
            animator.addCompletion { [weak webView, weak context] in
                guard let webView = webView else { return }
                context?.checkDismissed(webview: webView, revision: revision)
            }
        }
        originalDelegate?.webView?(webView, willDismissEditMenuWithAnimator: animator)
    }
}

class SelectionMenuHook {
    private static var isHookInstalled = false
    private static let lock = NSLock()

    static func attach(webview: WKWebView, plugin: SelectionMenuPlugin) {
        installHookOnce()
        guard context(for: webview) == nil else { return }
        let context = SelectionMenuContext(plugin: plugin, webview: webview)
        objc_setAssociatedObject(
            webview,
            &selectionMenuContextKey,
            context,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        setupUIDelegateProxy(for: webview)

        if #available(iOS 16.4, *) {
            // WKUIDelegate owns the modern edit-menu lifecycle.
        } else {
            context.observeLegacyMenu(webview: webview)
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
        let proxy = SelectionMenuUIDelegateProxy(originalDelegate: webview.uiDelegate)
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
