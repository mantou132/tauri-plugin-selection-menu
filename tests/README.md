# Selection menu regression checks

Run the JS callback/identity tests with `pnpm test`.

Run the iOS lifecycle tests from `ios/` (requires the local Tauri API package and an installed simulator):

```sh
xcodebuild -scheme tauri-plugin-selection-menu \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

The iOS tests control JavaScript response timing to cover stale replies after a
menu reopens or is reconfigured, temporary selection collapse, long handle drags,
JavaScript failures, click-before-dismiss ordering, duplicate dismissal, and
`autoClear: false`. These are lifecycle tests, not simulated finger gestures.

On both physical platforms, check the example app with `removeNative` on and off:

1. Select text in the special card, drag both handles for at least five seconds,
   cross the handles, and release. The custom items should remain.
2. Tap a custom item immediately after adjusting the selection. Its callback
   should run once with the adjusted text, followed by one dismissal.
3. Tap outside the selection. The items should clear after the selection ends.
4. Start another selection immediately as the old menu closes. Old cleanup must
   not remove the new items.
5. Repeat with `autoClear: false`; items and callbacks should remain available.
6. Check native Copy, Select All, Share, scrolling, and editable text fields.
7. On iOS, check both the modern delegate lifecycle (16.4+) and the legacy
   UIMenuController notification fallback on supported older OS versions.
