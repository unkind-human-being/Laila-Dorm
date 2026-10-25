package com.example.laila_dormitory_system

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs

object SmsEngine {
    const val PREFS = "laila_sms_native"
    const val KEY_QUEUE = "reminder_queue"
    const val KEY_RESULTS = "send_results"
    const val KEY_SCHEDULED = "schedule_enabled"

    const val ACTION_SMS_SENT =
        "YOUR_EXISTING_ANDROID_PACKAGE.LAILA_SMS_SENT"

    fun hasSendPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.SEND_SMS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun hasPhonePermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun getSimInfo(context: Context): List<Map<String, Any?>> {
        if (!hasPhonePermission(context)) {
            return emptyList()
        }

        val manager =
            context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
                as SubscriptionManager

        val defaultSubId =
            SubscriptionManager.getDefaultSmsSubscriptionId()

        val list = try {
            manager.activeSubscriptionInfoList ?: emptyList()
        } catch (_: SecurityException) {
            emptyList()
        }

        return list.map { info ->
            val display = info.displayName?.toString() ?: ""
            val carrier = info.carrierName?.toString() ?: ""

            mapOf(
                "subscriptionId" to info.subscriptionId,
                "slotIndex" to info.simSlotIndex,
                "displayName" to display,
                "carrierName" to carrier,
                "isDefault" to (info.subscriptionId == defaultSubId),
                "isTm" to isTmOrGlobe(display, carrier),
            )
        }
    }

    private fun isTmOrGlobe(
        display: String,
        carrier: String,
    ): Boolean {
        val text = "$display $carrier".lowercase()

        return text.contains("tm") ||
            text.contains("globe")
    }

    fun resolveSubscriptionId(
        context: Context,
        preferredSubId: Int,
    ): Int {
        if (!hasPhonePermission(context)) {
            return SubscriptionManager.getDefaultSmsSubscriptionId()
        }

        val manager =
            context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
                as SubscriptionManager

        val list = try {
            manager.activeSubscriptionInfoList ?: emptyList()
        } catch (_: SecurityException) {
            emptyList()
        }

        if (
            preferredSubId != SubscriptionManager.INVALID_SUBSCRIPTION_ID &&
            list.any { it.subscriptionId == preferredSubId }
        ) {
            return preferredSubId
        }

        // Prefer a SIM that identifies itself as TM or Globe.
        val tm = list.firstOrNull {
            isTmOrGlobe(
                it.displayName?.toString() ?: "",
                it.carrierName?.toString() ?: "",
            )
        }

        if (tm != null) {
            return tm.subscriptionId
        }

        val defaultId =
            SubscriptionManager.getDefaultSmsSubscriptionId()

        if (
            defaultId != SubscriptionManager.INVALID_SUBSCRIPTION_ID &&
            list.any { it.subscriptionId == defaultId }
        ) {
            return defaultId
        }

        return list.firstOrNull()?.subscriptionId
            ?: SubscriptionManager.INVALID_SUBSCRIPTION_ID
    }

    @Suppress("DEPRECATION")
    private fun smsManager(
        context: Context,
        subscriptionId: Int,
    ): SmsManager {
        if (subscriptionId == SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            throw IllegalStateException(
                "No active SMS SIM was found."
            )
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
                .createForSubscriptionId(subscriptionId)
        } else {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        }
    }

    fun sendSms(
        context: Context,
        number: String,
        message: String,
        name: String,
        residentKey: String,
        category: String,
        reminderKey: String,
        preferredSubId: Int,
    ): Boolean {
        if (!context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_TELEPHONY_MESSAGING
            )
        ) {
            throw UnsupportedOperationException(
                "This device does not support SMS messaging."
            )
        }

        if (!hasSendPermission(context)) {
            throw SecurityException(
                "SEND_SMS permission is required."
            )
        }

        if (number.isBlank()) {
            throw IllegalArgumentException(
                "The destination phone number is empty."
            )
        }

        if (message.isBlank()) {
            throw IllegalArgumentException(
                "The SMS message is empty."
            )
        }

        val subId =
            resolveSubscriptionId(
                context,
                preferredSubId,
            )

        val manager =
            smsManager(
                context,
                subId,
            )

        val messageId =
            "${System.currentTimeMillis()}_${abs((number + reminderKey).hashCode())}"

        val parts =
            manager.divideMessage(message)

        if (parts.isEmpty()) {
            throw IllegalArgumentException(
                "The SMS message could not be divided."
            )
        }

