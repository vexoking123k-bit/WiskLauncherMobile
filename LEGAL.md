# Legal

WiskLauncher Mobile is an unofficial third-party launcher. **Minecraft** is a trademark of Mojang Synergies AB / Microsoft Corporation. This project is not affiliated with, endorsed by, or sponsored by Mojang or Microsoft.

## What WiskLauncher does

* Authenticates exclusively through the official **Microsoft account / Xbox Live / Minecraft Services** OAuth flow.
* Downloads version manifests, client JARs, libraries, and assets **only from official Mojang / Microsoft endpoints** (`piston-meta.mojang.com`, `piston-data.mojang.com`, `resources.download.minecraft.net`, `libraries.minecraft.net`).
* Verifies downloaded files against the SHA1 hashes published in the official manifests.

## What WiskLauncher will never do

* Provide, accept, or distribute cracked / offline / unofficial Minecraft accounts.
* Bypass Microsoft's authentication, Xbox Live ownership checks, or Minecraft entitlement checks.
* Host or redistribute Minecraft client JARs, assets, or libraries.
* Patch the game to disable account checks.

If you do not own a legitimate Minecraft: Java Edition license, you cannot use this launcher to play the game.

## Tokens & privacy

* OAuth tokens are stored using the platform secure storage (Keychain on iOS, EncryptedSharedPreferences / Keystore on Android).
* Tokens are **never** logged, transmitted to any third party, or written to plaintext files.
* You can sign out at any time from the Accounts page; signing out wipes stored tokens.

## License

The launcher source code is released under the MIT license (see `LICENSE`). The Minecraft game files it downloads remain the property of Mojang / Microsoft and are governed by the Minecraft EULA: https://www.minecraft.net/eula.
