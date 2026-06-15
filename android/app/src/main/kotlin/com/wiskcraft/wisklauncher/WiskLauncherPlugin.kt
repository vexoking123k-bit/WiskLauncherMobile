package com.wiskcraft.wisklauncher

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Hosts the Dart-facing MethodChannels and EventChannel for WiskLauncher.
 *
 * Method channel: `wisklauncher/runtime`
 *   getAbi() -> String
 *   verifyJava({executablePath}) -> Boolean
 *   installJava({majorVersion, targetDir}) -> Map(executablePath,...)
 *   launch({executablePath, arguments, workingDirectory, environment}) -> Unit
 *   stop() -> Unit
 *
 * Event channel: `wisklauncher/events`
 *   {type:"stdout"|"stderr", line:String} OR {type:"exit", code:Int}
 */
class WiskLauncherPlugin private constructor(
    private val activity: Activity,
) {
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())
    private val javaBridge = JavaRuntimeBridge(activity, scope)

    private var eventSink: EventChannel.EventSink? = null
    private val pendingEvents = ArrayDeque<Map<String, Any?>>()
    private var currentJob: Job? = null

    companion object {
        fun register(engine: FlutterEngine, activity: Activity) {
            val plugin = WiskLauncherPlugin(activity)
            MethodChannel(engine.dartExecutor.binaryMessenger, "wisklauncher/runtime")
                .setMethodCallHandler { call, result -> plugin.handle(call.method, call.arguments, result) }
            EventChannel(engine.dartExecutor.binaryMessenger, "wisklauncher/events")
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                        plugin.eventSink = sink
                        plugin.flushPendingEvents()
                    }
                    override fun onCancel(args: Any?) { plugin.eventSink = null }
                })
        }
    }

    private fun emitEvent(event: Map<String, Any?>) {
        main.post {
            val sink = eventSink
            if (sink == null) {
                pendingEvents.addLast(event)
                while (pendingEvents.size > 200) pendingEvents.removeFirst()
            } else {
                sink.success(event)
            }
        }
    }

    private fun flushPendingEvents() {
        val sink = eventSink ?: return
        while (pendingEvents.isNotEmpty()) {
            sink.success(pendingEvents.removeFirst())
        }
    }

    private fun handle(method: String, args: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val map = args as? Map<String, Any?> ?: emptyMap()
        when (method) {
            "getAbi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
            "verifyJava" -> {
                val path = map["executablePath"] as String
                scope.launch {
                    val ok = javaBridge.verify(path)
                    main.post { result.success(ok) }
                }
            }
            "installJava" -> {
                val major = (map["majorVersion"] as Number).toInt()
                val targetDir = map["targetDir"] as String
                scope.launch {
                    try {
                        val info = javaBridge.installJava(major, targetDir)
                        main.post { result.success(info) }
                    } catch (e: Throwable) {
                        main.post { result.error("install_failed", e.message, null) }
                    }
                }
            }
            "launch" -> {
                val exec = map["executablePath"] as String
                @Suppress("UNCHECKED_CAST")
                val arguments = (map["arguments"] as List<String>)
                val cwd = map["workingDirectory"] as String
                @Suppress("UNCHECKED_CAST")
                val env = (map["environment"] as Map<String, String>)
                currentJob?.cancel()
                currentJob = scope.launch {
                    try {
                        javaBridge.spawn(exec, arguments, cwd, env) { event ->
                            emitEvent(event)
                        }
                    } catch (e: Throwable) {
                        emitEvent(mapOf(
                            "type" to "stderr",
                            "line" to "Launch failed before Minecraft could start: ${e.message ?: e::class.java.name}",
                        ))
                        emitEvent(mapOf("type" to "exit", "code" to -1))
                    }
                }
                result.success(null)
            }
            "stop" -> {
                currentJob?.cancel()
                javaBridge.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
