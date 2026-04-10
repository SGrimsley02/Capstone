/*
Name: source/SleepMonitorMenuDelegate.mc
Description: Menu input delegate for the SleepMonitor Connect IQ watch app.
             Handles menu selections and triggers the corresponding network test calls
             through SleepMonitorHttpClient.
Authors: Kiara Rose, Audrey Pan
Created: February 7, 2026
Last Modified: April 3, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Communications;

class SleepMonitorMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        // Initialize the menu delegate and construct the HTTP client for handling requests.
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        System.println("Selected user menu item: " + item.toString());

        if (item == :relinkWebsite) {
            System.println("Starting relink flow.");
            // getApp().getOnboardingManager().runRelink("http://localhost:5000");

        } else if (item == :uiCustomization) {
            System.println("UI customization selected.");
            WatchUi.pushView(new Rez.Menus.UiCustomizationMenu(), new ThemeMenuDelegate(), WatchUi.SLIDE_UP);
        } else if (item == :scheduleAlarm) {
            System.println("Scheduling alarm for 5 seconds from now.");
            getApp().getWakeAlarmManager().scheduleAlarmInSeconds(5);
        } 
    }

}
