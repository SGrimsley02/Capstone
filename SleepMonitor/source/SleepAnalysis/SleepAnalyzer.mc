/*
Name: source/SleepAnalysis/SleepAnalyzer.mc
Description: Sleep analysis logic for the SleepMonitor watch app.
             Contains methods to build a sleep summary payload based on recent sensor data
             and estimate sleep quality.
Authors: Lauren D'Souza
Created: February 21st, 2026
Last Modified: March 15th, 2026
*/

import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Math;

module SleepAnalyzer {
    const SLEEP_WINDOW_SECONDS = 12 * 60 * 60;   // Analyze last 12 hours
    const MIN_REST_BLOCK_MINUTES = 90;           // Minimum block to count as likely sleep
    const STRESS_SLEEP_THRESHOLD = 25;           // Lower stress = more likely asleep
    const DEFAULT_CYCLE_MINUTES = 90;            // Fallback sleep cycle length

    function buildSleepPayload(userId as String) as Dictionary or Null {
        var window = new Time.Duration(SLEEP_WINDOW_SECONDS);

        var bbSamples = collectSensorSamples(getBodyBatteryIterator(window));
        if (bbSamples == null || bbSamples.size() == 0) {
            return null;
        }

        var hrSamples = collectSensorSamples(getHeartRateIterator(window));
        var stressSamples = collectSensorSamples(getStressIterator(window));

        var bbSummary = summarizeSamples(bbSamples);
        if (bbSummary == null) {
            return null;
        }

        var hrSummary = summarizeSamples(hrSamples);
        var stressSummary = summarizeSamples(stressSamples);

        var restWindow = estimateRestWindow(stressSamples, hrSamples, bbSamples);
        var isSleeping = isLikelySleeping(hrSummary, stressSummary, bbSummary);

        var sleepQuality = estimateSleepQuality(hrSummary, stressSummary, bbSummary, restWindow);

        var payload = {
            "eventType" => "sleep_summary",
            "username" => userId,
            "sleepQuality" => sleepQuality
        };

        if (stressSummary != null) {
            payload["stressAvg"] = stressSummary["avg"];
        }

        if (hrSummary != null) {
            payload["hrAvg"] = hrSummary["avg"];
            payload["hrMin"] = hrSummary["min"];
        }

        payload["bodyBatteryStart"] = bbSummary["first"];
        payload["bodyBatteryEnd"] = bbSummary["last"];
        payload["bodyBatteryRecovery"] = bbSummary["last"] - bbSummary["first"];

        if (isSleeping && restWindow != null && restWindow["isFallback"] != true) {
            var stage = estimateSleepStage(restWindow);
            var handoffEpoch = estimateHandoffEpoch(restWindow);

            payload["sleepDetected"] = true;
            payload["restDurationMinutes"] = restWindow["durationMinutes"];
            payload["estimatedSleepStartEpochSec"] = restWindow["startSec"];
            payload["estimatedSleepEndEpochSec"] = restWindow["endSec"];
            payload["estimatedSleepStage"] = stage;
            payload["recommendedHandoffEpochSec"] = handoffEpoch;

        } else {
            payload["sleepDetected"] = false;
            payload["estimatedSleepStage"] = "unknown";

            // fallback wake time (30 minutes from now)
            var nowSec = Time.now().value();
            var fallback = nowSec + (30 * 60);

            payload["fallbackHandoffEpochSec"] = fallback;
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

    function collectSensorSamples(
        iter as SensorHistory.SensorHistoryIterator or Null
    ) as Array<Dictionary> or Null {
        if (iter == null) {
            return null;
        }

        var samples = [];
        var sample = iter.next();

        while (sample != null) {
            if (sample.data != null && sample.when != null) {
                samples.add({
                    "value" => sample.data,
                    "when" => sample.when,
                    "epochMs" => sample.when.value()
                });
            }
            sample = iter.next();
        }

        return samples;
    }

    function summarizeSamples(samples as Array<Dictionary> or Null) as Dictionary or Null {
        if (samples == null || samples.size() == 0) {
            return null;
        }

        var count = 0;
        var sum = 0.0;
        var minValue = 999999;
        var maxValue = -999999;

        var firstValue = samples[0]["value"];
        var lastValue = samples[samples.size() - 1]["value"];

        for (var i = 0; i < samples.size(); i += 1) {
            var value = samples[i]["value"];
            sum += value;
            count += 1;

            if (value < minValue) {
                minValue = value;
            }
            if (value > maxValue) {
                maxValue = value;
            }
        }

        if (count == 0) {
            return null;
        }

        return {
            "avg" => sum / count,
            "min" => minValue,
            "max" => maxValue,
            "count" => count,
            "first" => firstValue,
            "last" => lastValue
        };
    }

    function estimateRestWindow(
        stressSamples as Array<Dictionary> or Null,
        hrSamples as Array<Dictionary> or Null,
        bbSamples as Array<Dictionary>
    ) as Dictionary or Null {

        // Primary path: use longest low-stress block
        if (stressSamples != null && stressSamples.size() > 0) {
            var bestStartMs = null;
            var bestEndMs = null;
            var currentStartMs = null;
            var currentEndMs = null;

            for (var i = 0; i < stressSamples.size(); i += 1) {
                var stressValue = stressSamples[i]["value"];
                var epochMs = stressSamples[i]["epochMs"];

                if (stressValue <= STRESS_SLEEP_THRESHOLD) {
                    if (currentStartMs == null) {
                        currentStartMs = epochMs;
                    }
                    currentEndMs = epochMs;
                } else {
                    if (currentStartMs != null && isBetterBlock(currentStartMs, currentEndMs, bestStartMs, bestEndMs)) {
                        bestStartMs = currentStartMs;
                        bestEndMs = currentEndMs;
                    }
                    currentStartMs = null;
                    currentEndMs = null;
                }
            }

            if (currentStartMs != null && isBetterBlock(currentStartMs, currentEndMs, bestStartMs, bestEndMs)) {
                bestStartMs = currentStartMs;
                bestEndMs = currentEndMs;
            }

            if (bestStartMs != null && bestEndMs != null) {
                var durationMinutes = (bestEndMs - bestStartMs) / 60000.0;
                if (durationMinutes >= MIN_REST_BLOCK_MINUTES) {
                    return {
                        "startMs" => bestStartMs,
                        "endMs" => bestEndMs,
                        "durationMinutes" => durationMinutes
                    };
                }
            }
        }

        // Fallback path: if no stress block, use the last ~90 minutes ending at latest body battery sample
        if (bbSamples.size() > 0) {
            var fallbackEndMs = bbSamples[bbSamples.size() - 1]["epochMs"];
            var fallbackStartMs = fallbackEndMs - (DEFAULT_CYCLE_MINUTES * 60 * 1000);

            return {
                "startMs" => fallbackStartMs,
                "endMs" => fallbackEndMs,
                "durationMinutes" => DEFAULT_CYCLE_MINUTES
            };
        }

        return null;
    }

    function isBetterBlock(
        currentStartMs as Number or Null,
        currentEndMs as Number or Null,
        bestStartMs as Number or Null,
        bestEndMs as Number or Null
    ) as Boolean {
        if (currentStartMs == null || currentEndMs == null) {
            return false;
        }

        if (bestStartMs == null || bestEndMs == null) {
            return true;
        }

        var currentDuration = currentEndMs - currentStartMs;
        var bestDuration = bestEndMs - bestStartMs;

        return currentDuration > bestDuration;
    }

    function estimateSleepStage(restWindow as Dictionary) as String {
        var elapsedMinutes = restWindow["durationMinutes"] % DEFAULT_CYCLE_MINUTES;

        if (elapsedMinutes < 20) {
            return "light";
        } else if (elapsedMinutes < 50) {
            return "deep";
        } else if (elapsedMinutes < 70) {
            return "rem";
        } else {
            return "light";
        }
    }

    function estimateHandoffEpoch(restWindow as Dictionary) as Number {
        var elapsedMinutes = restWindow["durationMinutes"];
        var cyclesCompleted = elapsedMinutes / DEFAULT_CYCLE_MINUTES;
        var nextBoundaryMinutes = (Math.floor(cyclesCompleted) + 1) * DEFAULT_CYCLE_MINUTES;
        var deltaMinutes = nextBoundaryMinutes - elapsedMinutes;

        return restWindow["endMs"] + (deltaMinutes * 60 * 1000);
    }

    function estimateSleepQuality(
        hrSummary as Dictionary or Null,
        stressSummary as Dictionary or Null,
        bbSummary as Dictionary,
        restWindow as Dictionary or Null
    ) as Number {
        var bbRecovery = bbSummary["last"] - bbSummary["first"];
        var bbScore = clamp((bbRecovery + 20) * 2, 0, 100);

        var stressScore = 50;
        if (stressSummary != null) {
            stressScore = clamp(100 - stressSummary["avg"], 0, 100);
        }

        var hrScore = 50;
        if (hrSummary != null) {
            hrScore = clamp(100 - hrSummary["avg"], 0, 100);
        }

        var durationScore = 50;
        if (restWindow != null) {
            durationScore = clamp((restWindow["durationMinutes"] / 480.0) * 100, 0, 100);
        }

        var score = (bbScore * 0.40) + (stressScore * 0.25) + (hrScore * 0.15) + (durationScore * 0.20);
        return clamp(score, 0, 100);
    }

    function clamp(value as Numeric, low as Numeric, high as Numeric) as Numeric {
        if (value < low) {
            return low;
        }
        if (value > high) {
            return high;
        }
        return value;
    }
    function isLikelySleeping(
        hrSummary as Dictionary or Null,
        stressSummary as Dictionary or Null,
        bbSummary as Dictionary
    ) as Boolean {

        if (stressSummary == null || hrSummary == null) {
            return false;
        }

        var stressAvg = stressSummary["avg"];
        var hrAvg = hrSummary["avg"];
        var bbRecovery = bbSummary["last"] - bbSummary["first"];

        if (stressAvg <= 25 && hrAvg <= 80 && bbRecovery >= -20) {
            return true;
        }

        return false;
    }
}