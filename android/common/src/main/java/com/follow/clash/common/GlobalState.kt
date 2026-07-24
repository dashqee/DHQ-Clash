package com.follow.clash.common


import android.app.Application
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

object GlobalState : CoroutineScope by CoroutineScope(Dispatchers.Default) {

    const val NOTIFICATION_CHANNEL = "DHQClash"

    const val NOTIFICATION_ID = 1

    val packageName: String
        get() = application.packageName

    val RECEIVE_BROADCASTS_PERMISSIONS: String
        get() = "${packageName}.permission.RECEIVE_BROADCASTS"


    private var _application: Application? = null

    val application: Application
        get() = _application!!


    fun log(text: String) {
        Log.d("[DHQClash]", text)
    }

    fun init(application: Application) {
        _application = application
    }

    // Firebase/Crashlytics is removed in this fork (upstream reported crashes to
    // its own Firebase project). Kept as a no-op so the settings plumbing that
    // forwards the toggle keeps compiling.
    @Suppress("UNUSED_PARAMETER")
    fun setCrashlytics(enable: Boolean) {
    }
}
