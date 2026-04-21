/*
Name: source/Playback/QueueView.mc
Description: Simple queue screen for Spotify playback. Fetches queue data from
             PlaybackService and displays the currently playing track plus
             a basic text list of upcoming songs.
Authors: Ella Nguyen
Created: April 19, 2026
Last Modified: April 20, 2026
*/

import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class QueueView extends WatchUi.View {

    private var _provider as PlaybackProvider;

    private var _loading as Boolean;
    private var _loadFailed as Boolean;

    private var _queue as Array;
    private var _selectedIndex as Number;
    private var _scrollOffset as Number;

    private var _rowCoverCache as Lang.Dictionary;
    private var _pendingCoverUrl as String?;
    private var _placeholderIcon;


    function initialize(provider as PlaybackProvider) {
        View.initialize();

        _provider = provider;
        _loading = true;
        _loadFailed = false;
        _queue = [] as Array;
        _selectedIndex = 0;
        _scrollOffset = 0;
        _rowCoverCache = {} as Lang.Dictionary;
        _pendingCoverUrl = null;
        _placeholderIcon = loadResource(Rez.Drawables.musicIcon);
    }

    function onShow() as Void {
        _loading = true;
        _loadFailed = false;
        _queue = [] as Array;
        _selectedIndex = 0;
        _scrollOffset = 0;
        _pendingCoverUrl = null;
        _rowCoverCache = {} as Lang.Dictionary;

        _provider.sendPlaybackCommand("queue", null, null, method(:_onQueueLoaded));
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var left = 50;
        var y = 20;

        var bgColor = ThemeHelpers.getColor("bg");
        dc.setColor(bgColor, bgColor);
        dc.clear();

        // Title
        dc.setColor(ThemeHelpers.getColor("playback_controls"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(W / 2, y, Graphics.FONT_TINY, "Queue", Graphics.TEXT_JUSTIFY_CENTER);
        y += 32;

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

        y += 10;

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
        y += 28;

        // Fewer visible rows so text doesn't crowd the screen
        var maxRows = 3;
        var startIndex = _scrollOffset;
        var endIndex = startIndex + maxRows;

        if (endIndex > _queue.size()) {
            endIndex = _queue.size();
        }

        _ensureVisibleCovers();

        for (var i = startIndex; i < endIndex; i += 1) {
            var item = _queue[i] as Lang.Dictionary;
            var name = item["name"];
            var artist = item["artist_name"];
            var isSelected = (i == _selectedIndex);

            var rowTop = y;
            var rowHeight = 78;

            var coverSize = 56;
            var coverX = left + 10;
            var coverY = rowTop + (rowHeight - coverSize) / 2;

            var textX = coverX + coverSize + 14;

            if (isSelected) {
                dc.setColor(Graphics.COLOR_WHITE, ThemeHelpers.getColor("playback_controls"));
                dc.fillRoundedRectangle(4, rowTop - 2, dc.getWidth() - 8, rowHeight, 10);
                dc.setColor(ThemeHelpers.getColor("bg"), Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
            }

            var imageUrl = item["image_url"];
            var cachedCover = null;

            if (imageUrl != null) {
                cachedCover = _rowCoverCache[imageUrl.toString()];
            }

            if (cachedCover != null) {
                dc.drawBitmap(coverX, coverY, cachedCover);
            } else if (_placeholderIcon != null) {
                _drawTinyIconCentered(
                    dc,
                    _placeholderIcon,
                    coverX + (coverSize / 2),
                    coverY + (coverSize / 2),
                    ThemeHelpers.getColor("playback_artist_name")
                );
            } else {
                dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(coverX, coverY, coverSize, coverSize);
            }

            var titleFont = Graphics.FONT_XTINY;
            var artistFont = Graphics.FONT_XTINY;

            var titleMaxWidth = dc.getWidth() - textX - 18;
            var artistMaxWidth = dc.getWidth() - textX - 18;

            var rawTitle = name != null ? name.toString() : "Unknown track";
            var rawArtist = artist != null ? artist.toString() : "Unknown artist";

            var displayTitle = _truncateText(dc, rawTitle, titleFont, titleMaxWidth);
            var displayArtist = _truncateText(dc, rawArtist, artistFont, artistMaxWidth);

            // Spacing
            var lineGap = 22;
            var totalTextHeight = 2 * lineGap;

            var textStartY = rowTop + ((rowHeight - totalTextHeight) / 2) - 2;

            dc.setColor(isSelected ? ThemeHelpers.getColor("bg") : ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, textStartY, titleFont, displayTitle, Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(isSelected ? ThemeHelpers.getColor("bg") : ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, textStartY + lineGap, artistFont, displayArtist, Graphics.TEXT_JUSTIFY_LEFT);

            y += 80;
        }
    }

    private function _ensureVisibleCovers() as Void {
        if (_pendingCoverUrl != null) {
            return;
        }

        var maxRows = 3;
        var startIndex = _scrollOffset;
        var endIndex = startIndex + maxRows;

        if (endIndex > _queue.size()) {
            endIndex = _queue.size();
        }

        for (var i = startIndex; i < endIndex; i += 1) {
            var item = _queue[i] as Lang.Dictionary;
            var imageUrl = item["image_url"];

            if (imageUrl == null) {
                continue;
            }

            var url = imageUrl.toString();

            if (_rowCoverCache[url] == null) {
                _requestRowCover(url);
                return;
            }
        }
    }

    private function _requestRowCover(url as String) as Void {
        System.println("REQUESTING ROW COVER: " + url);
        _pendingCoverUrl = url;

        Communications.makeImageRequest(
            url,
            {},
            {
                :width => 56,
                :height => 56,
                :dithering => Communications.IMAGE_DITHERING_NONE
            },
            method(:_onRowCoverLoaded)
        );
    }

    function _onRowCoverLoaded(responseCode as Lang.Number, data as Graphics.BitmapReference or WatchUi.BitmapResource or Null) as Void {
        System.println("ROW COVER RESPONSE CODE = " + responseCode);
        System.println("ROW COVER URL = " + _pendingCoverUrl);
        System.println("ROW COVER DATA NULL? " + (data == null));
        
        if (_pendingCoverUrl != null && responseCode == 200 && data != null) {
            _rowCoverCache[_pendingCoverUrl] = data;
        }

        _pendingCoverUrl = null;
        WatchUi.requestUpdate();
    }

    function _onQueueLoaded(data as Lang.Dictionary) as Void {
        System.println("QueueView._onQueueLoaded: " + data);
        System.println("RAW QUEUE DATA = " + data["queue"]);

        _loading = false;
        _loadFailed = false;
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

        var queueData = data["queue"];
        if (queueData != null && queueData instanceof Array) {
            _queue = queueData;

            if (_queue.size() > 0) {
                var firstItem = _queue[0] as Lang.Dictionary;
                System.println("FIRST QUEUE ITEM IMAGE URL = " + firstItem["image_url"]);
            }
        }

        _ensureVisibleCovers();
        WatchUi.requestUpdate();
    }

    private function _drawTinyIconCentered(dc as Dc, icon, cx as Number, cy as Number, tint as Number) as Void {
        if (icon == null) {
            return;
        }

        var iw = icon.getWidth();
        var ih = icon.getHeight();

        dc.drawBitmap2(
            cx - iw / 2,
            cy - ih / 2,
            icon,
            { :tintColor => tint }
        );
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

        _ensureVisibleCovers();
        WatchUi.requestUpdate();
    }
}