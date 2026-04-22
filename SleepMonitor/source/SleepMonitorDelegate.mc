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
Last Modified: April 22, 2026
*/

import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import StorageKeys;

// Hold threshold for back-button exit (seconds)
// Using 1 second because SharedTimerManager runs on 1-second granularity.
const HOLD_SEC = 1;
const ESC_HOLD_TASK_ID = "sleep_monitor_esc_hold";

class SleepMonitorDelegate extends WatchUi.BehaviorDelegate {

    private var _escHoldFired   as Boolean = false;
    private var _escPressedHere as Boolean = false;

    function initialize() {
        BehaviorDelegate.initialize();
        _escHoldFired    = false;
        _escPressedHere  = false;
    }

    function openUserMenu() as Void {
        var view = new MenuUserView();
        var delegate = new MenuUserDelegate(view);
        WatchUi.pushView(view, delegate, WatchUi.SLIDE_UP);
    }

    (:debug)
    function openDebugMenu() as Void {
        WatchUi.pushView(new Rez.Menus.DebugMenu(), new DebugMenuDelegate(), WatchUi.SLIDE_UP);
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

        var dxL = tapX - leftX;
        var dyL = tapY - btnY;
        if (dxL * dxL + dyL * dyL <= btnR * btnR) {
            System.println("SleepMonitorDelegate: podcast button tapped");
            try {
                var podcast_url = Storage.getValue(StorageKeys.PODCAST_URL_KEY);
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
        return true;
    }

    function onMenu() as Boolean {
        System.println("SleepMonitorDelegate: opening user menu");
        openUserMenu();
        return true;
    }

    // call this function if you need the dev menu when testing (?) temporary solution
    (:debug)
    function openDeveloperToolsForTesting() as Void {
        WatchUi.pushView(new Rez.Menus.DebugMenu(), new DebugMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_ESC) {
            _escPressedHere = true;
            _escHoldFired = false;
            _cancelEscHoldTask();

            getApp().getSharedTimerManager().registerOneShotTask(
                ESC_HOLD_TASK_ID,
                HOLD_SEC,
                method(:_onEscHeld)
            );
            return true;

        } else if (key == WatchUi.KEY_DOWN) {
            System.println("SleepMonitorDelegate: opening podcast deeplink");
            try {
                var podcast_url = Storage.getValue(StorageKeys.PODCAST_URL_KEY);
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

    function onKeyReleased(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_ESC) {
            if (!_escPressedHere) {
                return false;
            }

            _escPressedHere = false;
            _cancelEscHoldTask();

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

    function _onEscHeld() as Void {
        if (!_escPressedHere) {
            return;
        }

        _escHoldFired = true;
        _cancelEscHoldTask();
        System.println("SleepMonitorDelegate: back held — exiting app");
        System.exit();
    }

    private function _cancelEscHoldTask() as Void {
        getApp().getSharedTimerManager().unregisterTask(ESC_HOLD_TASK_ID);
    }
}