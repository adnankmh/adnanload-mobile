package com.adnanload.adnanload_mobile

import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/** Optional overlay, visible only after explicit Android user authorization.
 * This does not read other apps' network traffic or hidden clipboard.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "adnanload/quick_capture"
    private var bridge: MethodChannel? = null
    private var bubble: View? = null
    private var windowManager: WindowManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        bridge?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(Settings.canDrawOverlays(this))
                }
                "enableBubble" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.error("OVERLAY_PERMISSION", "Allow display over other apps first", null)
                    } else {
                        showBubble()
                        result.success(true)
                    }
                }
                "disableBubble" -> { hideBubble(); result.success(true) }
                "initialLink" -> result.success(incomingLink(intent))
                else -> result.notImplemented()
            }
        }
    }

    private fun incomingLink(source: Intent?): String? {
        if (source?.action != Intent.ACTION_VIEW) return null
        val data = source.data ?: return null
        if (data.scheme != "http" && data.scheme != "https") return null
        return data.toString()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        incomingLink(intent)?.let { bridge?.invokeMethod("incomingLink", it) }
        if (intent.getBooleanExtra("quick_capture", false)) {
            bridge?.invokeMethod("bubbleTapped", true)
        }
    }

    private fun showBubble() {
        if (bubble != null) return
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm
        val size = (56 * resources.displayMetrics.density).toInt()
        val pad = (8 * resources.displayMetrics.density).toInt()
        val label = TextView(this).apply {
            text = "↓"
            textSize = 29f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(10, 105, 139))
                setStroke((2 * resources.displayMetrics.density).toInt(),
                    Color.rgb(214, 241, 249))
            }
            elevation = 9f * resources.displayMetrics.density
            contentDescription = "ADNANLOAD quick capture"
        }
        val params = WindowManager.LayoutParams(
            size, size,
            if (Build.VERSION.SDK_INT >= 26)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = pad
            y = (190 * resources.displayMetrics.density).toInt()
        }
        var downRawX = 0f
        var downRawY = 0f
        var downX = 0
        var downY = 0
        var dragged = false
        label.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX; downRawY = event.rawY
                    downX = params.x; downY = params.y
                    dragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downRawX).toInt()
                    val dy = (event.rawY - downRawY).toInt()
                    if (abs(dx) > 9 || abs(dy) > 9) dragged = true
                    if (dragged) {
                        params.x = (downX - dx).coerceAtLeast(0)
                        params.y = (downY + dy).coerceAtLeast(0)
                        try { wm.updateViewLayout(label, params) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragged) {
                        val open = Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            putExtra("quick_capture", true)
                        }
                        startActivity(open)
                    }
                    true
                }
                else -> false
            }
        }
        wm.addView(label, params)
        bubble = label
    }

    private fun hideBubble() {
        val view = bubble ?: return
        bubble = null
        try { windowManager?.removeViewImmediate(view) } catch (_: Exception) {}
    }

    override fun onDestroy() {
        hideBubble()
        bridge?.setMethodCallHandler(null)
        bridge = null
        super.onDestroy()
    }
}
