/// Microsoft OAuth client constants.
///
/// `00000000402b5328` is the public Minecraft Java Launcher application id
/// published by Microsoft. It is the same client id used by the official Java
/// launcher and is safe (and intended) to embed in third-party launchers — it
/// has no secret. We use the **device-code flow** so that we never need a web
/// redirect URI, which is the friendliest UX for mobile.
class AuthConstants {
  AuthConstants._();

  static const String clientId = '00000000402b5328';

  // Scopes required for Xbox Live + Minecraft Services.
  static const String scopes = 'XboxLive.signin offline_access';

  // XSTS relying party for Minecraft.
  static const String xstsRelyingParty = 'rp://api.minecraftservices.com/';
}
