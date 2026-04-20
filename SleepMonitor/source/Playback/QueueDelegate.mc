/*
Name: source/Playback/QueueDelegate.mc
Description: Input delegate for the queue screen. Lets the user move through
             queue items and start playback of the selected track.
Authors: Ella Nguyen
Created: April 19, 2026
Last Modified: April 19, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class QueueDelegate extends WatchUi.InputDelegate {

    private var _view as QueueView;

    function initialize(view as QueueView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_UP) {
            _view.setSelectedIndex(_view.getSelectedIndex() - 1);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.setSelectedIndex(_view.getSelectedIndex() + 1);
            return true;
        } else if (key == WatchUi.KEY_ENTER) {
            _playSelectedTrack();
            return true;
        }

        return false;
    }

    private function _playSelectedTrack() as Void {
        var queue = _view.getQueue();
        var selectedIndex = _view.getSelectedIndex();

        if (queue == null || queue.size() == 0) {
            return;
        }

        if (selectedIndex < 0 || selectedIndex >= queue.size()) {
            return;
        }

        var item = queue[selectedIndex] as Lang.Dictionary;
        var trackUri = item["track_uri"];

        if (trackUri != null) {
            System.println("QueueDelegate._playSelectedTrack: " + trackUri);
            _view.getProvider().sendPlaybackCommand(
                "play_uri",
                null,
                trackUri.toString(),
                method(:_onTrackStarted)
            );
        }
    }

    function _onTrackStarted(data as Lang.Dictionary) as Void {
        System.println("QueueDelegate._onTrackStarted: " + data);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}