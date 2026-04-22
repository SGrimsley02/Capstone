/*
Name: source/Playback/PlaybackView.mc
Description: Music playback control screen. Displays five tappable icon buttons:
             rewind (previous track), play/pause (toggle), skip (next track),
             volume (opens VolumeView), and star (opens the rating flow). Also
             shows the current song name and artist fetched via the "status" action.
             All layout is drawn programmatically in onUpdate.

             Status is refreshed automatically in three situations:
               1. onShow — immediate fetch on screen entry
               2. Periodic poll — every 10 s while the screen is visible, to
                  detect when a song finishes and a new one starts
               3. refreshStatus() — called by PlaybackDelegate after a skip or
                  rewind; uses a shared one-shot timer task so Spotify has time
                  to advance before we query.
Authors: Kiara Rose
Created: March 15, 2026
Last Modified: April 22, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class PlaybackView extends WatchUi.View {

    private const POLL_TASK_ID = "playback_poll";
    private const REFRESH_TASK_ID = "playback_refresh";

    private var _rewindIcon;
    private var _playIcon;
    private var _skipIcon;
    private var _volumeIcon;
    private var _starIcon;

    private var _songUri as Object?;
    private var _songName as Object?;
    private var _artistName as Object?;
    private var _isPlaying as Boolean;

    private var _rewindBounds as Array;
    private var _playBounds as Array;
    private var _skipBounds as Array;
    private var _volumeBounds as Array;
    private var _starBounds as Array;

    private var _provider as PlaybackProvider;

    function initialize() {
        View.initialize();

        _isPlaying = true;
        _songUri = null;
        _songName = null;
        _artistName = null;

        _rewindIcon = loadResource(Rez.Drawables.rewindIcon);
        _playIcon = loadResource(Rez.Drawables.playIcon);
        _skipIcon = loadResource(Rez.Drawables.skipIcon);
        _volumeIcon = loadResource(Rez.Drawables.volumeIcon);
        _starIcon = loadResource(Rez.Drawables.starIcon);

        _provider = new PlaybackProvider();

        var zero = [0, 0, 0, 0] as Array;
        _rewindBounds = zero;
        _playBounds = zero;
        _skipBounds = zero;
        _volumeBounds = zero;
        _starBounds = zero;
    }

    function onLayout(dc as Dc) as Void { setLayout(Rez.Layouts.PlaybackLayout(dc)); }

    function onShow() as Void {
        _requestStatus();

        getApp().getSharedTimerManager().registerRepeatingTask(
            POLL_TASK_ID,
            10,
            method(:_onPollTick)
        );

        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        _stopTimers();
    }

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;

        var bgColor = ThemeHelpers.getColor("bg");
        dc.setColor(bgColor, bgColor);
        dc.clear();

        dc.setColor(ThemeHelpers.getColor("playback_controls"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.12).toNumber(), Graphics.FONT_TINY, WatchUi.loadResource(Rez.Strings.NowPlaying),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_songName != null) {
            dc.setColor(ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (H * 0.27).toNumber(), Graphics.FONT_XTINY, _songName.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (_artistName != null) {
            dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (H * 0.37).toNumber(), Graphics.FONT_XTINY, _artistName.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var ctrlY = (H * 0.57).toNumber();
        var spacing = (W * 0.28).toNumber();

        _drawIconCentered(dc, _rewindIcon, cx - spacing, ctrlY, ThemeHelpers.getColor("playback_controls"));
        _drawIconCentered(dc, _playIcon, cx, ctrlY, ThemeHelpers.getColor("playback_controls"));
        _drawIconCentered(dc, _skipIcon, cx + spacing, ctrlY, ThemeHelpers.getColor("playback_controls"));

        _rewindBounds = _iconBounds(_rewindIcon, cx - spacing, ctrlY);
        _playBounds = _iconBounds(_playIcon, cx, ctrlY);
        _skipBounds = _iconBounds(_skipIcon, cx + spacing, ctrlY);

        var secY = (H * 0.80).toNumber();
        var secSpacing = (W * 0.22).toNumber();

        _drawIconCentered(dc, _volumeIcon, cx - secSpacing, secY, ThemeHelpers.getColor("playback_volume"));
        _drawIconCentered(dc, _starIcon, cx + secSpacing, secY, ThemeHelpers.getColor("playback_star"));

        _volumeBounds = _iconBounds(_volumeIcon, cx - secSpacing, secY);
        _starBounds = _iconBounds(_starIcon, cx + secSpacing, secY);
    }

    function getRewindBounds() as Array { return _rewindBounds; }
    function getPlayBounds() as Array { return _playBounds; }
    function getSkipBounds() as Array { return _skipBounds; }
    function getVolumeBounds() as Array { return _volumeBounds; }
    function getStarBounds() as Array { return _starBounds; }

    function isPlaying() as Boolean { return _isPlaying; }
    function togglePlayState() as Void { _isPlaying = !_isPlaying; }

    function getSongUri() as String? { return _songUri; }
    function getProvider() as PlaybackProvider { return _provider; }

    function refreshStatus() as Void {
        getApp().getSharedTimerManager().registerOneShotTask(
            REFRESH_TASK_ID,
            2,
            method(:_onRefreshTick)
        );
    }

    function _onPollTick() as Void {
        System.println("PlaybackView._onPollTick: polling status");
        _requestStatus();
    }

    function _onRefreshTick() as Void {
        System.println("PlaybackView._onRefreshTick: fetching status after skip/rewind");
        _requestStatus();
    }

    function _onStatusReceived(data as Lang.Dictionary) as Void {
        if (data != null) {
            _songUri = data["track_uri"] as String?;
            _songName = data["track_name"] as String?;
            _artistName = data["artist_name"] as String?;
            var playing = data["is_playing"];
            if (playing != null) {
                _isPlaying = playing as Boolean;
            }
        }
        WatchUi.requestUpdate();
    }

    private function _requestStatus() as Void {
        _provider.sendPlaybackCommand("status", null, method(:_onStatusReceived));
    }

    private function _stopTimers() as Void {
        getApp().getSharedTimerManager().unregisterTask(POLL_TASK_ID);
        getApp().getSharedTimerManager().unregisterTask(REFRESH_TASK_ID);
    }

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