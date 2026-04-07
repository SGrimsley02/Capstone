/*
Name: source/SleepMonitorMenuDelegate.mc
Description: Menu input delegate for the SleepMonitor Connect IQ watch app.
             Handles menu selections and triggers the corresponding network test calls
             through SleepMonitorHttpClient.
Authors: Kiara Rose, Audrey Pan
Created: February 7, 2026
Last Modified: April 5, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Communications;

class SleepMonitorMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        System.println("Selected user menu item: " + item.toString());

        if (item == :relinkWebsite) {
            System.println("Starting relink flow.");
            getApp().startRelinkFlow();

        } else if (item == :changeTheme) {
            var themeView = new MenuChangeThemeView();
            WatchUi.pushView(themeView, new MenuChangeThemeBehaviorDelegate(themeView), WatchUi.SLIDE_UP);
        }
    }
}