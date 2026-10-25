# Changelog

All notable changes to the **GestureSwitch** project will be documented in this file.

## [0.2.0] - 2026-10-25

### ✨ Added

* **Title Bar Hover Activation:** The window switcher now activates exclusively when your mouse cursor is hovering over the top 30pt title bar region of any visible window. No modifier keys are required, and it avoids interfering with normal two-finger scrolling in documents or web pages.
* **Scrollable HUD Overlay:** Replaced the static HUD layout with a vertically scrollable `NSScrollView` supporting clean navigation when a large number of windows are open.
* **Dynamic HUD Sizing:** The window switcher HUD now automatically sizes its height based on the active window count (capped at a maximum height of 500pt).

### 🐛 Fixed

* **Multi-Window App Mapping:** Resolved an accessibility bug where applications with multiple open windows (such as Safari or Terminal) would incorrectly map all entries to the application's first window instance. Windows are now correctly matched by their specific accessibility title.