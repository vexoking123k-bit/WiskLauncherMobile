import Flutter
import UIKit

/// iOS limitation-honest bridge. We deliberately do not include any code path
/// that would attempt to spawn a JVM or allocate `RWX` pages — see
/// docs/IOS_LIMITATIONS.md.
public class WiskLauncherPlugin: NSObject {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "wisklauncher/runtime",
            binaryMessenger: registrar.messenger()
        )
        let instance = WiskLauncherPlugin()
        channel.setMethodCallHandler(instance.handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAbi":
            // iOS devices are arm64 (modern) or x86_64 (simulator).
            #if arch(arm64)
            result("arm64")
            #else
            result("x86_64")
            #endif

        case "inspectJava":
            // Sandbox cannot exec the file, but we can stat & sniff the Mach-O
            // magic. This lets the user point at a sideloaded JDK and see that
            // it at least *looks* runnable — even if iOS won't let us run it.
            guard let args = call.arguments as? [String: Any],
                  let path = args["executablePath"] as? String,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped]),
                  data.count >= 4 else {
                result(false); return
            }
            let magic = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
            // Mach-O 32 / 64-bit magic numbers.
            let isMachO = magic == 0xFEEDFACE || magic == 0xFEEDFACF
                       || magic == 0xCEFAEDFE || magic == 0xCFFAEDFE
            result(isMachO)

        case "installJava", "launch", "stop":
            result(FlutterError(
                code: "platform_unsupported",
                message: "iOS cannot run the Minecraft JVM. WiskLauncher on iOS is a manager / downloader only — see docs/IOS_LIMITATIONS.md.",
                details: nil
            ))

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
