/*
Name: source/SleepMonitorDelegate.mc
Description: Input delegate for the SleepMonitor Connect IQ watch app.
             Handles user interactions that are not menu-based and coordinates
             input behavior with the active view.
             - Down (lower-left)       → opens the REMix morning podcast deeplink on the paired phone
             - Back short (lower-right) → opens music playback deeplink on the paired phone
             - Back hold  (lower-right) → exits the app
Authors: Kiara Rose
Created: February 7, 2026
Last Modified: March 13, 2026
*/

import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.Application.Storage;

// TODO: add podcast_url to storage in PodcastService.mc
// Hold threshold for back-button exit (milliseconds)
const HOLD_MS = 700;

class SleepMonitorDelegate extends WatchUi.BehaviorDelegate {

    private var _escHoldTimer  as Timer.Timer?;
    private var _escHoldFired  as Boolean = false;
    private var _escPressedHere as Boolean = false; // true only when THIS delegate handled the key-down

    function initialize() {
        BehaviorDelegate.initialize();
        _escHoldTimer   = null;
        _escHoldFired   = false;
        _escPressedHere = false;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new SleepMonitorMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }





    // Touch tap → check if the tap landed inside a button circle.
    // Button geometry mirrors SleepMonitorView.onUpdate exactly.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        var settings = System.getDeviceSettings();
        var W  = settings.screenWidth;
        var H  = settings.screenHeight;
        var cx = W / 2;

        var btnY   = (H * 0.74).toNumber();
        var leftX  = (cx - W * 0.36).toNumber();
        var rightX = (cx + W * 0.36).toNumber();
        var btnR   = (W * 0.19).toNumber();

        // Hit-test: point inside circle = dx²+dy² <= r²
        var dxL = tapX - leftX;
        var dyL = tapY - btnY;
        if (dxL * dxL + dyL * dyL <= btnR * btnR) {
            System.println("SleepMonitorDelegate: podcast button tapped");
            try {
                var podcast_url = Storage.getValue("podcast_url");
                if (podcast_url != null) {
                    Communications.openWebPage(podcast_url, null, null);
                }
            } catch (ex) {
                System.println("Podcast deeplink failed: " + ex.toString());
            }
            return true;
        }

        var dxR = tapX - rightX;
        var dyR = tapY - btnY;
        if (dxR * dxR + dyR * dyR <= btnR * btnR) {
            System.println("SleepMonitorDelegate: music button tapped");
            var pbView = new PlaybackView();
            WatchUi.pushView(pbView, new PlaybackDelegate(pbView), WatchUi.SLIDE_UP);
            return true;
        }

        return false;
    }

    function onBack() as Boolean {
        return true; // suppress, handled elsewhere (short vs. long press)
    }

    // ESC pressed → start hold timer; DOWN pressed → podcast immediately.
    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ESC) {
            _escPressedHere = true;
            _escHoldFired = false;
            _cancelEscTimer();
            _escHoldTimer = new Timer.Timer();
            _escHoldTimer.start(method(:_onEscHeld), HOLD_MS, false);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            System.println("SleepMonitorDelegate: opening podcast deeplink");
            try {
                var podcast_url = Storage.getValue("podcast_url");
                if (podcast_url != null) {
                    Communications.openWebPage(podcast_url, null, null);
                }
            } catch (ex) {
                System.println("Podcast deeplink failed: " + ex.toString());
            }
            return true;
        }
        return false;
    }

    // ESC released → if hold didn't fire yet, treat as short-press (music).
    // Guard with _escPressedHere so a release that arrives after returning from
    // a sub-view (e.g. back from the menu) doesn't spuriously trigger the deeplink.
    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {

        if (evt.getKey() == WatchUi.KEY_ESC) {
            if (!_escPressedHere) {
                // The press was handled by another delegate; ignore the orphaned release.
                return false;
            }
            _escPressedHere = false;
            _cancelEscTimer();
            if (!_escHoldFired) {
                System.println("SleepMonitorDelegate: opening music playback");
                var pbView = new PlaybackView();
                WatchUi.pushView(pbView, new PlaybackDelegate(pbView), WatchUi.SLIDE_UP);
            }
            _escHoldFired = false;
            return true;
        }
        return false;
    }

    // Fired by the hold timer — exit the app.
    function _onEscHeld() as Void {
        _escHoldFired = true;
        _cancelEscTimer();
        System.println("SleepMonitorDelegate: back held — exiting app");
        System.exit();
    }

    private function _cancelEscTimer() as Void {
        if (_escHoldTimer != null) {
            _escHoldTimer.stop();
            _escHoldTimer = null;
        }
    }

}