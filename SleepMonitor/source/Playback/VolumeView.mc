/*
Name: source/Playback/VolumeView.mc
Description: Volume control sub-screen pushed from the playback view when the
             volume icon is tapped. Shows a vertical volume bar (filled from the
             bottom up in proportion to the current level), an upArrow icon at the
             top to increase volume, and a downArrow icon at the bottom to decrease
             it. Each tap on an arrow sends a "volume" action via PlaybackService.
             All layout is drawn programmatically in onUpdate.
Authors: Kiara Rose
Created: March 15, 2026
Last Modified: March 15, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class VolumeView extends WatchUi.View {

    // State
    private var _volume as Number;
    private var _provider as PlaybackProvider;

    // Arrow icons
    private var _upArrow;
    private var _downArrow;

    // Arrow hit-test bounds [x, y, w, h] — updated every draw
    private var _upBounds as Array;
    private var _downBounds as Array;

    // ── Lifecycle ──────────────────────────────────────────────────

    function initialize(provider as PlaybackProvider) {
        View.initialize();
        _provider = provider;
        _volume = 50; // Default; updated from status if available
        _upArrow = loadResource(Rez.Drawables.upArrow);
        _downArrow = loadResource(Rez.Drawables.downArrow);
        _upBounds = [0, 0, 0, 0] as Array;
        _downBounds = [0, 0, 0, 0] as Array;
    }

    function onLayout(dc as Dc) as Void { setLayout(Rez.Layouts.VolumeLayout(dc)); }

    function onShow() as Void { WatchUi.requestUpdate(); }

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;

        // Background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // "Volume" title
        dc.setColor(Colors.TEAL_LITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.10).toNumber(), Graphics.FONT_TINY, "Volume",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Up arrow (tap to increase)
        var arrowUpY = (H * 0.22).toNumber();
        _drawIconCentered(dc, _upArrow, cx, arrowUpY, Colors.TEAL_LITE);
        _upBounds = _iconBounds(_upArrow, cx, arrowUpY);

        // ── Vertical volume bar ─────────────────────────────────────
        var barW = 24;
        var barX = cx - barW / 2;
        var barTop = (H * 0.32).toNumber();
        var barBottom = (H * 0.72).toNumber();
        var barH = barBottom - barTop;

        // Background track (dark gray)
        dc.setColor(Colors.GRAY_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barTop, barW, barH, 6);

        // Filled portion grows from bottom upward
        var fillH = (barH * _volume / 100).toNumber();
        if (fillH > 6) {
            dc.setColor(Colors.TEAL_LITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, barBottom - fillH, barW, fillH, 6);
        } else if (fillH > 0) {
            dc.setColor(Colors.TEAL_LITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barBottom - fillH, barW, fillH);
        }

        // Volume percentage
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.77).toNumber(), Graphics.FONT_XTINY, _volume.format("%d") + "%",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Down arrow (tap to decrease)
        var arrowDnY = (H * 0.88).toNumber();
        _drawIconCentered(dc, _downArrow, cx, arrowDnY, Colors.TEAL_LITE);
        _downBounds = _iconBounds(_downArrow, cx, arrowDnY);
    }

    function onHide() as Void {}

    // ── Accessors (called by VolumeDelegate) ───────────────────────

    function getVolume() as Number { return _volume; }
    function getProvider() as PlaybackProvider { return _provider; }
    function getUpBounds() as Array { return _upBounds; }
    function getDownBounds() as Array { return _downBounds; }

    function setVolume(v as Number) as Void {
        if (v < 0) {
            v = 0;
        }
        if (v > 100) {
            v = 100;
        }
        _volume = v;
    }

    // ── Private helpers ────────────────────────────────────────────

    private function _drawIconCentered(dc as Dc, icon, cx as Number, cy as Number, tint as Number) as Void {
        if (icon == null) {
            return;
        }
        var iw = icon.getWidth();
        var ih = icon.getHeight();
        dc.drawBitmap2(cx - iw / 2, cy - ih / 2, icon, { :tintColor => tint });
    }

    private function _iconBounds(icon, cx as Number, cy as Number) as Array {
        if (icon == null) {
            return [cx - 16, cy - 16, 32, 32] as Array;
        }
        var iw = icon.getWidth();
        var ih = icon.getHeight();
        return [cx - iw / 2, cy - ih / 2, iw, ih] as Array;
    }
}
