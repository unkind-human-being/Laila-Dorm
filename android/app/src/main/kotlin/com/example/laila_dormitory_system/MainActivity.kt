package com.example.laila_dormitory_system

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "laila_dormitory/sms"
        private const val REQUEST_SMS_PERMISSIONS = 9101
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> requestSmsPermissions(result)

                "getSimInfo" -> {
                    try {
                        result.success(SmsEngine.getSimInfo(this))
                    } catch (e: Exception) {
                        result.error("SIM_ERROR", e.message, null)
                    }
                }

                "sendSms" -> {
                    val number = call.argument<String>("number") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val name = call.argument<String>("name") ?: ""
                    val residentKey = call.argument<String>("residentKey") ?: ""
                    val category = call.argument<String>("category") ?: "manual"
                    val reminderKey = call.argument<String>("reminderKey") ?: ""
                    val preferredSubId =
                        call.argument<Int>("subscriptionId")
                            ?: SubscriptionManager.INVALID_SUBSCRIPTION_ID

                    try {
                        val queued = SmsEngine.sendSms(
                            context = this,
                            number = number,
                            message = message,
                            name = name,
                            residentKey = residentKey,
                            category = category,
                            reminderKey = reminderKey,
                            preferredSubId = preferredSubId,
                        )
                        result.success(queued)
                    } catch (e: SecurityException) {
                        result.error(
                            "SMS_PERMISSION",
                            "SMS permission has not been granted.",
                            null,
                        )
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
                    }
                }

                "saveReminderQueue" -> {
                    val json = call.argument<String>("json") ?: "[]"
                    SmsEngine.saveReminderQueue(this, json)
                    result.success(true)
                }

                "scheduleDaily" -> {
                    val hour = call.argument<Int>("hour") ?: 9
                    val minute = call.argument<Int>("minute") ?: 0
                    SmsScheduler.scheduleDaily(
                        context = this,
                        hour = hour,
                        minute = minute,
                    )
                    result.success(true)
                }

                "cancelDaily" -> {
                    SmsScheduler.cancelDaily(this)
                    result.success(true)
                }

                "runAutomationNow" -> {
                    SmsScheduler.runNow(this)
                    result.success(true)
                }

                "drainSendResults" -> {
                    result.success(SmsEngine.drainSendResults(this))
                }

                "smsStatus" -> {
                    result.success(
                        mapOf(
                            "sendPermission" to hasPermission(Manifest.permission.SEND_SMS),
                            "phonePermission" to hasPermission(Manifest.permission.READ_PHONE_STATE),
                            "scheduled" to SmsEngine.isScheduleEnabled(this),
                        )
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            permission,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermissions(result: MethodChannel.Result) {
        val permissions = mutableListOf<String>()

        if (!hasPermission(Manifest.permission.SEND_SMS)) {
            permissions.add(Manifest.permission.SEND_SMS)
        }

        if (!hasPermission(Manifest.permission.READ_PHONE_STATE)) {
            permissions.add(Manifest.permission.READ_PHONE_STATE)
        }

        if (permissions.isEmpty()) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "PERMISSION_PENDING",
                "A permission request is already open.",
                null,
            )
            return
        }

        pendingPermissionResult = result

        requestPermissions(
            permissions.toTypedArray(),
            REQUEST_SMS_PERMISSIONS,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        )

        if (requestCode == REQUEST_SMS_PERMISSIONS) {
            val granted =
                hasPermission(Manifest.permission.SEND_SMS) &&
                    hasPermission(Manifest.permission.READ_PHONE_STATE)

            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
