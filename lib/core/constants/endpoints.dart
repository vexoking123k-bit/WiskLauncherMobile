/// Official Mojang / Microsoft endpoints. We never download game files from
/// anywhere else.
class Endpoints {
  Endpoints._();

  // Version manifest (release + snapshot + old_alpha + old_beta).
  static const String versionManifestV2 =
      'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';

  // Assets resource server. Asset objects are addressed as
  // `<resourcesBase>/<hash[0..2]>/<hash>`.
  static const String resourcesBase =
      'https://resources.download.minecraft.net';

  // Microsoft OAuth (device code flow). We use the well-known public client id
  // shipped with the Java launcher — no embedded secrets.
  static const String msOAuthDeviceCode =
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode';
  static const String msOAuthToken =
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/token';

  // Xbox Live + XSTS
  static const String xblAuthenticate =
      'https://user.auth.xboxlive.com/user/authenticate';
  static const String xstsAuthorize =
      'https://xsts.auth.xboxlive.com/xsts/authorize';

  // Minecraft Services
  static const String mcLoginWithXbox =
      'https://api.minecraftservices.com/authentication/login_with_xbox';
  static const String mcEntitlements =
      'https://api.minecraftservices.com/entitlements/mcstore';
  static const String mcProfile =
      'https://api.minecraftservices.com/minecraft/profile';

  // Fabric meta
  static const String fabricLoaderMeta =
      'https://meta.fabricmc.net/v2/versions/loader';
  static const String fabricInstallerMeta =
      'https://meta.fabricmc.net/v2/versions/installer';

  // Quilt meta (Fabric-compatible shape)
  static const String quiltLoaderMeta =
      'https://meta.quiltmc.org/v3/versions/loader';

  // Forge — maven directly. We list versions via the legacy promotions json.
  static const String forgePromotions =
      'https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json';
  static const String forgeMavenBase =
      'https://maven.minecraftforge.net/net/minecraftforge/forge';

  // NeoForge
  static const String neoForgeMetaXml =
      'https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml';
  static const String neoForgeMavenBase =
      'https://maven.neoforged.net/releases/net/neoforged/neoforge';

  // OptiFine via BMCLAPI mirror — BMCLAPI publishes a Forge-compatible profile
  // JSON so we don't need to run OptiFine's Swing-based patcher locally.
  static const String optifineVersionsList =
      'https://bmclapi2.bangbang93.com/optifine/versionList';
  static String optifineDownload(String mcVersion, String type, String patch) =>
      'https://bmclapi2.bangbang93.com/optifine/$mcVersion/$type/$patch';

  // PojavLauncher's "Holy Java" — real Android-bionic OpenJDK builds. Without
  // these, the JRE we install on Android won't actually exec.
  // The releases are published on GitHub under PojavLauncherTeam/android-openjdk-build-multiarch.
  static String holyJavaRelease(int major, String abi) {
    // Release filename convention:
    //   jre$major-$abi.tar.xz
    // We pin to a known-good tag for reproducibility.
    const tag = 'experimental';
    return 'https://github.com/PojavLauncherTeam/android-openjdk-build-multiarch/releases/download/$tag/jre$major-$abi.tar.xz';
  }
}
