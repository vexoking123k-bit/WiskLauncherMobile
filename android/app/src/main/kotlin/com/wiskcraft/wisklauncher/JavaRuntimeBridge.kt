package com.wiskcraft.wisklauncher

import android.app.Activity
import android.os.Build
import android.system.Os
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.GZIPInputStream
import java.util.zip.ZipFile
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.FileOutputStream

/**
 * Owns the actual Java process. Two responsibilities:
 *
 *  1. Install: download an OpenJDK build that matches the device ABI from
 *     Adoptium's official redirect API.
 *  2. Spawn: ProcessBuilder.start() with stdout/stderr piped back to the
 *     Dart side via an event-sink callback.
 *
 * Apache Commons Compress is used for tar.gz extraction; add to
 * `android/app/build.gradle` dependencies:
 *   implementation("org.apache.commons:commons-compress:1.26.1")
 */
class JavaRuntimeBridge(
    private val activity: Activity,
    private val scope: CoroutineScope,
) {
    @Volatile private var current: Process? = null

    suspend fun verify(executablePath: String): Boolean = withContext(Dispatchers.IO) {
        val f = File(executablePath)
        if (!f.exists()) return@withContext false
        // Ensure exec permission (extracted JRE files can lose it).
        if (!f.canExecute()) f.setExecutable(true, false)
        runCatching {
            val p = ProcessBuilder(executablePath, "-version")
                .redirectErrorStream(true).start()
            val ok = p.waitFor() == 0
            ok
        }.getOrDefault(false)
    }

    suspend fun installJava(majorVersion: Int, targetDir: String): Map<String, Any?> = withContext(Dispatchers.IO) {
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        // PojavLauncher's Holy Java releases are real Android-bionic OpenJDK
        // builds. Vanilla Adoptium Linux builds CANNOT exec on Android (they
        // link against glibc). We download from the multi-arch repo.
        val abiTokens = when (abi) {
            "arm64-v8a"   -> listOf("aarch64", "arm64")
            "armeabi-v7a" -> listOf("arm", "armhf")
            "x86_64"      -> listOf("x86_64", "amd64")
            "x86"         -> listOf("x86", "i386", "i686")
            else -> listOf("aarch64")
        }
        // Discover the actual asset URL from the GitHub Releases API rather
        // than guessing — the tag and asset naming has changed several times
        // upstream, and Java 21 in particular only landed in newer tags.
        val dst = File(targetDir).apply { mkdirs() }
        if (majorVersion == 21) {
            val javaBin = installFromPojavApk(majorVersion, abi, dst)
                ?: error(unavailableHolyJavaMessage(majorVersion, abi))
            fixRuntimePermissions(dst)
            return@withContext mapOf(
                "executablePath" to javaBin.absolutePath,
                "vendor" to "PojavLauncherTeam/PojavLauncher",
                "fullVersion" to "OpenJDK $majorVersion ($abi)",
            )
        }
        val assetUrl = resolveHolyJavaAsset(majorVersion, abiTokens)
        if (assetUrl == null) error(unavailableHolyJavaMessage(majorVersion, abi))
        val archive = File(dst, "holyjava.tar.xz")
        downloadTo(assetUrl, archive)
        val javaBin = if (assetUrl.endsWith(".tar.gz", ignoreCase = true)) {
            extractTarGz(archive, dst)
        } else {
            extractTarXz(archive, dst)
        } ?: error("Holy Java archive missing bin/java (download URL: $assetUrl)")
        archive.delete()
        installPojavSupportFiles(abi, dst)
        fixRuntimePermissions(dst)

        // We don't try to `-version` here because on Android the JRE needs
        // LD_LIBRARY_PATH set up to find its own libs. The Dart-side verify
        // step will do a guarded check.
        mapOf(
            "executablePath" to javaBin.absolutePath,
            "vendor" to "PojavLauncherTeam/Holy-Java",
            "fullVersion" to "OpenJDK $majorVersion (${abiTokens.first()})",
        )
    }

    /// Walks the GitHub releases list (newest first) and returns the first
    /// asset whose containing release is **for Android** (not iOS), and whose
    /// filename mentions BOTH the requested Java major AND one of the ABI
    /// tokens.
    ///
    /// Ground truth in the upstream repo (checked 2026-06):
    ///   * Java 17: released as "JRE17 for Android", tag `jre17-ec28559`,
    ///     assets `jre17-arm64-...`, `jre17-arm-...`, `jre17-x86_64-...`.
    ///   * Java 8 / 11 / 16 / 21: no public Android tarball at this URL.
    ///     We surface a clear error rather than 404-ing.
    private fun resolveHolyJavaAsset(major: Int, abiTokens: List<String>): String? {
        val repo = "PojavLauncherTeam/android-openjdk-build-multiarch"
        val api = URL("https://api.github.com/repos/$repo/releases?per_page=100")
        val conn = (api.openConnection() as HttpURLConnection).apply {
            setRequestProperty("Accept", "application/vnd.github+json")
            connectTimeout = 15_000
            readTimeout = 30_000
        }
        val text = conn.inputStream.bufferedReader().use { it.readText() }

        // Walk releases as JSON objects so we can look at both the release
        // name (to filter Android vs iOS) and its assets.
        //
        // We don't want to pull in a JSON dependency just for this — the
        // structure is small and stable. We slice the array element-by-element
        // by finding balanced braces.
        val releases = splitJsonArray(text)
        for (release in releases) {
            val name = extractStringField(release, "name") ?: ""
            // Filter to Android releases only. The same repo holds iOS
            // sandboxed JREs (which won't exec on Android).
            if (name.contains("ios", ignoreCase = true)) continue
            if (!name.contains("android", ignoreCase = true)) continue
            // Look at assets inside this release.
            val urlRegex = Regex("\"browser_download_url\"\\s*:\\s*\"([^\"]+)\"")
            val assetUrls = urlRegex.findAll(release).map { it.groupValues[1] }
            for (url in assetUrls) {
                val asset = url.substringAfterLast('/').lowercase()
                val matchesMajor = asset.contains("jre$major") ||
                    asset.contains("jre-$major") ||
                    asset.contains("openjdk-$major") ||
                    asset.contains("-$major-")
                if (!matchesMajor) continue
                val matchesAbi = abiTokens.any { tok -> asset.contains(tok.lowercase()) }
                if (!matchesAbi) continue
                if (!asset.endsWith(".tar.xz") && !asset.endsWith(".tar.gz")) continue
                return url
            }
        }
        return null
    }

    private fun unavailableHolyJavaMessage(major: Int, abi: String): String =
        "Java $major is not available as a public Android runtime for $abi. " +
        "PojavLauncherTeam/android-openjdk-build-multiarch currently publishes " +
        "only Java 17 as a standalone downloadable release. WiskLauncher can " +
        "extract Java 21 from the official PojavLauncher APK, but Java 11 and " +
        "16 do not have supported downloadable Android runtimes here. Install " +
        "Java 17 for Minecraft 1.18-1.20.4 or Java 21 for 1.20.5+."

    private fun installFromPojavApk(major: Int, abi: String, dst: File): File? {
        val binName = when (abi) {
            "arm64-v8a" -> "bin-arm64.tar.xz"
            "armeabi-v7a" -> "bin-arm.tar.xz"
            "x86_64" -> "bin-x86_64.tar.xz"
            "x86" -> "bin-x86.tar.xz"
            else -> "bin-arm64.tar.xz"
        }
        val componentDir = "assets/components/jre-$major"
        val apk = downloadPojavApk(dst)
        val universal = File(dst, "universal.tar.xz")
        val archBin = File(dst, binName)
        ZipFile(apk).use { zip ->
            extractZipEntry(zip, "$componentDir/universal.tar.xz", universal)
            extractZipEntry(zip, "$componentDir/$binName", archBin)
        }
        installPojavSupportFiles(abi, dst)
        extractTarXz(universal, dst)
        val javaBin = extractTarXz(archBin, dst)
        universal.delete()
        archBin.delete()
        return javaBin ?: File(dst, "bin/java").takeIf { it.exists() }
    }

    private fun installPojavSupportFiles(abi: String, dst: File) {
        val apk = downloadPojavApk(dst)
        ZipFile(apk).use { zip ->
            extractZipEntry(
                zip,
                "assets/components/lwjgl3/lwjgl-glfw-classes.jar",
                File(dst, "pojav/lwjgl-glfw-classes.jar"),
            )
            extractPojavNativeLibs(zip, abi, File(dst, "pojav-libs"))
        }
        apk.delete()
    }

    private fun downloadPojavApk(dst: File): File {
        val apk = File(dst, "pojav-runtime-source.apk")
        if (!apk.exists() || apk.length() < 1024L * 1024L) {
            downloadTo(POJAV_APK_URL, apk)
        }
        return apk
    }

    private fun extractZipEntry(zip: ZipFile, entryName: String, dst: File) {
        val entry = zip.getEntry(entryName)
            ?: error("Pojav APK is missing $entryName")
        dst.parentFile?.mkdirs()
        zip.getInputStream(entry).use { input ->
            FileOutputStream(dst).use { input.copyTo(it) }
        }
    }

    private fun extractPojavNativeLibs(zip: ZipFile, abi: String, dst: File) {
        dst.mkdirs()
        val prefix = "lib/$abi/"
        val entries = zip.entries()
        while (entries.hasMoreElements()) {
            val entry = entries.nextElement()
            if (entry.isDirectory || !entry.name.startsWith(prefix)) continue
            if (!entry.name.endsWith(".so")) continue
            val out = File(dst, entry.name.substringAfterLast('/'))
            zip.getInputStream(entry).use { input ->
                FileOutputStream(out).use { input.copyTo(it) }
            }
            out.setExecutable(true, false)
        }
    }

    private fun fixRuntimePermissions(root: File) {
        root.walkTopDown().forEach { file ->
            runCatching {
                when {
                    file.isDirectory -> Os.chmod(file.absolutePath, 493) // 0755
                    file.parentFile?.name == "bin" -> Os.chmod(file.absolutePath, 493)
                    file.extension == "so" -> Os.chmod(file.absolutePath, 493)
                    file.name == "jspawnhelper" -> Os.chmod(file.absolutePath, 493)
                    else -> Os.chmod(file.absolutePath, 420) // 0644
                }
            }
        }
    }

    /// Splits a JSON array of objects into the substring for each object,
    /// honouring nested braces and string literals. Returns a list of the
    /// inner-object substrings (so each entry starts with `{` and ends with
    /// `}`).
    private fun splitJsonArray(text: String): List<String> {
        val out = mutableListOf<String>()
        var depth = 0
        var start = -1
        var inString = false
        var escape = false
        for (i in text.indices) {
            val c = text[i]
            if (escape) { escape = false; continue }
            if (c == '\\' && inString) { escape = true; continue }
            if (c == '"') { inString = !inString; continue }
            if (inString) continue
            when (c) {
                '{' -> {
                    if (depth == 0) start = i
                    depth++
                }
                '}' -> {
                    depth--
                    if (depth == 0 && start >= 0) {
                        out.add(text.substring(start, i + 1))
                        start = -1
                    }
                }
            }
        }
        return out
    }

    private fun extractStringField(obj: String, field: String): String? {
        val r = Regex("\"$field\"\\s*:\\s*\"((?:\\\\.|[^\\\\\"])*)\"")
        return r.find(obj)?.groupValues?.get(1)
    }

    private fun downloadTo(url: String, dst: File) {
        URL(url).openStream().use { input ->
            FileOutputStream(dst).use { input.copyTo(it) }
        }
    }

    private fun extractTarGz(tar: File, dst: File): File? {
        var javaBin: File? = null
        GZIPInputStream(tar.inputStream().buffered()).use { gz ->
            TarArchiveInputStream(gz).use { tarIn ->
                while (true) {
                    val entry = tarIn.nextTarEntry ?: break
                    val rel = normalizeTarPath(entry.name)
                    if (rel.isEmpty()) continue
                    val out = File(dst, rel)
                    if (entry.isDirectory) {
                        out.mkdirs()
                    } else {
                        out.parentFile?.mkdirs()
                        FileOutputStream(out).use { tarIn.copyTo(it) }
                        if (out.name == "java" && out.parentFile?.name == "bin") {
                            javaBin = out
                        }
                    }
                }
            }
        }
        return javaBin
    }

    private fun extractTarXz(archive: File, dst: File): File? {
        var javaBin: File? = null
        org.apache.commons.compress.compressors.xz.XZCompressorInputStream(
            archive.inputStream().buffered()
        ).use { xz ->
            TarArchiveInputStream(xz).use { tarIn ->
                while (true) {
                    val entry = tarIn.nextTarEntry ?: break
                    val rel = normalizeTarPath(entry.name)
                    if (rel.isEmpty()) continue
                    val out = File(dst, rel)
                    if (entry.isDirectory) {
                        out.mkdirs()
                    } else {
                        out.parentFile?.mkdirs()
                        FileOutputStream(out).use { tarIn.copyTo(it) }
                        if (out.name == "java" && out.parentFile?.name == "bin") {
                            javaBin = out
                        }
                    }
                }
            }
        }
        return javaBin
    }

    private fun normalizeTarPath(name: String): String {
        val clean = name.trimStart('/').removePrefix("./")
        val parts = clean.split('/', limit = 2)
        if (parts.size != 2) return clean

        // Pojav's split JRE archives are already rooted at bin/, lib/, conf/,
        // etc. Only strip a wrapper directory when it is clearly an archive
        // root such as jdk-21/ or jre17-aarch64/. Blind stripping breaks
        // lib/jvm.cfg into jvm.cfg, which makes bin/java exit immediately.
        val first = parts[0].lowercase()
        val rootedDirs = setOf(
            "bin", "conf", "include", "legal", "lib", "man",
            "pojav", "pojav-libs",
        )
        if (first in rootedDirs) return clean
        val looksLikeWrapper =
            first.startsWith("jdk") ||
            first.startsWith("jre") ||
            first.startsWith("java") ||
            first.startsWith("openjdk")
        return if (looksLikeWrapper) parts[1] else clean
    }

    suspend fun spawn(
        executable: String,
        arguments: List<String>,
        workingDirectory: String,
        environment: Map<String, String>,
        onEvent: (Map<String, Any?>) -> Unit,
    ) {
        val pb = ProcessBuilder(listOf(executable) + arguments)
            .directory(File(workingDirectory))
            .redirectErrorStream(false)
        // Merge env on top of the inherited env.
        val env = pb.environment()
        environment.forEach { (k, v) ->
            if (k == "TMPDIR") File(v).mkdirs()
            if (k == "LD_LIBRARY_PATH") {
                val existing = env[k]
                env[k] = if (existing.isNullOrBlank()) v else "$v:$existing"
            } else {
                env[k] = v
            }
        }
        val p = pb.start().also { current = it }
        onEvent(mapOf("type" to "stdout", "line" to "Java process started"))

        // stdout pump
        scope.launch(Dispatchers.IO) {
            BufferedReader(InputStreamReader(p.inputStream)).useLines { lines ->
                lines.forEach { onEvent(mapOf("type" to "stdout", "line" to it)) }
            }
        }
        // stderr pump
        scope.launch(Dispatchers.IO) {
            BufferedReader(InputStreamReader(p.errorStream)).useLines { lines ->
                lines.forEach { onEvent(mapOf("type" to "stderr", "line" to it)) }
            }
        }
        scope.launch(Dispatchers.IO) {
            delay(25_000)
            if (p.isAlive) {
                onEvent(mapOf(
                    "type" to "stderr",
                    "line" to "Java process is still running but has not opened a Minecraft window. Android rendering may still need the Pojav activity/renderer bridge.",
                ))
            }
        }
        val code = p.waitFor()
        onEvent(mapOf("type" to "exit", "code" to code))
        current = null
    }

    fun stop() {
        current?.destroy()
        current = null
    }

    private companion object {
        private const val POJAV_APK_URL =
            "https://github.com/PojavLauncherTeam/PojavLauncher/releases/download/gladiolus/PojavLauncher.apk"
    }
}
