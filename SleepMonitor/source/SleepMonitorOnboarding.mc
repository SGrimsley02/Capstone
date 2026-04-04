/*
Name: source/SleepMonitorOnboarding.mc
Description: One-time onboarding helper. On first run, prompts the user to open a web page
             on their phone (via a Garmin Connect Mobile notification).
Authors: Audrey Pan
Created: February 14, 2026
Last Modified: February 14, 2026
*/

import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.System;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.Math;
import StorageKeys;
import Defaults;

class SleepMonitorOnboarding {

    var _sessionId as String = "";
    var _timer = getApp().userInfoTimer; // Use the main app timer for onboarding polling tasks
    var _pollCount as Number = 0;
    var _wakeStart as String? = null;
    var _wakeEnd as String? = null;
    const MAX_POLLS = 15;  // stop after 5 minutes (15 x 20s)

    function runIfFirstTime(targetUrl as String) as Boolean {

        var key = StorageKeys.HAS_ONBOARDED_KEY;

        System.println("Onboarding check started...");

        var hasOnboarded = Storage.getValue(key);
        System.println("Stored value: " + hasOnboarded);

        if (hasOnboarded == true) {
            System.println("User already onboarded. Skipping.");
            return false;
        }

        Storage.setValue(StorageKeys.WAKE_START_KEY, null);
        Storage.setValue(StorageKeys.WAKE_END_KEY, null);

        // Generate a unique session ID
        _sessionId = Lang.format("$1$-$2$", [System.getTimer(), Math.rand()]);

        // Open login page with session ID
        try {
            System.println("Attempting openWebPage...");
            Communications.openWebPage(targetUrl, {"sessionId" => _sessionId}, null);
            System.println("openWebPage call completed.");
        } catch (ex) {
            System.println("openWebPage FAILED: " + ex.toString());
        }

        // Start polling every 20 seconds
        _timer.start(method(:pollForUsername), 20000, true);

        return true;
    }

    function pollForUsername() as Void {
        _pollCount++;

        if (_pollCount > MAX_POLLS) {
            System.println("Polling timed out.");
            _timer.stop();
            // TODO: Display error message with instructions to retry onboarding + warning that they should login within 5 mins next time
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, false);
            System.println("Onboarding failed: user did not log in within time limit.");
            return;
        }
        Communications.makeWebRequest(
            "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/session/poll",
            { "sessionId" => _sessionId },
            {
                :method       => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onPollResponse)
        );
    }

    function onPollResponse(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode == 200 && data != null) {
            // Got the result — stop polling
            _timer.stop();

            var preferences = data["preferences"] as Dictionary?;
            Storage.setValue(StorageKeys.USER_ID_KEY, data["username"]);
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, true);

            if (preferences != null && preferences.size() > 0) {
                _wakeStart = preferences["wakeStart"] as String?;
                if (_wakeStart != null) {
                    Storage.setValue(StorageKeys.WAKE_START_KEY, _wakeStart);
                    System.println("Wake start time: " + _wakeStart);
                }
                _wakeEnd = preferences["wakeEnd"] as String?;
                if (_wakeEnd != null) {
                    Storage.setValue(StorageKeys.WAKE_END_KEY, _wakeEnd);
                    System.println("Wake end time: " + _wakeEnd);
                }
            } 

            getApp().getWakeAlarmManager().scheduleAlarmFromWakeWindow(_wakeStart, _wakeEnd);

            System.println("Onboarding complete for: " + data["username"]);

            _timer.start(method(:pollForPreferences), Defaults.SHORT_PREF_INT, false); // repull for preferences after 5 minutes
        } else if (responseCode == 404) {
            // Not ready yet — keep polling
            System.println("Waiting for user to log in... (" + _pollCount + ")");

        } else {
            // Something went wrong — stop polling
            _timer.stop();
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, false);
            System.println("Username poll failed: " + responseCode);
        }
    }

    function pollForPreferences() as Void {
        getApp().getWakeAlarmManager().pollPreferences();
        _timer.stop();
        var callback = new Method(getApp().getWakeAlarmManager(), :pollPreferences);
        _timer.start(callback, Defaults.LONG_PREF_INT, true); // regular preference polling every 2 hours after initial 5-minute check
    }
}
