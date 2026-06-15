# iOS limitations — honest version

## The short version

You cannot legally run Minecraft Java Edition on a non-jailbroken iOS device through the App Store.

## Why

Minecraft Java Edition needs a JVM. A JVM needs a JIT compiler (HotSpot, OpenJ9, etc). iOS bars third-party JIT for App Store apps:

1. **No executable pages from user code.** App Store apps cannot allocate `RWX` memory pages or use `mprotect` to flip a page to executable. JIT compilers depend on this.
2. **Code-signing enforcement.** All executable pages must be signed by Apple at install time. JIT-compiled code is generated at runtime and unsigned.
3. **No fork/exec of arbitrary binaries.** Even if we bundled a JRE, iOS will not let us `exec("java", ...)` on a separate ELF/Mach-O binary that wasn't part of the signed app bundle, and even then only the main executable runs as the process.
4. **Sandbox.** The app's file access is limited to its own container; it cannot install system-wide runtimes.

An interpreter-only JVM (no JIT) would technically be legal under App Store rules but would run Minecraft at single-digit FPS — not a product we want to ship.

## What we still do on iOS

The iOS build is a **launcher manager**:

* Sign in with Microsoft (full official OAuth).
* Browse and download Minecraft versions, libraries, and assets to a per-app directory.
* Manage profiles, mods folders, settings.
* Surface logs from previous runs (e.g. via shared iCloud Drive folder if the user has one from a desktop launcher).

The Play button on iOS surfaces a clear, non-misleading dialog:

> "Launching Minecraft Java is not supported on iOS. This device can be used to manage downloads and profiles, but the game must be launched on a desktop, Android device, or jailbroken iOS device."

We do **not** fake launching, show a fake loading screen, or pretend the game is running.

## What would change this

* **Jailbreak / TrollStore** with `get-task-allow` entitlement → JIT works. Out of scope for App Store, but the same Flutter binary can be repackaged for those distribution channels by anyone who wants to.
* **Apple ships a "developer JIT" entitlement for general apps** (currently only `com.apple.developer.cs.allow-jit` exists, gated to specific use cases). If/when that opens up, we can bundle OpenJDK for iOS.
* **AltStore / sideloading with `MAP_JIT`** — possible on supported iOS versions; the abstraction layer in `lib/platform/ios/` is structured to allow this to be wired up if the host environment provides JIT.
