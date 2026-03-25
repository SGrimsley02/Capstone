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

class SleepMonitorOnboarding {

    var _sessionId as String = "";
    var _timer as Timer.Timer?;
    var _pollCount as Number = 0;
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

        // Start polling every 5 seconds
        _timer = new Timer.Timer();
        _timer.start(method(:pollForResult), 20000, true);

        return true;
    }

    function pollForResult() as Void {
        _pollCount++;

        if (_pollCount > MAX_POLLS) {
            System.println("Polling timed out.");
            _timer.stop();
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

            var preferences = data["preferences"];
            SleepMonitorHttpClient.setUserId(data["username"]);
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, true);

            if (preferences != null) {
                Storage.setValue(StorageKeys.WAKE_START_KEY, preferences["wakeStart"]);
                Storage.setValue(StorageKeys.WAKE_END_KEY,   preferences["wakeEnd"]);
            }

            System.println("Onboarding complete for: " + data["username"]);

        } else if (responseCode == 404) {
            // Not ready yet — keep polling
            System.println("Waiting for user to log in... (" + _pollCount + ")");

        } else {
            // Something went wrong — stop polling
            _timer.stop();
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, false);
            System.println("Poll failed: " + responseCode);
        }
    }
}
