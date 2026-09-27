import XCTest
import WebKit
import Tauri
@testable import tauri_plugin_selection_menu

private class ControlledWebView: WKWebView {
    var replies: [(Any?, Error?) -> Void] = []

    override func evaluateJavaScript(_ script: String, completionHandler: (@MainActor @Sendable (Any?, Error?) -> Void)? = nil) {
        if let completionHandler = completionHandler { replies.append(completionHandler) }
    }

    func reply(_ result: Any?, error: Error? = nil) {
        XCTAssertFalse(replies.isEmpty)
        guard !replies.isEmpty else { return }
        replies.removeFirst()(result, error)
    }
}

final class SelectionMenuTests: XCTestCase {
    private var plugin: SelectionMenuPlugin!
    private var context: SelectionMenuContext!
    private var webview: ControlledWebView!
    private var events: [String] = []
    private let item = SelectionMenuItem(id: "quote", label: "Quote")

    override func setUp() {
        super.setUp()
        plugin = SelectionMenuPlugin()
        webview = ControlledWebView()
        context = SelectionMenuContext(plugin: plugin)
        context.update(items: [item], removeNative: false, autoClear: true)
        context.menuPresented()
        events = []
        for event in ["click", "dismiss"] {
            let invoke = Invoke(command: "registerListener", callback: 0, error: 1,
                sendResponse: { id, _ in XCTAssertEqual(id, 0) },
                sendChannelData: { [weak self] _, _ in self?.events.append(event) },
                data: "{\"event\":\"\(event)\",\"handler\":\"__CHANNEL__:1\"}")
            let selector = NSSelectorFromString("registerListener:error:")
            typealias Register = @convention(c) (AnyObject, Selector, Invoke, UnsafeMutablePointer<NSError?>) -> Void
            let register = unsafeBitCast(plugin.method(for: selector), to: Register.self)
            var error: NSError?
            register(plugin, selector, invoke, &error)
            XCTAssertNil(error)
        }
    }

    override func tearDown() {
        context.clear()
        context = nil
        webview = nil
        plugin = nil
        super.tearDown()
    }

    private func nextProbe() {
        let ready = expectation(description: "dismiss probe")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { ready.fulfill() }
        wait(for: [ready], timeout: 2)
    }

    private func dismiss() {
        context.checkDismissed(webview: webview, revision: context.menuWillDismiss())
        nextProbe()
    }

    func testOldSelectionReplyCannotClearReopenedMenu() {
        dismiss()
        context.menuPresented()
        webview.reply(true)
        nextProbe()
        XCTAssertEqual(context.items.count, 1)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(webview.replies.isEmpty)
    }

    func testOldSelectionReplyCannotClearNewConfiguration() {
        dismiss()
        context.update(items: [SelectionMenuItem(id: "new", label: "New")], removeNative: false, autoClear: true)
        webview.reply(true)
        nextProbe()
        XCTAssertEqual(context.items.first?.id, "new")
        XCTAssertTrue(events.isEmpty)
    }

    func testTransientCollapseAndLongDragPreserveItems() {
        dismiss()
        webview.reply(true)
        // The selection becomes nonempty again before collapse is confirmed.
        for _ in 0..<7 {
            nextProbe()
            webview.reply(false)
        }
        XCTAssertEqual(context.items.count, 1)
        XCTAssertTrue(events.isEmpty)
        nextProbe()
        webview.reply(true)
        nextProbe()
        webview.reply(true)
        XCTAssertTrue(context.items.isEmpty)
        XCTAssertEqual(events, ["dismiss"])
    }

    func testJavaScriptErrorDoesNotMeanSelectionEnded() {
        dismiss()
        webview.reply(nil, error: NSError(domain: "WebKit", code: 1))
        nextProbe()
        webview.reply(true)
        XCTAssertEqual(context.items.count, 1)
        nextProbe()
        webview.reply(true)
        XCTAssertEqual(events, ["dismiss"])
    }

    func testDismissWaitsForClickAndEmitsOnlyOnce() {
        context.handleClick(item: item, webview: webview)
        dismiss()
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(context.items.count, 1)
        webview.reply("selected text")
        XCTAssertEqual(events, ["click", "dismiss"])
        XCTAssertTrue(context.items.isEmpty)
        dismiss()
        XCTAssertEqual(events, ["click", "dismiss"])
    }

    func testPersistentItemsSurviveClickAndDismiss() {
        context.update(items: [item], removeNative: true, autoClear: false)
        context.handleClick(item: item, webview: webview)
        webview.reply("text")
        XCTAssertEqual(context.items.count, 1)
        XCTAssertEqual(events, ["click", "dismiss"])
        context.menuPresented()
        dismiss()
        webview.reply(true)
        nextProbe()
        webview.reply(true)
        XCTAssertEqual(context.items.count, 1)
        XCTAssertEqual(events, ["click", "dismiss", "dismiss"])
    }

    func testProxySupportsNSObjectAndMenuLifecycleMethods() {
        let original = NSObject()
        let proxy = SelectionMenuUIDelegateProxy(originalDelegate: nil)
        XCTAssertTrue(proxy.responds(to: NSSelectorFromString("description")))
        XCTAssertEqual(proxy.isKind(of: NSObject.self), original.isKind(of: NSObject.self))
        if #available(iOS 16.4, *) {
            XCTAssertTrue(proxy.responds(to: NSSelectorFromString("webView:willPresentEditMenuWithAnimator:")))
            XCTAssertTrue(proxy.responds(to: NSSelectorFromString("webView:willDismissEditMenuWithAnimator:")))
        }
    }
}
