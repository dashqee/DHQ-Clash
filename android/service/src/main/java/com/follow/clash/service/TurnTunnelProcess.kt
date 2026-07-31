package com.follow.clash.service

import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.follow.clash.common.GlobalState
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.OutputStreamWriter
import java.net.Inet4Address
import java.net.InetAddress
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

internal class TurnTunnelProcess(
    private val onStatus: (String) -> Unit,
) {
    private var process: Process? = null
    private var worker: Thread? = null
    private var stdin: BufferedWriter? = null
    private var leaveAck = CountDownLatch(1)

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
        if (!stop()) return false
        val nativeDir = GlobalState.application.applicationInfo.nativeLibraryDir
        val executable = File(nativeDir, SIDECAR_NAME)
        if (!executable.exists()) {
            Log.e(TAG, "TURN sidecar not found")
            onStatus("ERROR:sidecar missing")
            return false
        }

        val child = try {
            ProcessBuilder(
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
        } catch (error: Exception) {
            Log.e(TAG, "TURN sidecar failed to start", error)
            onStatus("ERROR:${error.message ?: "start failed"}")
            return false
        }
        process = child
        stdin = BufferedWriter(OutputStreamWriter(child.outputStream))
        leaveAck = CountDownLatch(1)
        running = true
        worker = Thread {
            try {
                child.inputStream.bufferedReader().forEachLine { line ->
                    when {
                        line.startsWith("RESOLVE:") -> {
                            resolve(line.removePrefix("RESOLVE:"))
                        }

                        line.startsWith("STATUS:") -> {
                            val status = line.removePrefix("STATUS:")
                            if (status == "LEAVE_ACK") {
                                leaveAck.countDown()
                                return@forEachLine
                            }
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
                synchronized(this) {
                    if (process === child) {
                        process = null
                        runCatching { stdin?.close() }
                        stdin = null
                    }
                }
            }
        }.also {
            it.name = "DHQClashTurn"
            it.start()
        }
        return true
    }

    @Synchronized
    fun stop(): Boolean {
        running = false
        val activeProcess = process
        if (activeProcess == null) {
            runCatching { stdin?.close() }
            stdin = null
            worker?.interrupt()
            worker = null
            return true
        }
        writeLine("LEAVE")
        val leaveAcknowledged = runCatching {
            leaveAck.await(LEAVE_ACK_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        }.getOrDefault(false)
        if (!leaveAcknowledged) activeProcess.destroy()
        var exited = waitForExit(activeProcess, PROCESS_EXIT_TIMEOUT_MS)
        if (!exited) {
            activeProcess.destroy()
            exited = waitForExit(activeProcess, PROCESS_EXIT_TIMEOUT_MS)
        }
        if (!exited && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activeProcess.destroyForcibly()
            exited = waitForExit(activeProcess, FORCED_STOP_TIMEOUT_MS)
        }
        if (!exited) {
            Log.e(TAG, "TURN sidecar did not exit after forced shutdown")
            onStatus("ERROR:sidecar stop timed out")
            return false
        }
        runCatching { stdin?.close() }
        stdin = null
        process = null
        worker?.interrupt()
        worker = null
        return true
    }

    private fun waitForExit(activeProcess: Process, timeoutMs: Long): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return runCatching {
                activeProcess.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
            }.getOrDefault(false)
        }
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        while (SystemClock.elapsedRealtime() < deadline) {
            if (runCatching { activeProcess.exitValue() }.isSuccess) return true
            SystemClock.sleep(PROCESS_POLL_INTERVAL_MS)
        }
        return runCatching { activeProcess.exitValue() }.isSuccess
    }

    private fun resolve(hostname: String) {
        val result = runCatching {
            val addresses = InetAddress.getAllByName(hostname)
            (addresses.firstOrNull { it is Inet4Address } ?: addresses.first()).hostAddress
        }.getOrNull().orEmpty()
        writeLine("RESOLVED:$result")
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
        private const val LEAVE_ACK_TIMEOUT_MS = 2000L
        private const val PROCESS_EXIT_TIMEOUT_MS = 1000L
        private const val FORCED_STOP_TIMEOUT_MS = 1000L
        private const val PROCESS_POLL_INTERVAL_MS = 25L
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
    private var lastStartAt = 0L

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

        if (activeProcess != null && !activeProcess.stop()) {
            emitStatus("ERROR:previous sidecar is still running")
            return false
        }
        val sinceLastStart = SystemClock.elapsedRealtime() - lastStartAt
        val debounceRemaining = RESTART_DEBOUNCE_MS - sinceLastStart
        if (lastStartAt != 0L && debounceRemaining > 0L) {
            runCatching { Thread.sleep(debounceRemaining) }
        }
        val nextProcess = TurnTunnelProcess(::emitStatus)
        val started = nextProcess.start(
            joinLink,
            displayName,
            tunnelMode,
            socksPort,
            socksUsername,
            socksPassword,
        )
        if (!started) {
            process = null
            activeSessionKey = null
            return false
        }
        process = nextProcess
        activeSessionKey = nextSessionKey
        lastStartAt = SystemClock.elapsedRealtime()
        return true
    }

    @Synchronized
    fun stop(): Boolean {
        val stopped = process?.stop() != false
        if (stopped) {
            process = null
            activeSessionKey = null
            lastStatus = "STOPPED"
        } else {
            emitStatus("ERROR:sidecar stop timed out")
        }
        return stopped
    }

    @Synchronized
    private fun emitStatus(status: String) {
        lastStatus = status
        onStatus?.invoke(status)
    }

    private const val RESTART_DEBOUNCE_MS = 2000L
}
