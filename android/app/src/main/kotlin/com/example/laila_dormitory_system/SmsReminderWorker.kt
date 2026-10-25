package com.example.laila_dormitory_system

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject

class SmsReminderWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(
    appContext,
    workerParams,
) {
    override fun doWork(): Result {
        if (
            ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.SEND_SMS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return Result.failure()
        }

        val prefs =
            applicationContext.getSharedPreferences(
                SmsEngine.PREFS,
                Context.MODE_PRIVATE,
            )

        val queue =
            try {
                JSONArray(
                    SmsEngine.getReminderQueue(
                        applicationContext
                    )
                )
            } catch (_: Exception) {
                JSONArray()
            }

        val now =
            System.currentTimeMillis()

        var attempted = 0

        for (index in 0 until queue.length()) {
            if (attempted >= 50) {
                break
            }

            val job =
                queue.optJSONObject(index)
                    ?: continue

            if (!job.optBoolean("enabled", true)) {
                continue
            }

            val reminderKey =
                job.optString(
                    "reminderKey",
                    "",
                )

            if (reminderKey.isBlank()) {
                continue
            }

            val repeatDays =
                job.optInt(
                    "repeatDays",
                    0,
                )

            val lastSent =
                prefs.getLong(
                    "last_sent_$reminderKey",
                    0L,
                )

            if (repeatDays <= 0) {
                // One-time reminder for this billing state.
                if (lastSent > 0L) {
                    continue
                }
            } else {
                val repeatMillis =
                    repeatDays.toLong() *
                        24L *
                        60L *
                        60L *
                        1000L

                if (
                    lastSent > 0L &&
                    now - lastSent < repeatMillis
                ) {
                    continue
                }
            }

            // Prevent duplicate attempts if WorkManager is restarted/retried.
            val lastAttempt =
                prefs.getLong(
                    "last_attempt_$reminderKey",
                    0L,
                )

            val twelveHours =
                12L *
                    60L *
                    60L *
                    1000L

            if (
                lastAttempt > 0L &&
                now - lastAttempt < twelveHours
            ) {
                continue
            }

            val number =
                job.optString(
                    "number",
                    "",
                )

            val message =
                job.optString(
                    "message",
                    "",
                )

            if (
                number.isBlank() ||
                message.isBlank()
            ) {
                continue
            }

            val preferredSubId =
                job.optInt(
                    "subscriptionId",
                    -1,
                )

            prefs.edit()
                .putLong(
                    "last_attempt_$reminderKey",
                    now,
                )
                .apply()

            try {
                SmsEngine.sendSms(
                    context = applicationContext,
                    number = number,
                    message = message,
                    name = job.optString(
                        "name",
                        "",
                    ),
                    residentKey = job.optString(
                        "residentKey",
                        "",
                    ),
                    category = job.optString(
                        "category",
                        "",
                    ),
                    reminderKey = reminderKey,
                    preferredSubId = preferredSubId,
                )

                attempted++

                // Keep automated messages slightly spaced out.
                Thread.sleep(1000L)
            } catch (e: Exception) {
                prefs.edit()
                    .remove(
                        "last_attempt_$reminderKey"
                    )
                    .apply()

                SmsEngine.appendFinalResult(
                    applicationContext,
                    JSONObject().apply {
                        put(
                            "messageId",
                            "failed_${System.currentTimeMillis()}_$index",
                        )

                        put(
                            "residentKey",
                            job.optString(
                                "residentKey",
                                "",
                            ),
                        )

                        put(
                            "name",
                            job.optString(
                                "name",
                                "",
                            ),
                        )

                        put(
                            "number",
                            number,
                        )

                        put(
                            "message",
                            message,
                        )

                        put(
                            "category",
                            job.optString(
                                "category",
                                "",
                            ),
                        )

                        put(
                            "reminderKey",
                            reminderKey,
                        )

                        put(
                            "status",
                            "failed",
                        )

                        put(
                            "error",
                            e.message
                                ?: "SMS could not be queued.",
                        )

                        put(
                            "at",
                            System.currentTimeMillis(),
                        )
                    }
                )
            }
        }

        return Result.success()
    }
}
