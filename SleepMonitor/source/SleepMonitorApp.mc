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
import Toybox.Timer;

(:background_exluded)
class SleepMonitorApp extends Application.AppBase {
    private var _httpStatus as String = "Idle";
    private var _wakeAlarmManager;
    private var _httpClient;
    private var _onboardingManager as SleepMonitorOnboarding;
    var userInfoTimer as Timer.Timer;

    function initialize() {
        AppBase.initialize();
        _wakeAlarmManager = new WakeAlarmManager();
        _httpClient = new SleepMonitorHttpClient();
        userInfoTimer = new Timer.Timer();
        _onboardingManager = new SleepMonitorOnboarding();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {

        // One-time onboarding: prompt user to open a web page on their phone.
        var onboarding = new SleepMonitorOnboarding();
        var didOnboard = onboarding.runIfFirstTime("https://www.remixdisco.com");

        if (didOnboard) {
            setHttpStatus("Open phone link to continue");
            WatchUi.requestUpdate();
        }
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {}

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new SleepMonitorView(), new SleepMonitorDelegate()];
    }

    // Read current networking/UI status for display.
    function getHttpStatus() as String { return _httpStatus; }

    // Update status message (typically set by HTTP client after responses/errors).
    function setHttpStatus(message as String) as Void {
        _httpStatus = message;
    }

    function getWakeAlarmManager() {
        return _wakeAlarmManager;
    }

    function updateUserInfo(onReceive as Method) as Void {
        _httpClient.getUserInfo(onReceive);
    }

    function sendSleepSummary() as Void {
        _httpClient.sendSleepSummaryRequest();
    }

    function startRelinkFlow() as Void {
        _onboardingManager.runRelink("https://www.remixdisco.com");
        setHttpStatus("Open phone link to relink");
        WatchUi.requestUpdate();
    }

    function getOnboardingManager() as SleepMonitorOnboarding {
        return _onboardingManager;
    }
}

// Convenience helper to access the App instance from other modules.
function getApp() as SleepMonitorApp { return Application.getApp() as SleepMonitorApp; }