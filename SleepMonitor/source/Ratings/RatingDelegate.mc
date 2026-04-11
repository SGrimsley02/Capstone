/*
Name: source/Ratings/RatingDelegate.mc
Description: Input delegate for the song rating screen.
             Handles all user interactions on the RatingView:
               - UP physical button        -> increment star rating (max 5)
               - DOWN physical button      -> decrement star rating (min 0/unset)
               - BACK (ESC) button         -> pop view without submitting a rating
               - START / activity button   -> submit the rating and pop the view
               - Tap on a star             -> set rating to that star's level
             Uses WatchUi.InputDelegate (not BehaviorDelegate) so that onTap
             receives raw coordinates instead of being swallowed by onSelect.
Authors: Kiara Rose
Created: March 14, 2026
Last Modified: March 14, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class RatingDelegate extends WatchUi.InputDelegate {

    private var _view as RatingView;

    function initialize(view as RatingView) {
        InputDelegate.initialize();
        _view = view;
    }

    // Tap -- set the rating to whichever star was tapped (1 = leftmost).
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var tapX   = coords[0];
        var tapY   = coords[1];

        System.println("RatingDelegate.onTap: tapX=" + tapX + " tapY=" + tapY);

        for (var i = 0; i < 5; i++) {
            var bounds = _view.getStarBounds(i);
            var bx = bounds[0] as Number;
            var by = bounds[1] as Number;
            var bw = bounds[2] as Number;
            var bh = bounds[3] as Number;

            // Generous hit area: 15 px padding on every side.
            var PAD = 15;
            if (tapX >= bx - PAD && tapX <= bx + bw + PAD &&
                tapY >= by - PAD && tapY <= by + bh + PAD) {
                _view.setRating(i + 1);
                WatchUi.requestUpdate();
                return true;
            }
        }
        return true; // consume all taps on this screen
    }

    // Physical button handling.
    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();

        if (key == WatchUi.KEY_ENTER) {
            // START -- submit if a star is selected, then exit.
            var rating = _view.getRating();
            if (rating > 0) {
                var request = new SongRatingService();
                request.submitRating(_view.getUserId(), _view.getSong(), rating, getSleepScore());
            }
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        } else if (key == WatchUi.KEY_UP) {
            _view.incrementRating();
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.decrementRating();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function getSleepScore() as Number? {
        var score = Storage.getValue(StorageKeys.SLEEP_SCORE_KEY);
        return score as Number?;
    }
}
