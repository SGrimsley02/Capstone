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

class QueueDelegate extends WatchUi.BehaviorDelegate {

    private var _view as QueueView;
    private var _playbackView as PlaybackView;
    private var _isStartingTrack as Boolean;

    function initialize(view as QueueView, playbackView as PlaybackView) {
        WatchUi.BehaviorDelegate.initialize();
        _view = view;
        _playbackView = playbackView;
        _isStartingTrack = false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
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
        } else if (key == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }

        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tx = coords[0];
        var ty = coords[1];

        var tappedIndex = _view.getVisibleIndexForTap(tx, ty);

        if (tappedIndex == -1) {
            return false;
        }

        if (tappedIndex == _view.getSelectedIndex()) {
            _playSelectedTrack();
        } else {
            _view.setSelectedIndex(tappedIndex);
        }

        return true;
    }

    private function _playSelectedTrack() as Void {
        if (_isStartingTrack) {
            System.println("QueueDelegate._playSelectedTrack: blocked, already starting track");
            return;
        }

        _isStartingTrack = true;

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
            var queueUris = "";

            for (var i = selectedIndex; i < queue.size(); i += 1) {
                var qItem = queue[i] as Lang.Dictionary;
                var uri = qItem["track_uri"];

                if (uri != null) {
                    if (queueUris.length() > 0) {
                        queueUris += ",";
                    }
                    queueUris += uri.toString();
                }
            }

            System.println("QueueDelegate._playSelectedTrack: " + trackUri);
            System.println("QueueDelegate queueUris: " + queueUris);

            _view.getProvider().playQueueFrom(
                trackUri.toString(),
                queueUris,
                method(:_onTrackStarted)
            );
        }
    }

    function _onTrackStarted(data as Lang.Dictionary) as Void {
        _isStartingTrack = false;

        System.println("QueueDelegate._onTrackStarted: " + data);

        if (data == null) {
            return;
        }

        var success = data["success"];

        if (success != null && (success as Boolean)) {
            _playbackView.refreshStatus();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }
}