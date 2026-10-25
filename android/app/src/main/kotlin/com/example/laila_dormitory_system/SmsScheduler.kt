package com.example.laila_dormitory_system

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

object SmsScheduler {
    private const val DAILY_WORK =
        "laila_daily_sms_reminders"

    private const val MANUAL_WORK =
        "laila_manual_sms_reminder_run"

    fun scheduleDaily(
        context: Context,
        hour: Int,
        minute: Int,
    ) {
        val safeHour =
            hour.coerceIn(
                0,
                23,
            )

        val safeMinute =
            minute.coerceIn(
                0,
                59,
            )

        val now =
            Calendar.getInstance()

        val next =
            Calendar.getInstance().apply {
                set(
                    Calendar.HOUR_OF_DAY,
                    safeHour,
                )

                set(
                    Calendar.MINUTE,
                    safeMinute,
                )

                set(
                    Calendar.SECOND,
                    0,
                )

                set(
                    Calendar.MILLISECOND,
                    0,
                )

                if (!after(now)) {
                    add(
                        Calendar.DAY_OF_YEAR,
                        1,
                    )
                }
            }

        val delayMillis =
            next.timeInMillis -
                now.timeInMillis

        val request =
            PeriodicWorkRequestBuilder<
                SmsReminderWorker
            >(
                24,
                TimeUnit.HOURS,
            )
                .setInitialDelay(
                    delayMillis,
                    TimeUnit.MILLISECONDS,
                )
                .build()

        WorkManager
            .getInstance(context)
            .enqueueUniquePeriodicWork(
                DAILY_WORK,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )

        SmsEngine.setScheduleEnabled(
            context,
            true,
        )
    }

    fun cancelDaily(
        context: Context,
    ) {
        WorkManager
            .getInstance(context)
            .cancelUniqueWork(
                DAILY_WORK
            )

        SmsEngine.setScheduleEnabled(
            context,
            false,
        )
    }

    fun runNow(
        context: Context,
    ) {
        val request =
            OneTimeWorkRequestBuilder<
                SmsReminderWorker
            >()
                .build()

        WorkManager
            .getInstance(context)
            .enqueueUniqueWork(
                MANUAL_WORK,
                ExistingWorkPolicy.REPLACE,
                request,
            )
    }
}
