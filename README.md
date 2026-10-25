# GestureSwitch 🚀

**GestureSwitch** is a lightweight, native macOS menu bar utility that lets you effortlessly cycle through your open application windows using smooth horizontal trackpad swipe gestures, complete with a gorgeous native HUD overlay.

---

## ✨ Features

* **Gesture-Powered Window Switching:** Swipe horizontally across your trackpad to instantly bring up the window switcher HUD.
* **Hold-to-Browse:** Pause or hold your fingers on the trackpad to comfortably browse your open windows list without premature switching.
* **Sleek HUD Overlay:** A native macOS dark-themed floating panel with real-time selection highlights.
* **Menu Bar Status Item:** Easily check status, enable/disable the gesture engine on the fly, or toggle gesture logging.
* **Real-Time Gesture Logs:** Built-in log window to inspect trackpad events, active window counts, and switching states in real time.
* **Custom App Icon & Build Automation:** Includes a self-contained build script that automatically generates a high-res app icon and bundles the app properly.

---

## 📋 Prerequisites

* **macOS 14.0+** (Sonoma or later recommended)
* **Swift Command Line Tools** (Xcode Command Line Tools installed via `xcode-select --install`)
* **Accessibility Permissions** (Required for macOS to monitor trackpad gestures and manage windows)

---

## 🛠️ Installation & Building

1. Clone or place all project files (`GestureSwitch.swift`, `Info.plist`, and `build.sh`) into a local directory.
2. Open your Terminal and navigate to that directory:
```bash
cd /path/to/GestureSwitch

```

3. Make the build script executable:
```bash
chmod +x build.sh

```


4. Run the build script:
```bash
./build.sh

```


5. Launch your newly compiled app bundle:
```bash
open GestureSwitch.app

```



---

## ⚙️ First-Time Permission Setup

When you launch `GestureSwitch.app` for the first time, macOS will prompt you to grant Accessibility permissions:

1. Click **Open System Settings** when the alert appears.
2. Navigate to **Privacy & Security > Accessibility**.
3. Toggle **GestureSwitch** ON.
4. Restart the app (`open GestureSwitch.app`).

---

## 💡 How to Use

* **Switch Windows:** Swipe horizontally with two fingers across your trackpad. The window switcher HUD will appear.
* **Browse:** Keep your fingers resting on the trackpad or pause briefly to hold your position in the switcher list.
* **Commit Selection:** Lift your fingers to switch to the highlighted window, or click anywhere / press `Enter` to commit immediately.
* **Menu Bar Controls:** Click the GestureSwitch icon in your macOS menu bar to:
* Enable or Disable the engine.
* Turn gesture logging on or off.
* Open the live **Gesture Log** window.
* Quit the app.



---

## 🎛️ Customizing Sensitivity & Thresholds

You can fine-tune how fast or sensitive the swipe gestures feel by editing the configuration variables inside **`GestureSwitch.swift`** (under the `SwishGestureEngine` class):

1. **`swipeThreshold` (Default: `30.0`)**
* Controls how much movement is required to step to the next window once the switcher is open.
* *Lower values* (e.g., `15.0`) make it more sensitive (switches faster with less movement).
* *Higher values* (e.g., `50.0`) require a larger swipe to change windows.


2. **Initial Activation Check (Default: `10.0`)**
* Located in `handleScrollEvent` (`guard abs(deltaX) > 10.0 else { return }`).
* Prevents accidental minor movements from opening the HUD. Adjust this higher if it triggers too easily by accident, or lower it if it's hard to invoke.


3. **`stepCooldown` (Default: `0.22` seconds)**
* Acts as a speed limit between consecutive window steps so you don't skip through windows too quickly.
* *Lower values* allow faster cycling; *higher values* slow down the scrolling pace.



*After modifying these values in `GestureSwitch.swift`, simply run `./build.sh` again to recompile.*

---

## 📄 License

This project is open-source and available under the MIT License.