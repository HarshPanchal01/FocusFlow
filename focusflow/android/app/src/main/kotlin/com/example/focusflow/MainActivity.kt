package com.example.focusflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private var phoneActivityEventSink: EventChannel.EventSink? = null

    private val phoneActivityReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val sink = phoneActivityEventSink ?: return
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> sink.success("screen_off")
                Intent.ACTION_SCREEN_ON -> sink.success("screen_on")
                Intent.ACTION_USER_PRESENT -> sink.success("user_present")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "focusflow/phone_activity"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                phoneActivityEventSink = events
                val filter = IntentFilter().apply {
                    addAction(Intent.ACTION_SCREEN_OFF)
                    addAction(Intent.ACTION_SCREEN_ON)
                    addAction(Intent.ACTION_USER_PRESENT)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(phoneActivityReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("DEPRECATION")
                    registerReceiver(phoneActivityReceiver, filter)
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    unregisterReceiver(phoneActivityReceiver)
                } catch (_: Exception) {
                }
                phoneActivityEventSink = null
            }
        })
    }
}
