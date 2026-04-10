/*
Name: source/DebugMenuDelegate.mc
Description: Menu input delegate for the SleepMonitor debug menu.
             Handles development and testing actions.
Authors: Audrey Pan
Created: April 3, 2026
Last Modified: April 3, 2026
*/

import Toybox.System;
import Toybox.WatchUi;
import Toybox.Lang;

class DebugMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _httpClient as SleepMonitorHttpClient;

    function initialize() {
        MenuInputDelegate.initialize();
        _httpClient = new SleepMonitorHttpClient();
    }

    function onMenuItem(item as Symbol) as Void {
        System.println("Selected debug menu item: " + item.toString());

        if (item == :httpLocal) {
            System.println("Running local HTTP test on http://127.0.0.1:5000/");
            _httpClient.sendLocalHttpRequest();

        } else if (item == :httpPublic) {
            System.println("Running public HTTPS test.");
            _httpClient.sendPublicHttpsRequest("https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/");

        } else if (item == :httpPost) {
            System.println("Sending sleep summary.");
            _httpClient.sendSleepSummaryRequest();

        } else if (item == :scheduleAlarm) {
            System.println("Scheduling alarm for 5 seconds from now.");
            getApp().getWakeAlarmManager().scheduleAlarmInSeconds(5);

        } else if (item == :testReview) {
            System.println("Navigating to the song rating screen.");
            var song = "fakeSongUri";
            var ratingView = new RatingView(song);
            var ratingDelegate = new RatingDelegate(ratingView);
            WatchUi.pushView(ratingView, ratingDelegate, WatchUi.SLIDE_UP);
        }
    }
}