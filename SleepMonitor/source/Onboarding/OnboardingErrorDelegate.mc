/*
Name: source/OnboardingErrorDelegate.mc
Description: Input delegate for the onboarding error screen.
Authors: Lauren D'Souza
Created: April 20, 2026
Last Modified: April 20, 2026
*/

using Toybox.WatchUi;
using Toybox.Graphics;

class OnboardingErrorDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // User presses SELECT — pop back to the previous menu
    function onSelect() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // User presses BACK — same behavior
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
