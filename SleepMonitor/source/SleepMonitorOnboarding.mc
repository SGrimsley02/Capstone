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

class SleepMonitorOnboarding {

    static function runIfFirstTime(targetUrl as String) as Boolean {

        var key = "hasOnboarded";

        System.println("Onboarding check started...");

        var hasOnboarded = Storage.getValue(key);
        System.println("Stored value: " + hasOnboarded);

        if (hasOnboarded == true) {
            System.println("User already onboarded. Skipping.");
            return false;
        }

        System.println("First-time user detected. Setting flag.");
        Storage.setValue(key, true);

        try {
            System.println("Attempting openWebPage...");
            Communications.openWebPage(targetUrl, null, null);
            System.println("openWebPage call completed.");
        } catch (ex) {
            System.println("openWebPage FAILED: " + ex.toString());
        }

        return true;
    }
}
