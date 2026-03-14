/*
Name: source/Ratings/RatingView.mc
Description: View for the song rating screen. Prompts the user to rate the
             song that just played using a 1–5 star scale. Stars are drawn
             programmatically so each can be tinted yellow (filled) or gray
             (empty) based on the current selection. The title and hint labels
             are positioned via the RatingsLayout XML resource.
Authors: Kiara Rose
Created: March 14, 2026
Last Modified: March 14, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class RatingView extends WatchUi.View {

    // Star tint colours
    private const STAR_YELLOW = 0xFFCC00;
    private const STAR_GRAY   = 0x555555;

    // Data for the submission
    private var _userId as Object;
    private var _song   as Object;
    private var _rating as Number;   // 0 = none selected; 1–5 = selected

    // Star bitmap resource
    private var _starBitmap;

    // Pre-computed star layout (set in _computeStarLayout, used in draw & hit-test)
    private var _starW      as Number;
    private var _starH      as Number;
    private var _starGap    as Number;
    private var _starStartX as Number;
    private var _starY      as Number;

    // ── Lifecycle ──────────────────────────────────────────────────

    function initialize(song as Object) {
        View.initialize();
        _userId = Storage.getValue("userId");
        if (_userId == null) {
            _userId = "unknown";
        }
        _song   = song;
        _rating = 0;

        _starBitmap = loadResource(Rez.Drawables.starIcon);

        // Cache star geometry so the delegate can use it before the first draw
        _starW = 0; _starH = 0; _starGap = 0; _starStartX = 0; _starY = 0;
        _computeStarLayout();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.RatingsLayout(dc));
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        // Black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Render the layout-defined text labels
        findDrawableById("ratingTitle").draw(dc);
        findDrawableById("ratingHint").draw(dc);

        // Draw the five stars with tint reflecting the current rating
        _drawStars(dc);
    }

    function onHide() as Void {}

    // ── Rating accessors (called by RatingDelegate) ────────────────

    function setRating(r as Number) as Void {
        if (r >= 1 && r <= 5) {
            _rating = r;
        }
    }

    function getRating() as Number {
        return _rating;
    }

    function incrementRating() as Void {
        if (_rating < 5) {
            _rating = _rating + 1;
        }
    }

    function decrementRating() as Void {
        if (_rating > 0) {
            _rating = _rating - 1;
        }
    }

    function getUserId() as Object { return _userId; }
    function getSong()   as Object { return _song;   }

    // Returns [x, y, w, h] of the i-th star (0-indexed) for hit testing.
    function getStarBounds(i as Number) as Array {
        return [
            _starStartX + i * (_starW + _starGap),
            _starY,
            _starW,
            _starH
        ] as Array;
    }

    // ── Private helpers ────────────────────────────────────────────

    // Computes and caches star layout geometry from the current screen size.
    private function _computeStarLayout() as Void {
        var W = System.getDeviceSettings().screenWidth;
        var H = System.getDeviceSettings().screenHeight;

        _starW   = _starBitmap.getWidth();
        _starH   = _starBitmap.getHeight();
        _starGap = (_starW / 3).toNumber();

        var totalW = 5 * _starW + 4 * _starGap;
        _starStartX = ((W - totalW) / 2).toNumber();
        _starY      = ((H * 0.45).toNumber() - _starH / 2).toNumber();

        System.println("RatingView._computeStarLayout: W=" + W + " H=" + H +
            " starW=" + _starW + " starH=" + _starH +
            " startX=" + _starStartX + " starY=" + _starY);
    }    // Draws the five stars, tinting each yellow (filled) or gray (empty).
    private function _drawStars(dc as Dc) as Void {
        for (var i = 0; i < 5; i++) {
            var x    = _starStartX + i * (_starW + _starGap);
            var tint = (i < _rating) ? STAR_YELLOW : STAR_GRAY;
            dc.drawBitmap2(x, _starY, _starBitmap, {:tintColor => tint});
        }
    }

}
