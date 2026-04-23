/*
Name: source/Playback/PlaybackDelegate.mc
Description: Input delegate for the music playback control screen.
             Routes taps on each icon button to the appropriate PlaybackService
             action or sub-screen:
               - Rewind icon  → "previous" action
               - Play icon    → "pause" or "resume" action (toggles)
               - Skip icon    → "next" action
               - Volume icon  → pushes VolumeView / VolumeDelegate
               - Star icon    → fetches current track URI via "status", then
                                pushes RatingView / RatingDelegate
             Uses WatchUi.InputDelegate so that onTap receives raw coordinates.
Authors: Kiara Rose, Ella Nguyen
Created: March 15, 2026
Last Modified: April 22, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class PlaybackDelegate extends WatchUi.InputDelegate {

    private var _view as PlaybackView;

    function initialize(view as PlaybackView) {
        InputDelegate.initialize();
        _view = view;
    }

    // ── Touch input ────────────────────────────────────────────────

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        System.println("PlaybackDelegate.onTap: x=" + tapX + " y=" + tapY);

        if (_hitTest(tapX, tapY, _view.getRewindBounds())) {
            _view.getProvider().sendPlaybackCommand("previous", null, null, null);
            _view.refreshStatus();
            return true;
        }

        if (_hitTest(tapX, tapY, _view.getPlayBounds())) {
            var action = _view.isPlaying() ? "pause" : "resume";
            _view.getProvider().sendPlaybackCommand(action, null, null, null);
            _view.togglePlayState();
            WatchUi.requestUpdate();
            return true;
        }

        if (_hitTest(tapX, tapY, _view.getSkipBounds())) {
            _view.getProvider().sendPlaybackCommand("next", null, null, null);
            _view.refreshStatus();
            return true;
        }

        if (_hitTest(tapX, tapY, _view.getVolumeBounds())) {
            var volView = new VolumeView(_view.getProvider());
            WatchUi.pushView(volView, new VolumeDelegate(volView), WatchUi.SLIDE_UP);
            return true;
        }

        if (_hitTest(tapX, tapY, _view.getQueueBounds())) {
            if (!_view.canOpenQueue()) {
                System.println("PlaybackDelegate.onTap: queue blocked until playback is stable");
                return true;
            }

            _pushQueueView();
            return true;
        }

        if (_hitTest(tapX, tapY, _view.getStarBounds())) {
            _pushRatingView();
            return true;
        }

        return false;
    }

    // ── Queue flow helpers ────────────────────────────────────────
    // Navigate to queue view
    private function _pushQueueView() as Void {
        var queueView = new QueueView(_view.getProvider());
        WatchUi.pushView(queueView, new QueueDelegate(queueView), WatchUi.SLIDE_UP);
    }

    // ── Rating flow helpers ────────────────────────────────────────

    // If we already have the song URI from the last status fetch, navigate
    // straight to the rating screen; otherwise request status first.
    private function _pushRatingView() as Void {
        var songUri = _view.getSongUri();
        if (songUri == null) {
            _view.getProvider().sendPlaybackCommand("status", null, null, method(:_onStatusForRating));
        } else {
            _navigateToRating(songUri);
        }
    }

    function _onStatusForRating(data as Lang.Dictionary) as Void {
        var uri = null;
        if (data != null) {
            uri = data["track_uri"];
        }
        _navigateToRating(uri);
    }

    private function _navigateToRating(songUri as String) as Void {
        var ratingView = new RatingView(songUri);
        WatchUi.pushView(ratingView, new RatingDelegate(ratingView), WatchUi.SLIDE_UP);
    }

    // ── Private helpers ────────────────────────────────────────────

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
