/*
Name: source/SleepMonitorApp.mc
Description: Application entry point for the SleepMonitor Connect IQ watch app.
             Maintains shared in-memory UI/network status and provides the initial
             view + input delegate wiring.
Authors: Kiara Rose, Audrey Pan
Created: February 7, 2026
Last Modified: February 14, 2026
*/

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import Toybox.Communications;

(:background_exluded)
class SleepMonitorApp extends Application.AppBase {
    private var _httpStatus as String = "Idle";
    private var _wakeAlarmManager;
    private var _httpClient;


    function initialize() {
        AppBase.initialize();
        _wakeAlarmManager = new WakeAlarmManager();
        _httpClient = new SleepMonitorHttpClient();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        //DELETE THIS LATER (ONLY FOR TESTING)
        // Storage.deleteValue("hasOnboarded");
        //System.println("Storage cleared for test.");

        // One-time onboarding: prompt user to open a web page on their phone.
        var onboarding = new SleepMonitorOnboarding();
        var didOnboard = onboarding.runIfFirstTime("http://127.0.0.1:5000/");

        if (didOnboard) {
            setHttpStatus("Open phone link to continue");
            var wakeStartTime = SleepMonitorHttpClient.getWakeStart();
            if (wakeStartTime == null) {
                wakeStartTime = "00:00";
            }
            var wakeStartEpoch = WakeAlarmManager.getNextDayEpoch(wakeStartTime);
            getWakeAlarmManager().scheduleAlarmAtEpoch(wakeStartEpoch);
            System.println("Wake alarm scheduled for epoch: " + wakeStartEpoch);
            WatchUi.requestUpdate();
        }
}

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new SleepMonitorView(), new SleepMonitorDelegate() ];
    }

    // Read current networking/UI status for display.
    function getHttpStatus() as String {
        return _httpStatus;
    }

    // Update status message (typically set by HTTP client after responses/errors).
    function setHttpStatus(message as String) as Void {
        _httpStatus = message;
    }
    function getWakeAlarmManager() {
        return _wakeAlarmManager;
    }
    function updateUserInfo() as Void {
        _httpClient.getUserInfo();
    }
}

// Convenience helper to access the App instance from other modules.
function getApp() as SleepMonitorApp {
    return Application.getApp() as SleepMonitorApp;
}