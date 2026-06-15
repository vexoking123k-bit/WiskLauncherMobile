# Roadmap

## v0.1 — Scaffold (this drop)
- [x] Clean architecture skeleton (core/data/domain/platform/presentation)
- [x] Microsoft OAuth device-code flow
- [x] Official version manifest fetch + cache
- [x] Version installer (json, jar, libraries, assets, natives)
- [x] SHA1 verification on all official downloads
- [x] Profile manager (CRUD, JSON-persisted)
- [x] Java runtime manager (detect arch, register installed runtimes)
- [x] Launch command builder (parity with vanilla launcher argument schema, modern + legacy)
- [x] Android native bridge: spawn `java` process, pipe stdout/stderr into Logs page
- [x] iOS native bridge: download / profile ops only, launch reports `unsupported`
- [x] Flutter UI: Home, Versions, Accounts, Downloads, Settings, Logs, Profiles, Mods, Java
- [x] Touch controls UI editor (saves layout; input forwarding is a stub — needs JNI hook into the game loop)
- [x] Fabric installer (downloads loader, generates merged version JSON)
- [ ] Forge installer (interface only — Forge installer JAR is GUI/Swing, needs custom headless reimpl)
- [ ] Quilt installer (interface only — similar to Fabric, easy follow-up)

## v0.2 — Quality
- [ ] Background download service (Android `WorkManager`)
- [ ] Resume partial downloads via HTTP `Range`
- [ ] Per-profile mod toggling
- [ ] Skin renderer (3D) on Home page
- [ ] Settings: per-profile JVM args UI
- [ ] Localization (en, es, pt-BR, zh-CN)

## v0.3 — Performance & UX
- [ ] Pojav-style GL4ES / Zink renderer integration (Android only; requires bundling shared libs)
- [ ] Touch control input forwarding via libxhook into LWJGL input loop (Android only)
- [ ] In-game gamepad mapping
- [ ] Cloud sync of profiles via user-supplied WebDAV

## v1.0 — Ship
- [ ] Crash reporter (Sentry, opt-in)
- [ ] Play Store listing
- [ ] TestFlight build (downloader-only on iOS, clearly marked)
