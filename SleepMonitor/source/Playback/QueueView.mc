/*
Name: source/Playback/QueueView.mc
Description: Simple queue screen for Spotify playback. Fetches queue data from
             PlaybackService and displays the currently playing track plus
             a basic text list of upcoming songs.
Authors: Ella Nguyen
Created: April 19, 2026
Last Modified: April 19, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class QueueView extends WatchUi.View {

    private var _provider as PlaybackProvider;

    private var _loading as Boolean;
    private var _loadFailed as Boolean;

    private var _currentlyPlaying as Lang.Dictionary?;
    private var _queue as Array;
    private var _selectedIndex as Number;
    private var _scrollOffset as Number;


    function initialize(provider as PlaybackProvider) {
        View.initialize();

        _provider = provider;
        _loading = true;
        _loadFailed = false;
        _currentlyPlaying = null;
        _queue = [] as Array;
        _selectedIndex = 0;
        _scrollOffset = 0;
    }

    function onShow() as Void {
        _loading = true;
        _loadFailed = false;
        _currentlyPlaying = null;
        _queue = [] as Array;
        _selectedIndex = 0;
        _scrollOffset = 0;

        _provider.sendPlaybackCommand("queue", null, null, method(:_onQueueLoaded));
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var left = 16;
        var y = 20;

        var bgColor = ThemeHelpers.getColor("bg");
        dc.setColor(bgColor, bgColor);
        dc.clear();

        // Title
        dc.setColor(ThemeHelpers.getColor("playback_controls"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(W / 2, y, Graphics.FONT_TINY, "Queue", Graphics.TEXT_JUSTIFY_CENTER);
        y += 40;

        var centerX = dc.getWidth() / 2;

        if (_loading) {
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Loading queue...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_loadFailed) {
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Could not load queue.", Graphics.TEXT_JUSTIFY_CENTER);
            y += 20;
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Open Spotify on a device first.", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Now Playing header
        dc.setColor(ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(W / 2, y, Graphics.FONT_XTINY, "Now Playing:", Graphics.TEXT_JUSTIFY_CENTER);
        y += 25;

        if (_currentlyPlaying != null) {
            var currentName = _currentlyPlaying["name"];
            var currentArtist = _currentlyPlaying["artist_name"];

            var nowTitleFont = Graphics.FONT_XTINY;
            var nowArtistFont = Graphics.FONT_XTINY;

            var nowTitle = _truncateText(
                dc,
                currentName != null ? currentName.toString() : "Unknown track",
                nowTitleFont,
                dc.getWidth() - 70
            );

            var nowArtist = _truncateText(
                dc,
                currentArtist != null ? currentArtist.toString() : "Unknown artist",
                nowArtistFont,
                dc.getWidth() - 80
            );

            dc.drawText(
                W / 2,
                y,
                nowTitleFont,
                nowTitle,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            y += 20;

            dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                W / 2,
                y,
                nowArtistFont,
                nowArtist,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            y += 30;
        } else {
            dc.drawText(W / 2, y, Graphics.FONT_XTINY, "Nothing currently playing", Graphics.TEXT_JUSTIFY_CENTER);
            y += 24;
        }

        // Up Next header
        if (_queue.size() == 0) {
            dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, y, Graphics.FONT_XTINY, "Up Next:", Graphics.TEXT_JUSTIFY_LEFT);
            y += 30;
            dc.drawText(left + 8, y, Graphics.FONT_XTINY, "Queue is empty.", Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            left,
            y,
            Graphics.FONT_XTINY,
            "Up Next (" + (_selectedIndex + 1).toString() + "/" + _queue.size().toString() + "):",
            Graphics.TEXT_JUSTIFY_LEFT
        );
        y += 34;

        // Fewer visible rows so text doesn't crowd the screen
        var maxRows = 3;
        var startIndex = _scrollOffset;
        var endIndex = startIndex + maxRows;

        if (endIndex > _queue.size()) {
            endIndex = _queue.size();
        }

        for (var i = startIndex; i < endIndex; i += 1) {
            var item = _queue[i] as Lang.Dictionary;
            var name = item["name"];
            var artist = item["artist_name"];
            var isSelected = (i == _selectedIndex);

            if (isSelected) {
                dc.setColor(Graphics.COLOR_WHITE, ThemeHelpers.getColor("playback_controls"));
                dc.fillRoundedRectangle(left + 4, y - 3, dc.getWidth() - 24, 50, 6);
                dc.setColor(ThemeHelpers.getColor("bg"), Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
            }

            var titleFont = Graphics.FONT_XTINY;
            var artistFont = Graphics.FONT_XTINY;

            var titleMaxWidth = dc.getWidth() - 40;
            var artistMaxWidth = dc.getWidth() - 70;

            var rawTitle = name != null ? name.toString() : "Unknown track";
            var rawArtist = artist != null ? artist.toString() : "Unknown artist";

            var displayTitle = _truncateText(dc, rawTitle, titleFont, titleMaxWidth);
            var displayArtist = _truncateText(dc, rawArtist, artistFont, artistMaxWidth);

            dc.drawText(left + 10, y, titleFont, displayTitle, Graphics.TEXT_JUSTIFY_LEFT);
            y += 19;

            if (isSelected) {
                dc.setColor(ThemeHelpers.getColor("bg"), Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            }

            dc.drawText(left + 26, y, artistFont, displayArtist, Graphics.TEXT_JUSTIFY_LEFT);
            y += 31;
        }
    }

    function _onQueueLoaded(data as Lang.Dictionary) as Void {
        System.println("QueueView._onQueueLoaded: " + data);
        System.println("RAW QUEUE DATA = " + data["queue"]);

        _loading = false;
        _loadFailed = false;
        _currentlyPlaying = null;
        _queue = [] as Array;

        if (data == null) {
            _loadFailed = true;
            WatchUi.requestUpdate();
            return;
        }

        var success = data["success"];
        if (success == null || !(success as Boolean)) {
            _loadFailed = true;
            WatchUi.requestUpdate();
            return;
        }

        var currentlyPlaying = data["currently_playing"];
        if (currentlyPlaying != null && currentlyPlaying instanceof Lang.Dictionary) {
            _currentlyPlaying = currentlyPlaying;
        }

        var queueData = data["queue"];
        if (queueData != null && queueData instanceof Array) {
            _queue = queueData;
        }

        WatchUi.requestUpdate();
    }

    function _truncateText(dc as Dc, text as String, font as Graphics.FontType, maxWidth as Number) as String {
        if (text == null) {
            return "";
        }

        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var ellipsis = "...";
        var shortened = text;

        while (shortened.length() > 0 &&
            dc.getTextWidthInPixels(shortened + ellipsis, font) > maxWidth) {
            shortened = shortened.substring(0, shortened.length() - 1);
        }

        return shortened + ellipsis;
    }

    function getProvider() as PlaybackProvider {
        return _provider;
    }

    function getQueue() as Array {
        return _queue;
    }

    function getSelectedIndex() as Number {
        return _selectedIndex;
    }

    function getScrollOffset() as Number {
        return _scrollOffset;
    }

    function setScrollOffset(offset as Number) as Void {
        if (_queue.size() == 0) {
            _scrollOffset = 0;
            return;
        }

        var maxRows = 3;
        var maxOffset = _queue.size() - maxRows;
        if (maxOffset < 0) {
            maxOffset = 0;
        }

        if (offset < 0) {
            _scrollOffset = 0;
        } else if (offset > maxOffset) {
            _scrollOffset = maxOffset;
        } else {
            _scrollOffset = offset;
        }

        WatchUi.requestUpdate();
    }

    function setSelectedIndex(index as Number) as Void {
        if (_queue.size() == 0) {
            _selectedIndex = 0;
            _scrollOffset = 0;
            return;
        }

        if (index < 0) {
            _selectedIndex = 0;
        } else if (index >= _queue.size()) {
            _selectedIndex = _queue.size() - 1;
        } else {
            _selectedIndex = index;
        }

        var maxRows = 3;

        if (_selectedIndex < _scrollOffset) {
            _scrollOffset = _selectedIndex;
        } else if (_selectedIndex >= _scrollOffset + maxRows) {
            _scrollOffset = _selectedIndex - maxRows + 1;
        }

        WatchUi.requestUpdate();
    }
}