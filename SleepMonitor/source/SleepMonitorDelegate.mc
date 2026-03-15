/*
Name: source/SleepMonitorDelegate.mc
Description: Input delegate for the SleepMonitor Connect IQ watch app.
             Handles user interactions that are not menu-based and coordinates
             input behavior with the active view.
Authors: Kiara Rose
Created: February 7, 2026
Last Modified: February 7, 2026
*/

import Toybox.Lang;
import Toybox.WatchUi;

class SleepMonitorDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new SleepMonitorMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}