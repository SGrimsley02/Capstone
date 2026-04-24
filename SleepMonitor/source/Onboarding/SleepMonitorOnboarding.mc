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
import Toybox.Math;
import Toybox.WatchUi;
import StorageKeys;
import Defaults;
import TimerConstants;

class SleepMonitorOnboarding {

    var _sessionId as String = "";
    var _pollCount as Number = 0;
    var _wakeStart as String? = null;
    var _wakeEnd as String? = null;
    var _usernamePollPending;
    var _prefPollPending;
    var _hasOnboarded;

    function runIfFirstTime(targetUrl as String) as Boolean {

        _usernamePollPending = false;
        _prefPollPending = false;

        System.println("Onboarding check started...");

        _hasOnboarded = Storage.getValue(StorageKeys.HAS_ONBOARDED_KEY);
        System.println("Stored value: " + _hasOnboarded);

        if (_hasOnboarded == true) {
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

        _usernamePollPending = true;

        // Start polling every 20 seconds
        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.ONBOARDING_USERNAME_POLL_TASK_ID,
            TimerConstants.ONBOARDING_USERNAME_POLL_INTERVAL_SEC,
            method(:pollForUsername)
        );

        return true;
    }

    function pollForUsername() as Void {
        _pollCount++;

        if (_usernamePollPending == false) {
            return;
        }
        if (_pollCount > TimerConstants.ONBOARDING_USERNAME_MAX_POLLS) {
            if (_hasOnboarded && Storage.getValue(StorageKeys.USER_ID_KEY)) {
                System.println("User has onboarded but poll timed out. Stopping polling.");
                _stopPollingUsername();
                return;
            }

            System.println("Polling timed out.");
            _stopPollingUsername();
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, false);
            _hasOnboarded = false;
            System.println("Onboarding failed: user did not log in within time limit.");
            WatchUi.pushView(new OnboardingErrorView(), new OnboardingErrorDelegate(), WatchUi.SLIDE_UP);
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
            _stopPollingUsername();

            var oldUsername = Storage.getValue(StorageKeys.USER_ID_KEY) as String?;
            var newUsername = data["username"] as String?;
            var preferences = data["preferences"] as Dictionary?;

            if (newUsername == null) {
                Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, false);
                _hasOnboarded = false;
                System.println("Username poll returned success but no username was present.");
                return;
            }

            var isDifferentUser = (oldUsername == null) || !oldUsername.equals(newUsername);

            if (isDifferentUser) {
                if (oldUsername != null) {
                    System.println("Relink detected account switch from " + oldUsername + " to " + newUsername);
                } else {
                    System.println("First-time onboarding for " + newUsername);
                }

                // Clear stale user-specific wake data before applying the current user's prefs
                _wakeStart = null;
                _wakeEnd = null;
                Storage.setValue(StorageKeys.WAKE_START_KEY, null);
                Storage.setValue(StorageKeys.WAKE_END_KEY, null);
            }

            Storage.setValue(StorageKeys.USER_ID_KEY, newUsername);
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, true);
            _hasOnboarded = true;


            if (preferences != null && preferences.size() > 0) {
                _wakeStart = preferences["wakeStart"] as String?;
                if (_wakeStart != null) {
                    Storage.setValue(StorageKeys.WAKE_START_KEY, _wakeStart);
                    System.println("Wake start time: " + _wakeStart);
                } else {
                    Storage.setValue(StorageKeys.WAKE_START_KEY, null);
                }

                _wakeEnd = preferences["wakeEnd"] as String?;
                if (_wakeEnd != null) {
                    Storage.setValue(StorageKeys.WAKE_END_KEY, _wakeEnd);
                    System.println("Wake end time: " + _wakeEnd);
                } else {
                    Storage.setValue(StorageKeys.WAKE_END_KEY, null);
                }
            } else {
                Storage.setValue(StorageKeys.WAKE_START_KEY, null);
                Storage.setValue(StorageKeys.WAKE_END_KEY, null);
                System.println("No preferences returned from poll response.");
            }

            getApp().getWakeAlarmManager().scheduleAlarmFromWakeWindow(_wakeStart, _wakeEnd);

            System.println("Onboarding complete for: " + newUsername);

            _prefPollPending = true;
            getApp().getSharedTimerManager().registerOneShotTask(
                TimerConstants.ONBOARDING_INITIAL_PREF_POLL_ID,
                TimerConstants.ONBOARDING_INITIAL_PREF_POLL_INTERVAL,
                method(:pollOnceForPreferences)
            );
        } else if (responseCode == 404) {
            // Not ready yet — keep polling
            System.println("Waiting for user to log in... (" + _pollCount + ")");
        } else {
            // Something went wrong — stop polling
            _stopPollingUsername();
            Storage.setValue(StorageKeys.HAS_ONBOARDED_KEY, false);
            _hasOnboarded = false;
            System.println("Username poll failed: " + responseCode);
        }
    }

    function pollOnceForPreferences() as Void {
        if (_prefPollPending == false) {
            return;
        }
        getApp().getWakeAlarmManager().pollPreferences();
        
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.ONBOARDING_INITIAL_PREF_POLL_ID);
        _prefPollPending = false;

        var callback = new Method(getApp().getWakeAlarmManager(), :pollPreferences);
        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.ONBOARDING_LONG_PREF_POLL_ID,
            TimerConstants.ONBOARDING_LONG_PREF_POLL_INTERVAL,
            callback
        ); // regular preference polling every 2 hours after initial 5-minute check
    }
    
    function runRelink(targetUrl as String) as Void {
        System.println("Relink flow started.");
        _usernamePollPending = false;
        _prefPollPending = false;
        _sessionId = Lang.format("$1$-$2$", [System.getTimer(), Math.rand()]);

        try {
            System.println("Attempting openWebPage for relink...");
            Communications.openWebPage(targetUrl, {"sessionId" => _sessionId}, null);
            System.println("Relink openWebPage call completed.");
        } catch (ex) {
            System.println("Relink openWebPage FAILED: " + ex.toString());
            return;
        }

        _stopPollingUsername();
        _usernamePollPending = true;
        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.ONBOARDING_USERNAME_POLL_TASK_ID,
            TimerConstants.ONBOARDING_USERNAME_POLL_INTERVAL_SEC,
            method(:pollForUsername)
        );
    }

    function _stopPollingUsername() as Void {
        _usernamePollPending = false;
        _pollCount = 0;
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.ONBOARDING_USERNAME_POLL_TASK_ID);
        return;
    }
}
