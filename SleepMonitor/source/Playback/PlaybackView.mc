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
                  rewind; uses a 1.5 s one-shot timer so Spotify has time to
                  advance before we query.
Authors: Kiara Rose, Ella Nguyen
Created: March 15, 2026
Last Modified: April 22, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class PlaybackView extends WatchUi.View {

    // Playback icons
    private var _rewindIcon;
    private var _playIcon;
    private var _skipIcon;
    private var _volumeIcon;
    private var _queueIcon;
    private var _starIcon;

    // Current track info (populated by status response)
    private var _songUri as Object?;
    private var _songName as Object?;
    private var _artistName as Object?;
    private var _isPlaying as Boolean;
    private var _statusReady as Boolean;
    private var _queueReadyAtMs as Number;

    // Icon hit-test bounds [x, y, w, h] — updated every draw
    private var _rewindBounds as Array;
    private var _playBounds as Array;
    private var _skipBounds as Array;
    private var _volumeBounds as Array;
    private var _queueBounds as Array;
    private var _starBounds as Array;

    private var _provider as PlaybackProvider;

    // Shared timer state
    private var _refreshPending as Boolean;
    private var _isActive as Boolean;

    // ── Lifecycle ──────────────────────────────────────────────────

    function initialize() {
        View.initialize();

        _isPlaying = true;
        _songUri = null;
        _songName = null;
        _artistName = null;
        _statusReady = false;
        _queueReadyAtMs = 0;

        _rewindIcon = loadResource(Rez.Drawables.rewindIcon);
        _playIcon = loadResource(Rez.Drawables.playIcon);
        _skipIcon = loadResource(Rez.Drawables.skipIcon);
        _volumeIcon = loadResource(Rez.Drawables.volumeIcon);
        _queueIcon = loadResource(Rez.Drawables.queueIcon);
        _starIcon = loadResource(Rez.Drawables.starIcon);

        _provider = new PlaybackProvider();

        _refreshPending = false;
        _isActive = false;

        var zero = [0, 0, 0, 0] as Array;
        _rewindBounds = zero;
        _playBounds = zero;
        _skipBounds = zero;
        _volumeBounds = zero;
        _queueBounds = zero;
        _starBounds = zero;
    }

    function onLayout(dc as Dc) as Void { setLayout(Rez.Layouts.PlaybackLayout(dc)); }

    function onShow() as Void {
        _isActive = true;
        _refreshPending = false;

        // Immediate status fetch on entry
        _markStatusPending(2500);
        _requestStatus();

        // Start repeating poll to detect when a song finishes
        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.PLAYBACK_POLL_TASK_ID,
            TimerConstants.PLAYBACK_POLL_INTERVAL_SEC,
            method(:_onPollTick)
        );

        WatchUi.requestUpdate();
    }

    function onHide() as Void { _stopTimers(); }

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();
        var cx = W / 2;

        // Background
        var bgColor = ThemeHelpers.getColor("bg");
        dc.setColor(bgColor, bgColor);
        dc.clear();

        // "Now Playing" title
        dc.setColor(ThemeHelpers.getColor("playback_controls"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (H * 0.12).toNumber(), Graphics.FONT_TINY, WatchUi.loadResource(Rez.Strings.NowPlaying),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Song name
        if (_songName != null) {
            dc.setColor(ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (H * 0.27).toNumber(), Graphics.FONT_XTINY, _songName.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } 

        // Artist name
        if (_artistName != null) {
            dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (H * 0.37).toNumber(), Graphics.FONT_XTINY, _artistName.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Main controls row: Rewind | Play | Skip @ 57% ──────────
        var ctrlY = (H * 0.57).toNumber();
        var spacing = (W * 0.28).toNumber();

        _drawIconCentered(dc, _rewindIcon, cx - spacing, ctrlY, ThemeHelpers.getColor("playback_controls"));
        _drawIconCentered(dc, _playIcon, cx, ctrlY, ThemeHelpers.getColor("playback_controls"));
        _drawIconCentered(dc, _skipIcon, cx + spacing, ctrlY, ThemeHelpers.getColor("playback_controls"));

        _rewindBounds = _iconBounds(_rewindIcon, cx - spacing, ctrlY);
        _playBounds = _iconBounds(_playIcon, cx, ctrlY);
        _skipBounds = _iconBounds(_skipIcon, cx + spacing, ctrlY);

        // ── Secondary row: Volume | Queue | Star @ 80% ─────────────────
        var secY = (H * 0.80).toNumber();
        var secSpacing = (W * 0.22).toNumber();

        _drawIconCentered(dc, _volumeIcon, cx - secSpacing, secY, ThemeHelpers.getColor("playback_volume"));
        _drawIconCentered(dc, _queueIcon, cx, secY, ThemeHelpers.getColor("playback_controls"));
        _drawIconCentered(dc, _starIcon, cx + secSpacing, secY, ThemeHelpers.getColor("playback_star"));

        _volumeBounds = _iconBounds(_volumeIcon, cx - secSpacing, secY);
        _queueBounds = _iconBounds(_queueIcon, cx, secY);
        _starBounds = _iconBounds(_starIcon, cx + secSpacing, secY);
    }

    // ── Accessors (called by PlaybackDelegate) ─────────────────────

    function getRewindBounds() as Array { return _rewindBounds; }
    function getPlayBounds() as Array { return _playBounds; }
    function getSkipBounds() as Array { return _skipBounds; }
    function getVolumeBounds() as Array { return _volumeBounds; }
    function getQueueBounds() as Array { return _queueBounds; }
    function getStarBounds() as Array { return _starBounds; }

    function isPlaying() as Boolean { return _isPlaying; }
    function togglePlayState() as Void { _isPlaying = !_isPlaying; }

    function getSongUri() as String? { return _songUri; }
    function getProvider() as PlaybackProvider { return _provider; }
    function isStatusReady() as Boolean { return _statusReady; }

    function canOpenQueue() as Boolean {
        if (!_statusReady) {
            return false;
        }

        if (_songUri == null || _songName == null || _artistName == null) {
            return false;
        }

        return System.getTimer() >= _queueReadyAtMs;
    }

    // Called by PlaybackDelegate after a skip or rewind.
    // Waits REFRESH_DELAY_MS before querying status so Spotify has time to advance.
    function refreshStatus() as Void {
        if (!_isActive) {
            return;
        }

        // Immediately treat status as stale while Spotify catches up
        _markStatusPending((TimerConstants.PLAYBACK_REFRESH_DELAY_SEC + 1) * 1000);

        // Cancel any pending refresh that hasn't fired yet
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.PLAYBACK_REFRESH_TASK_ID);
        _refreshPending = true;

        getApp().getSharedTimerManager().registerOneShotTask(
            TimerConstants.PLAYBACK_REFRESH_TASK_ID,
            TimerConstants.PLAYBACK_REFRESH_DELAY_SEC,
            method(:_onRefreshTick)
        );

        WatchUi.requestUpdate();
    }

    // ── Timer callbacks ────────────────────────────────────────────

    // Fires every POLL_INTERVAL_MS — detects when a song ends and a new one starts
    function _onPollTick() as Void {
        if (!_isActive) {
            return;
        }

        System.println("PlaybackView._onPollTick: polling status");
        _requestStatus();
    }

    // Fires once REFRESH_DELAY_MS after a skip/rewind
    function _onRefreshTick() as Void {
        if (!_isActive || !_refreshPending) {
            return;
        }

        _refreshPending = false;
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.PLAYBACK_REFRESH_TASK_ID);

        System.println("PlaybackView._onRefreshTick: fetching status after skip/rewind");
        _requestStatus();
    }

    // ── Status response callback ───────────────────────────────────

    function _onStatusReceived(data as Lang.Dictionary) as Void {
      if (!_isActive) {
          return;
      }

      _statusReady = true;

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

    // ── Private helpers ────────────────────────────────────────────

    private function _requestStatus() as Void {
        if (!_isActive) {
            return;
        }
        _provider.sendPlaybackCommand("status", null, null, method(:_onStatusReceived));
    }

    private function _stopTimers() as Void {
        _isActive = false;
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.PLAYBACK_POLL_TASK_ID);
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.PLAYBACK_REFRESH_TASK_ID);
        _refreshPending = false;
    }

    private function _drawIconCentered(dc as Dc, icon, cx as Number, cy as Number, tint as Number) as Void {
        if (icon == null) {
            return;
        }
        var iw = icon.getWidth();
        var ih = icon.getHeight();
        dc.drawBitmap2(cx - iw / 2, cy - ih / 2, icon, { :tintColor => tint });
    }

    // Returns [x, y, w, h] centered on (cx, cy) with the icon's natural size.
    private function _iconBounds(icon, cx as Number, cy as Number) as Array {
        if (icon == null) {
            return [cx - 16, cy - 16, 32, 32] as Array;
        }
        var iw = icon.getWidth();
        var ih = icon.getHeight();
        return [cx - iw / 2, cy - ih / 2, iw, ih] as Array;
    }

    private function _markStatusPending(blockMs as Number) as Void {
        _statusReady = false;
        _queueReadyAtMs = System.getTimer() + blockMs;
    }
}
