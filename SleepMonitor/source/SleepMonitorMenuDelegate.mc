/*
Name: source/SleepMonitorMenuDelegate.mc
Description: Menu input delegate for the SleepMonitor Connect IQ watch app.
             Handles menu selections and triggers the corresponding network test calls
             through SleepMonitorHttpClient.
Authors: Kiara Rose, Audrey Pan
Created: February 7, 2026
Last Modified: February 14, 2026

Notes:
- Menu item symbols are defined in resources/menus/menu.xml.
*/


import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Communications;

class SleepMonitorMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _httpClient as SleepMonitorHttpClient;

    function initialize() {
        // Initialize the menu delegate and construct the HTTP client for handling requests.
        MenuInputDelegate.initialize();
        _httpClient = new SleepMonitorHttpClient();
    }

    function onMenuItem(item as Symbol) as Void {
        // Handle menu item selections and trigger the corresponding HTTP client methods.
        // (Item symbols map to menu.xml entries)
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
        } else if (item == :openWebsite) {
            System.println("Opening website.");
            try {
                System.println("Attempting openWebPage...");
                Communications.openWebPage("https://www.google.com", null, null); // TODO: replace with real URL, need to replace elsewhere too
                System.println("openWebPage call completed.");
            } catch (ex) {
                System.println("openWebPage FAILED: " + ex.toString());
            }
        }
    }
}
