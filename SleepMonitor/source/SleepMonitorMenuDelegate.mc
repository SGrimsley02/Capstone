/*
Name: source/SleepMonitorMenuDelegate.mc
Description: Menu input delegate for the SleepMonitor Connect IQ watch app.
             Handles menu selections and triggers the corresponding network test calls
             through SleepMonitorHttpClient.
Authors: Kiara Rose, Audrey Pan
Created: February 7, 2026
Last Modified: February 14, 2026

Notes:
- Menu item symbols (:item_1, :item_2, :item_3) are defined in resources/menus/menu.xml.
- Some menu actions are intended for local testing and will be removed once a
    backend endpoint and workflow are in place.
*/


import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

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
        if (item == :item_1) {
            System.println("Running local HTTP test on http://127.0.0.1:3000/");
            _httpClient.sendLocalHttpRequest();
        } else if (item == :item_2) {
            System.println("Running public HTTPS test.");
            _httpClient.sendPublicHttpsRequest();
        } else if (item == :item_3) {
            System.println("Running HTTPS POST test.");
            _httpClient.sendPostTestRequest();
        }
    }
}