        val sentIntents =
            ArrayList<PendingIntent>()

        for (index in parts.indices) {
            val intent =
                Intent(
                    context,
                    SmsResultReceiver::class.java,
                ).apply {
                    action = ACTION_SMS_SENT

                    putExtra("messageId", messageId)
                    putExtra("number", number)
                    putExtra("message", message)
                    putExtra("name", name)
                    putExtra("residentKey", residentKey)
                    putExtra("category", category)
                    putExtra("reminderKey", reminderKey)
                    putExtra("subscriptionId", subId)
                    putExtra("partIndex", index)
                    putExtra("partCount", parts.size)
                }

            val requestCode =
                abs("$messageId:$index".hashCode())

            val pendingIntent =
                PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE,
                )

            sentIntents.add(pendingIntent)
        }

        if (parts.size == 1) {
            manager.sendTextMessage(
                number,
                null,
                message,
                sentIntents.first(),
                null,
            )
        } else {
            manager.sendMultipartTextMessage(
                number,
                null,
                parts,
                sentIntents,
                null,
            )
        }

        return true
    }

    fun saveReminderQueue(
        context: Context,
        json: String,
    ) {
        context.getSharedPreferences(
            PREFS,
            Context.MODE_PRIVATE,
        ).edit()
            .putString(KEY_QUEUE, json)
            .apply()
    }

    fun getReminderQueue(
        context: Context,
    ): String {
        return context.getSharedPreferences(
            PREFS,
            Context.MODE_PRIVATE,
        ).getString(
            KEY_QUEUE,
            "[]",
        ) ?: "[]"
    }

    fun setScheduleEnabled(
        context: Context,
        enabled: Boolean,
    ) {
        context.getSharedPreferences(
            PREFS,
            Context.MODE_PRIVATE,
        ).edit()
            .putBoolean(
                KEY_SCHEDULED,
                enabled,
            )
            .apply()
    }

    fun isScheduleEnabled(
        context: Context,
    ): Boolean {
        return context.getSharedPreferences(
            PREFS,
            Context.MODE_PRIVATE,
        ).getBoolean(
            KEY_SCHEDULED,
            false,
        )
    }

    fun appendFinalResult(
        context: Context,
        item: JSONObject,
    ) {
        val prefs =
            context.getSharedPreferences(
                PREFS,
                Context.MODE_PRIVATE,
            )

        synchronized(this) {
            val old =
                prefs.getString(
                    KEY_RESULTS,
                    "[]",
                ) ?: "[]"

            val oldArray =
                try {
                    JSONArray(old)
                } catch (_: Exception) {
                    JSONArray()
                }

            val newArray =
                JSONArray()

            // Keep only the latest 199 before appending.
            val start =
                (oldArray.length() - 199)
                    .coerceAtLeast(0)

            for (i in start until oldArray.length()) {
                newArray.put(
                    oldArray.get(i)
                )
            }

            newArray.put(item)

            prefs.edit()
                .putString(
                    KEY_RESULTS,
                    newArray.toString(),
                )
                .apply()
        }
    }

    fun drainSendResults(
        context: Context,
    ): String {
        val prefs =
            context.getSharedPreferences(
                PREFS,
                Context.MODE_PRIVATE,
            )

        synchronized(this) {
            val json =
                prefs.getString(
                    KEY_RESULTS,
                    "[]",
                ) ?: "[]"

            prefs.edit()
                .putString(
                    KEY_RESULTS,
                    "[]",
                )
                .apply()

            return json
        }
    }

    fun errorText(
        resultCode: Int,
    ): String {
        return when (resultCode) {
            Activity.RESULT_OK ->
                "Sent"

            SmsManager.RESULT_ERROR_GENERIC_FAILURE ->
                "Generic failure. Check SIM load/promo, signal, and SMS settings."

            SmsManager.RESULT_ERROR_RADIO_OFF ->
                "Mobile radio is turned off."

            SmsManager.RESULT_ERROR_NULL_PDU ->
                "SMS PDU error."

            SmsManager.RESULT_ERROR_NO_SERVICE ->
                "No mobile service."

            SmsManager.RESULT_ERROR_LIMIT_EXCEEDED ->
                "Android SMS sending limit was reached."

            SmsManager.RESULT_ERROR_FDN_CHECK_FAILURE ->
                "Fixed Dialing Number restriction blocked the SMS."

            else ->
                "SMS failed with Android error code $resultCode."
        }
    }
}
