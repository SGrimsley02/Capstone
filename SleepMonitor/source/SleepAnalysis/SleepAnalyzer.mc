/*
Name: source/SleepAnalysis/SleepAnalyzer.mc
Description: Sleep analysis logic for the SleepMonitor watch app.
             Contains methods to build a sleep summary payload based on recent sensor data
             and estimate sleep quality.
Authors: Lauren D'Souza
Created: February 21st, 2026
Last Modified: March 1st, 2026
*/

import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;

module SleepAnalyzer {   

    function buildSleepPayload(userId as String) as Dictionary or Null {
        // Create simulated sleep payload values (placeholder for now)

        var now = System.getClockTime();
        var ts = now.hour.toString() + ":" + now.min.toString() + ":" + now.sec.toString();

        // Build a nightly sleep summary for the last sleep window based on heart rate/body battery.
        var window = new Time.Duration(SLEEP_WINDOW_SECONDS);
        var hrIterator = getHeartRateIterator(window);
        if (hrIterator == null) {
            return null;
        }

        var hrSummary = summarizeSensorHistory(hrIterator);
        if (hrSummary == null) {
            return null;
        }

        var bbIterator = getHeartRateIterator(window);
        if (bbIterator == null) {
            return null;
        }

        var bbSummary = summarizeSensorHistory(bbIterator);
        if (bbSummary == null) {
            return null;
        }

        var sleepQuality = estimateSleepQuality(hrSummary, bbSummary);

        var payload = {
            "eventType" => "sleep_summary",
            "timestamp" => ts,
            "username" => userId,
            "sleepQuality" => sleepQuality
        };

        var stressIterator = getStressIterator(window);
        if (stressIterator != null) {
            var stressSummary = summarizeSensorHistory(stressIterator);
            if (stressSummary != null) {
                payload["stressAvg"] = stressSummary["avg"];
                payload["stressSamples"] = stressSummary["count"];
            }
        }

        return payload;
    }

    function getHeartRateIterator(window as Time.Duration)
        as SensorHistory.SensorHistoryIterator or Null {
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getHeartRateHistory)) {
            return SensorHistory.getHeartRateHistory({
                :period => window,
                :order => SensorHistory.ORDER_OLDEST_FIRST
            });
        }

        return null;
    }

    function getStressIterator(window as Time.Duration)
        as SensorHistory.SensorHistoryIterator or Null {
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory)) {
            return SensorHistory.getStressHistory({
                :period => window,
                :order => SensorHistory.ORDER_OLDEST_FIRST
            });
        }

        return null;
    }

    function getBodyBatteryIterator(window as Time.Duration)
        as SensorHistory.SensorHistoryIterator or Null {
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
            return SensorHistory.getBodyBatteryHistory({
                :period => window,
                :order => SensorHistory.ORDER_OLDEST_FIRST
            });
        }

        return null;
    }

    function summarizeSensorHistory(
        iter as SensorHistory.SensorHistoryIterator
    ) as Dictionary or Null {
        var count = 0;
        var sum = 0.0;
        var minValue = 999999;
        var maxValue = 0;

        var sample = iter.next();
        var lastSample = sample;
        while (sample != null) {
            var value = sample.data;
            if (value != null) {
                sum += value;
                count += 1;
                if (value < minValue) {
                    minValue = value;
                }
                if (value > maxValue) {
                    maxValue = value;
                }
            }
            lastSample = sample;
            sample = iter.next();
        }

        if (count == 0) {
            return null;
        }

        var avg = sum / count;
        return {
            "avg" => avg,
            "min" => minValue,
            "max" => maxValue,
            "count" => count,
            "lastSample" => lastSample
        };
    }

    function estimateSleepQuality(
        hrSummary as Dictionary,
        bbSummary as Dictionary
    ) as Number {
        // Placeholder sleep quality estimation logic based on HR and Body Battery summaries.
        // This should be improved in the future.
        var bbRecovery = bbSummary["max"] - bbSummary["min"];
        return bbRecovery*1.1;

    }
}