/*
Name: source/Playback/VolumeDelegate.mc
Description: Input delegate for the volume control screen.
             Handles taps on the upArrow / downArrow icons and physical UP/DOWN
             button presses — each adjusting the volume by 10% and immediately
             sending a "volume" action via PlaybackService. ESC pops the view.
Authors: Kiara Rose, Ella Nguyen
Created: March 15, 2026
Last Modified: April 19, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class VolumeDelegate extends WatchUi.InputDelegate {

    private const STEP = 10; // Volume change per tap/button press

    private var _view as VolumeView;

    function initialize(view as VolumeView) {
        InputDelegate.initialize();
        _view = view;
    }

    // ── Touch input ────────────────────────────────────────────────

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        System.println("VolumeDelegate.onTap: x=" + tapX + " y=" + tapY);

        if (_hitTest(tapX, tapY, _view.getUpBounds())) {
            _changeVolume(STEP);
            return true;
        }

        if (_hitTest(tapX, tapY, _view.getDownBounds())) {
            _changeVolume(-STEP);
            return true;
        }

        return false;
    }

    // ── Physical buttons ───────────────────────────────────────────

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP) {
            _changeVolume(STEP);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _changeVolume(-STEP);
            return true;
        }
        return false;
    }

    // ── Private helpers ────────────────────────────────────────────

    private function _changeVolume(delta as Number) as Void {
        _view.setVolume(_view.getVolume() + delta);
        _view.getProvider().sendPlaybackCommand("volume", _view.getVolume(), null, null);
        WatchUi.requestUpdate();
    }

    // Returns true when (tapX, tapY) falls within bounds [x, y, w, h] + PAD.
    private function _hitTest(tapX as Number, tapY as Number, bounds as Array) as Boolean {
        var bx  = bounds[0] as Number;
        var by  = bounds[1] as Number;
        var bw  = bounds[2] as Number;
        var bh  = bounds[3] as Number;
        var PAD = 18;
        return tapX >= bx - PAD && tapX <= bx + bw + PAD &&
               tapY >= by - PAD && tapY <= by + bh + PAD;
    }

}
