/*
Name: source/Network/PodcastService.mc
Description: Implements the PlaybackProvider class responsible for communicating
                with the AWS Lambda backend to control Spotify playback on the user's phone.
                Also handles checking of playback status and triggering review submission whenever
                a song finishes playing or the user exits the playback screen.
Authors: Kiara Rose, Ella Nguyen
Created: March 14, 2026
Last Modified: April 19, 2026
*/


import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import StorageKeys;

class PlaybackProvider {
    private var _userId;
    private var _notifyUrl = "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/spotify/playback";
    private var _callbacks as Lang.Dictionary;
    private var _nextRequestId as Number;

    private function _refreshUserId() as Void {
        var stored = Application.Storage.getValue(StorageKeys.USER_ID_KEY);
        _userId = stored != null ? stored.toString() : "unknown";
    }


    function initialize() {
        var stored = Application.Storage.getValue(StorageKeys.USER_ID_KEY);
        _userId = stored != null ? stored.toString() : "unknown"; //Fall back to default username if not yet set
        System.println("PlaybackProvider user_id: " + _userId);
        _callbacks = {} as Lang.Dictionary;
        _nextRequestId = 0;
    }


    // Expected event examples:
    // { "userId": "testing" }
    // { "userId": "testing", "action": "pause" }
    // { "userId": "testing", "action": "play", "trackUri": "spotify:track:..." }
    // { "userId": "testing", "action": "resume" }
    // { "userId": "testing", "action": "next" }
    // { "userId": "testing", "action": "previous" }
    // { "userId": "testing", "action": "volume", "volume": 35 }
    // { "userId": "testing", "action": "status" }
    // { "userId": "testing", "action": "queue" }
    // { "userId": "testing", "action": "play_uri", "trackUri": "spotify:track:..." }
    // Goal: allow user to pause, resume, skip, replay, fetch queue data, and adjust volume through watch app UI
    //       Use "status" action to check if a song is playing and retrieve its URI for review submission.

    function sendPlaybackCommand(action as String, volume as Number?, trackUri as String?, callback as Lang.Method?) as Void {
        _refreshUserId();

        _nextRequestId += 1;
        var requestId = _nextRequestId.toString();

        if (callback != null) {
            _callbacks[requestId] = callback;
        }

        var payload = {
            "userId" => _userId,
            "action" => action,
            "requestId" => requestId
        };

        if (action.equals("volume")) {
            payload["volume"] = volume;
        }

        if (trackUri != null) {
            payload["trackUri"] = trackUri;
        }

        Communications.makeWebRequest(
            _notifyUrl,
            payload,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:_onPlaybackResponse)
        );
    }

    function playQueueFrom(trackUri as String, queueUris as String, callback as Lang.Method?) as Void {
        _refreshUserId();

        _nextRequestId += 1;
        var requestId = _nextRequestId.toString();

        if (callback != null) {
            _callbacks[requestId] = callback;
        }

        System.println("PlaybackProvider.playQueueFrom user_id: " + _userId);

        var payload = {
            "userId" => _userId,
            "action" => "play_uri",
            "trackUri" => trackUri,
            "queueUris" => queueUris,
            "requestId" => requestId
        };

        try {
            Communications.makeWebRequest(
                _notifyUrl,
                payload,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:_onPlaybackResponse)
            );
        } catch (e) {
            System.println("playQueueFrom FAILED: " + e.toString());
        }
    }

    function _onPlaybackResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        System.println("PlaybackProvider._onPlaybackResponse: responseCode=" + responseCode + " data=" + data);

        if (!(data instanceof Lang.Dictionary)) {
            return;
        }

        var requestId = data["requestId"];
        if (requestId == null) {
            return;
        }

        var callback = _callbacks[requestId.toString()];
        if (callback != null) {
            _callbacks.remove(requestId.toString());
            callback.invoke(data);
        }
    }
}
