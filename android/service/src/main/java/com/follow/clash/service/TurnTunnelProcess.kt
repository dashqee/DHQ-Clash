package com.follow.clash.service

import android.os.Build
import android.util.Log
import com.follow.clash.common.GlobalState
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.OutputStreamWriter
import java.net.Inet4Address
import java.net.InetAddress
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

internal class TurnTunnelProcess(
    private val onStatus: (String) -> Unit,
) {
    private var process: Process? = null
    private var worker: Thread? = null
    private var stdin: BufferedWriter? = null

    @Volatile
    private var running = false

    val isRunning: Boolean
        get() = running

    @Synchronized
    fun start(
        joinLink: String,
        displayName: String,
        tunnelMode: String,
        socksPort: Int,
        socksUsername: String,
        socksPassword: String,
    ): Boolean {
        stop()
        val nativeDir = GlobalState.application.applicationInfo.nativeLibraryDir
        val executable = File(nativeDir, SIDECAR_NAME)
        if (!executable.exists()) {
            Log.e(TAG, "TURN sidecar not found")
            onStatus("ERROR:sidecar missing")
            return false
        }

        running = true
        worker = Thread {
            try {
                val child = ProcessBuilder(
                    executable.absolutePath,
                    "--mode",
                    "vk-headless-joiner",
                    "--socks-host",
                    "127.0.0.1",
                    "--socks-port",
                    socksPort.toString(),
                    "--socks-user",
                    socksUsername,
                    "--socks-pass",
                    socksPassword,
                ).redirectErrorStream(true).start()
                synchronized(this) {
                    process = child
                    stdin = BufferedWriter(OutputStreamWriter(child.outputStream))
                }
                child.inputStream.bufferedReader().forEachLine { line ->
                    when {
                        line.startsWith("RESOLVE:") -> {
                            resolve(line.removePrefix("RESOLVE:"))
                        }

                        line.startsWith("STATUS:") -> {
                            val status = line.removePrefix("STATUS:")
                            onStatus(status)
                            if (status == "READY") {
                                val params = JSONObject().apply {
                                    put("joinLink", joinLink)
                                    put("displayName", displayName)
                                    put("tunnelMode", tunnelMode)
                                    put("vp8Fps", 0)
                                    put("vp8Batch", 0)
                                    put("dualTrack", false)
                                }
                                writeLine("AUTH:$params")
                            }
                        }

                        else -> Log.d(TAG, sanitizeLog(line))
                    }
                }
                child.waitFor()
                if (running) onStatus("ERROR:sidecar exited")
            } catch (error: Exception) {
                Log.e(TAG, "TURN sidecar failed", error)
                if (running) onStatus("ERROR:${error.message ?: "start failed"}")
            } finally {
                running = false
            }
        }.also {
            it.name = "DHQClashTurn"
            it.start()
        }
        return true
    }

    @Synchronized
    fun stop() {
        running = false
        runCatching { stdin?.close() }
        stdin = null
        val activeProcess = process
        process = null
        activeProcess?.destroy()
        if (activeProcess != null) {
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !activeProcess.waitFor(1500, TimeUnit.MILLISECONDS)
                ) {
                    activeProcess.destroyForcibly()
                }
            }
        }
        worker?.interrupt()
        worker = null
    }

    private fun resolve(hostname: String) {
        val result = runCatching {
            val addresses = InetAddress.getAllByName(hostname)
            (addresses.firstOrNull { it is Inet4Address } ?: addresses.first()).hostAddress
        }.getOrNull().orEmpty()
        writeLine(result)
    }

    @Synchronized
    private fun writeLine(value: String) {
        runCatching {
            stdin?.write(value)
            stdin?.newLine()
            stdin?.flush()
        }.onFailure { Log.e(TAG, "TURN stdin write failed", it) }
    }

    private fun sanitizeLog(value: String): String {
        return JOIN_LINK_REGEX.replace(
            value,
            "https://vk.ru/call/join/[redacted]",
        )
    }

    companion object {
        private const val TAG = "DHQClashTurn"
        private const val SIDECAR_NAME = "libDHQClashTurn.so"
        private val JOIN_LINK_REGEX =
            Regex("""https://(?:vk\.ru|vk\.com)/call/join/[^\s"'<>]+""")

        fun sessionKey(
            joinLink: String,
            displayName: String,
            tunnelMode: String,
            socksPort: Int,
        ): String {
            val value = "$joinLink\u0000$displayName\u0000$tunnelMode\u0000$socksPort"
            return MessageDigest.getInstance("SHA-256")
                .digest(value.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }
    }
}

internal object TurnTunnelRuntime {
    private var process: TurnTunnelProcess? = null
    private var activeSessionKey: String? = null
    private var lastStatus = "STOPPED"
    private var onStatus: ((String) -> Unit)? = null

    @Synchronized
    fun start(
        joinLink: String,
        displayName: String,
        tunnelMode: String,
        socksPort: Int,
        socksUsername: String,
        socksPassword: String,
        statusCallback: (String) -> Unit,
    ): Boolean {
        onStatus = statusCallback
        val nextSessionKey = TurnTunnelProcess.sessionKey(
            joinLink,
            displayName,
            tunnelMode,
            socksPort,
        )
        val activeProcess = process
        if (activeSessionKey == nextSessionKey && activeProcess?.isRunning == true) {
            statusCallback(lastStatus)
            return true
        }

        activeProcess?.stop()
        val nextProcess = TurnTunnelProcess(::emitStatus)
        process = nextProcess
        activeSessionKey = nextSessionKey
        return nextProcess.start(
            joinLink,
            displayName,
            tunnelMode,
            socksPort,
            socksUsername,
            socksPassword,
        )
    }

    @Synchronized
    fun stop() {
        process?.stop()
        process = null
        activeSessionKey = null
        lastStatus = "STOPPED"
    }

    @Synchronized
    private fun emitStatus(status: String) {
        lastStatus = status
        onStatus?.invoke(status)
    }
}
