package com.example.laila_dormitory_system

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

class SmsResultReceiver :
    BroadcastReceiver() {

    companion object {
        private val lock =
            Any()
    }

    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (
            intent.action !=
            SmsEngine.ACTION_SMS_SENT
        ) {
            return
        }

        val messageId =
            intent.getStringExtra(
                "messageId",
            ) ?: return

        val partCount =
            intent.getIntExtra(
                "partCount",
                1,
            )

        val reminderKey =
            intent.getStringExtra(
                "reminderKey",
            ) ?: ""

        val prefs =
            context.getSharedPreferences(
                SmsEngine.PREFS,
                Context.MODE_PRIVATE,
            )

        val aggregateKey =
            "part_result_$messageId"

        synchronized(lock) {
            val existing =
                try {
                    JSONObject(
                        prefs.getString(
                            aggregateKey,
                            "{}",
                        ) ?: "{}",
                    )
                } catch (
                    _: Exception,
                ) {
                    JSONObject()
                }

            val received =
                existing.optInt(
                    "received",
                    0,
                ) + 1

            val previouslyFailed =
                existing.optBoolean(
                    "failed",
                    false,
                )

            val thisFailed =
                resultCode !=
                    Activity.RESULT_OK

            val failed =
                previouslyFailed ||
                    thisFailed

            val error =
                if (thisFailed) {
                    SmsEngine.errorText(
                        resultCode,
                    )
                } else {
                    existing.optString(
                        "error",
                        "",
                    )
                }

            existing.put(
                "received",
                received,
            )

            existing.put(
                "failed",
                failed,
            )

            existing.put(
                "error",
                error,
            )

            // =================================================
            // WAIT FOR ALL SMS PARTS
            // =================================================

            if (received < partCount) {
                prefs.edit()
                    .putString(
                        aggregateKey,
                        existing.toString(),
                    )
                    .apply()

                return
            }

            prefs.edit()
                .remove(
                    aggregateKey,
                )
                .apply()

            // =================================================
            // FINAL SMS RESULT
            // =================================================

            val now =
                System.currentTimeMillis()

            val finalResult =
                JSONObject().apply {

                    put(
                        "messageId",
                        messageId,
                    )

                    put(
                        "residentKey",
                        intent.getStringExtra(
                            "residentKey",
                        ) ?: "",
                    )

                    put(
                        "name",
                        intent.getStringExtra(
                            "name",
                        ) ?: "",
                    )

                    put(
                        "number",
                        intent.getStringExtra(
                            "number",
                        ) ?: "",
                    )

                    put(
                        "message",
                        intent.getStringExtra(
                            "message",
                        ) ?: "",
                    )

                    put(
                        "category",
                        intent.getStringExtra(
                            "category",
                        ) ?: "",
                    )

                    put(
                        "reminderKey",
                        reminderKey,
                    )

                    put(
                        "subscriptionId",
                        intent.getIntExtra(
                            "subscriptionId",
                            -1,
                        ),
                    )

                    put(
                        "status",
                        if (failed) {
                            "failed"
                        } else {
                            "sent"
                        },
                    )

                    // ==========================================
                    // THIS WAS THE BROKEN PART
                    // ==========================================

                    put(
                        "error",
                        if (failed) {
                            error
                        } else {
                            ""
                        },
                    )

                    put(
                        "at",
                        now,
                    )
                }

            // =================================================
            // SAVE RESULT
            // =================================================

            SmsEngine.appendFinalResult(
                context,
                finalResult,
            )

            // =================================================
            // MARK REMINDER AS SENT
            // =================================================

            if (
                !failed &&
                reminderKey.isNotBlank()
            ) {
                prefs.edit()
                    .putLong(
                        "last_sent_$reminderKey",
                        now,
                    )
                    .remove(
                        "last_attempt_$reminderKey",
                    )
                    .apply()
            }
        }
    }
}