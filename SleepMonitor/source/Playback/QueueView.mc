/*
Name: source/Playback/QueueView.mc
Description: Simple queue screen for Spotify playback. Fetches queue data from
             PlaybackService and displays the currently playing track plus
             a basic text list of upcoming songs.
Authors: Ella Nguyen
Created: April 19, 2026
Last Modified: April 22, 2026
*/

import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class QueueView extends WatchUi.View {

    // Queue data + UI state
    private var _provider as PlaybackProvider;
    private var _loading as Boolean;
    private var _loadFailed as Boolean;

    private var _queue as Array;
    private var _selectedIndex as Number;
    private var _scrollOffset as Number;

    // Album art caching
    private var _rowCoverCache as Lang.Dictionary;
    private var _pendingCoverUrl as String?;
    private var _placeholderIcon;

    // Row tap targets
    var rowHitboxes = [];


    // ── Lifecycle ────────────────────────────────────────────

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
        rowHitboxes = [];
    }

    function onShow() as Void {
        _loading = true;
        _loadFailed = false;
        _queue = [] as Array;
        _selectedIndex = 0;
        _scrollOffset = 0;
        _pendingCoverUrl = null;
        _rowCoverCache = {} as Lang.Dictionary;
        rowHitboxes = [];

        _provider.sendPlaybackCommand("queue", null, null, method(:_onQueueLoaded));
        WatchUi.requestUpdate();
    }

    // ── Rendering ────────────────────────────────────────────

    function onUpdate(dc as Dc) as Void {
        var W = dc.getWidth();
        var H = dc.getHeight();

        // Layout Constants
        var left = (W * 0.12).toNumber();
        var rightPad = (W * 0.08).toNumber();
        var maxRows = 3;
        var rowGap = (H * 0.015).toNumber();
        var y = (H * 0.08).toNumber();

        // Colors
        var bgColor = ThemeHelpers.getColor("bg");
        var selectedBg = ThemeHelpers.getColor("queue_selected_bg");
        var selectedTitle = ThemeHelpers.getColor("queue_selected_title");
        var selectedArtist = ThemeHelpers.getColor("queue_selected_artist");

        dc.setColor(bgColor, bgColor);
        dc.clear();
        rowHitboxes = [];

        // Draw Header ("Queue")
        dc.setColor(ThemeHelpers.getColor("playback_controls"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(W / 2, y, Graphics.FONT_TINY, loadResource(Rez.Strings.Queue), Graphics.TEXT_JUSTIFY_CENTER);
        
        y += (H * 0.11).toNumber();

        // Loading & Error States
        if (_loading) {
            dc.drawText(W / 2, y + 20, Graphics.FONT_XTINY, loadResource(Rez.Strings.LoadingQueue), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (_loadFailed) {
            dc.drawText(W / 2, y + 20, Graphics.FONT_XTINY, loadResource(Rez.Strings.QueueNotLoaded), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Draw "Up Next" Text
        dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
        var upNextStr = loadResource(Rez.Strings.UpNext) + " (" + (_selectedIndex + 1).toString() + "/" + _queue.size().toString() + "):";
        dc.drawText(left, y, Graphics.FONT_XTINY, upNextStr, Graphics.TEXT_JUSTIFY_LEFT);

        // Calculate List Area
        var listTop = y + (dc.getFontHeight(Graphics.FONT_XTINY) * 1.4).toNumber();
        var listBottom = (H * 0.78).toNumber(); 
        var listHeight = listBottom - listTop;

        var totalGapHeight = (maxRows - 1) * rowGap;
        var rowHeight = ((listHeight - totalGapHeight) / maxRows).toNumber();
        var coverSize = (rowHeight * 0.70).toNumber();

        var startIndex = _scrollOffset;
        var endIndex = startIndex + maxRows;
        if (endIndex > _queue.size()) { 
            endIndex = _queue.size(); 
        }

        _ensureVisibleCovers();

        // Render Rows
        for (var i = startIndex; i < endIndex; i += 1) {
            var item = _queue[i] as Lang.Dictionary;
            var isSelected = (i == _selectedIndex);
            var visibleIndex = i - startIndex;
            
            var rowTop = listTop + (visibleIndex * (rowHeight + rowGap));
            
            var cardWidth = W - 20; 
            var cardX = (W - cardWidth) / 2 + 6; 

            rowHitboxes.add([cardX, rowTop, cardWidth, rowHeight]);

            if (isSelected) {
                var rectPaddingY = 12; 
                var stretchX = 0;
                var stretchWidth = (cardX + cardWidth) - stretchX;
                
                dc.setColor(selectedBg, selectedBg);
                dc.fillRoundedRectangle(
                    stretchX, 
                    rowTop - (rectPaddingY / 2), 
                    stretchWidth, 
                    rowHeight + rectPaddingY, 
                    8
                );
            }

            // --- Artwork Rendering ---
            var coverX = cardX + (cardWidth * 0.05).toNumber();
            var coverY = rowTop + ((rowHeight - coverSize) / 2);

            var imageUrl = item["image_url"];
            var cachedCover = (imageUrl != null) ? _rowCoverCache[imageUrl.toString()] : null;

            if (cachedCover != null) {
                dc.drawBitmap(coverX, coverY, cachedCover);
            } else {
                dc.setColor(ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(coverX, coverY, coverSize, coverSize);
            }

            // --- Text Rendering ---
            var titleFont = Graphics.FONT_XTINY;
            var artistFont = Graphics.FONT_XTINY;
            
            var internalGap = -2; 

            var textGap = (W * 0.04).toNumber(); 
            var totalTextBlockHeight = dc.getFontHeight(titleFont) + dc.getFontHeight(artistFont) + internalGap;
            
            var textStartY = rowTop + ((rowHeight - totalTextBlockHeight) / 2);
            var textX = coverX + coverSize + textGap;
            
            var titleMaxWidth = (cardX + cardWidth) - textX - rightPad;

            // Title Moving (Used to separate title and artist)
            var titleVerticalScooch = 1;

            // Draw Title
            dc.setColor(isSelected ? selectedTitle : ThemeHelpers.getColor("playback_song_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, textStartY - titleVerticalScooch, titleFont, _truncateText(dc, item["name"], titleFont, titleMaxWidth), Graphics.TEXT_JUSTIFY_LEFT);

            // Draw Artist
            dc.setColor(isSelected ? selectedArtist : ThemeHelpers.getColor("playback_artist_name"), Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, textStartY + dc.getFontHeight(titleFont) + internalGap, artistFont, _truncateText(dc, item["artist_name"], artistFont, titleMaxWidth), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── Album art loading ───────────────────────────────────

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
        
        if (_pendingCoverUrl != null && responseCode == 200 && data != null) {
            _rowCoverCache[_pendingCoverUrl] = data;
        }

        _pendingCoverUrl = null;
        WatchUi.requestUpdate();
    }

    // ── Queue callback ──────────────────────────────────────

    function _onQueueLoaded(data as Lang.Dictionary) as Void {

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
        }

        _ensureVisibleCovers();
        WatchUi.requestUpdate();
    }

    // ── Helpers ─────────────────────────────────────────────

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

    // ── Navigation ──────────────────────────────────────────

    function getSelectedIndex() as Number {
        return _selectedIndex;
    }

    function getScrollOffset() as Number {
        return _scrollOffset;
    }

    function getVisibleIndexForTap(tx as Number, ty as Number) as Number {
        for (var i = 0; i < rowHitboxes.size(); i += 1) {
            var hitbox = rowHitboxes[i];
            if (tx >= hitbox[0] && tx <= hitbox[0] + hitbox[2] &&
                ty >= hitbox[1] && ty <= hitbox[1] + hitbox[3]) {
                return _scrollOffset + i;
            }
        }

        return -1;
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