package dev.manishpanday.input_language

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.inputmethod.InputMethodInfo
import android.view.inputmethod.InputMethodManager
import android.view.inputmethod.InputMethodSubtype
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale

/**
 * Android implementation of input_language.
 *
 * Reads [InputMethodManager.getCurrentInputMethodSubtype] (the language the
 * current IME says it is typing in). Android has no broadcast for subtype
 * changes, so while Dart listens the plugin polls the subtype (a cheap binder
 * call) and also reacts to [Intent.ACTION_INPUT_METHOD_CHANGED] for IME
 * switches. Apps cannot switch the IME or its subtype, so `setLanguage`
 * reports `unsupported`.
 */
class InputLanguagePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var context: Context
  private val handler = Handler(Looper.getMainLooper())
  private var sink: EventChannel.EventSink? = null
  private var receiver: BroadcastReceiver? = null
  private var pollIntervalMs = 500L
  private var hasSent = false
  private var lastSent: Map<String, Any?>? = null

  private val poll = object : Runnable {
    override fun run() {
      emitIfChanged()
      if (sink != null) handler.postDelayed(this, pollIntervalMs)
    }
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "dev.manishpanday/input_language")
    methodChannel.setMethodCallHandler(this)
    eventChannel = EventChannel(binding.binaryMessenger, "dev.manishpanday/input_language/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    stopWatching()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getCurrent" -> result.success(currentPayload())
      "getAvailable" -> result.success(availablePayloads())
      "setLanguage" -> result.error(
        "unsupported",
        "Android does not allow apps to change the keyboard (IME) or its language.",
        null,
      )
      "getCapabilities" -> result.success(
        mapOf(
          "canReadCurrent" to true,
          "canObserveChanges" to true,
          "canListAvailable" to true,
          "canSetLanguage" to false,
          "requiresFocusedTextField" to false,
          "isWeakHint" to false,
        ),
      )
      else -> result.notImplemented()
    }
  }

  // Reading

  private val inputMethodManager: InputMethodManager?
    get() = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager

  private fun currentImeId(): String? =
    try {
      Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
    } catch (e: SecurityException) {
      null
    }

  private fun imeInfo(id: String?): InputMethodInfo? {
    if (id == null) return null
    return try {
      inputMethodManager?.enabledInputMethodList?.firstOrNull { it.id == id }
    } catch (e: RuntimeException) {
      null
    }
  }

  private fun languageTagOf(subtype: InputMethodSubtype): String? {
    val tag = subtype.languageTag
    if (tag.isNotEmpty()) return tag
    @Suppress("DEPRECATION")
    val legacy = subtype.locale
    if (legacy.isNullOrEmpty()) return null
    return Locale.forLanguageTag(legacy.replace('_', '-')).toLanguageTag().takeIf { it != "und" }
      ?: legacy.replace('_', '-')
  }

  private fun payload(subtype: InputMethodSubtype?, ime: InputMethodInfo?): Map<String, Any?>? {
    if (subtype == null) return null
    val tag = languageTagOf(subtype) ?: return null
    val displayName: String? = try {
      if (ime != null) {
        subtype.getDisplayName(context, ime.packageName, ime.serviceInfo.applicationInfo)?.toString()
      } else {
        null
      }
    } catch (e: RuntimeException) {
      null
    }?.takeIf { it.isNotBlank() } ?: Locale.forLanguageTag(tag).displayName.takeIf { it.isNotBlank() }
    val sourceId = listOfNotNull(ime?.id, subtype.hashCode().toString()).joinToString("#")
    return mapOf(
      "languageTag" to tag,
      "displayName" to displayName,
      "inputSourceId" to sourceId,
      "source" to "inputMethod",
    )
  }

  private fun currentPayload(): Map<String, Any?>? {
    val imm = inputMethodManager ?: return null
    val subtype = try {
      imm.currentInputMethodSubtype
    } catch (e: RuntimeException) {
      null
    }
    return payload(subtype, imeInfo(currentImeId()))
  }

  private fun availablePayloads(): List<Map<String, Any?>> {
    val imm = inputMethodManager ?: return emptyList()
    val currentId = currentImeId()
    val imes = try {
      imm.enabledInputMethodList ?: emptyList()
    } catch (e: RuntimeException) {
      emptyList()
    }
    // The current IME first, then the others.
    val ordered = imes.sortedBy { if (it.id == currentId) 0 else 1 }
    val result = mutableListOf<Map<String, Any?>>()
    for (ime in ordered) {
      val subtypes = try {
        imm.getEnabledInputMethodSubtypeList(ime, true) ?: emptyList()
      } catch (e: RuntimeException) {
        emptyList()
      }
      for (subtype in subtypes) {
        if (subtype.mode.isNotEmpty() && subtype.mode != "keyboard") continue
        payload(subtype, ime)?.let { result.add(it) }
      }
    }
    return result
  }

  // Observing

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    stopWatching()
    sink = events
    hasSent = false
    lastSent = null
    val requested = ((arguments as? Map<*, *>)?.get("pollIntervalMs") as? Number)?.toLong()
    pollIntervalMs = (requested ?: 500L).coerceAtLeast(100L)
    val r = object : BroadcastReceiver() {
      override fun onReceive(ctx: Context?, intent: Intent?) {
        emitIfChanged()
      }
    }
    val filter = IntentFilter(Intent.ACTION_INPUT_METHOD_CHANGED)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
    } else {
      @Suppress("UnspecifiedRegisterReceiverFlag")
      context.registerReceiver(r, filter)
    }
    receiver = r
    handler.removeCallbacks(poll)
    handler.post(poll)
  }

  override fun onCancel(arguments: Any?) {
    stopWatching()
  }

  private fun stopWatching() {
    sink = null
    handler.removeCallbacks(poll)
    receiver?.let {
      try {
        context.unregisterReceiver(it)
      } catch (e: IllegalArgumentException) {
        // Already unregistered.
      }
    }
    receiver = null
  }

  private fun emitIfChanged() {
    val events = sink ?: return
    val current = currentPayload()
    if (hasSent && current == lastSent) return
    hasSent = true
    lastSent = current
    events.success(current)
  }
}
