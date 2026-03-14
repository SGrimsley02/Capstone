/*
Name: source/Network/PodcastService.mc
Description: Implements the PlaybackProvider class responsible for communicating
                with the AWS Lambda backend to control Spotify playback on the user's phone.
                Also handles checking of playback status and triggering review submission whenever
                a song finishes playing or the user exits the playback screen.
Authors: Kiara Rose
Created: March 14, 2026
Last Modified: March 14, 2026
*/


import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;

class PlaybackProvider {
    private var _userId;
    private var _notifyUrl = "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/spotify/playback";


    function initialize() {
        var stored = Application.Storage.getValue("user_id");
        _userId = stored != null ? stored.toString() : "unknown"; //Fall back to default username if not yet set
        _userId = "playbacktest"; // Hardcode for testing purposes
        System.println("PlaybackProvider user_id: " + _userId);
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
    // Goal: allow user to pause, resume, skip, replay, and adjust volume through watch app UI
    //       Use "status" action to check if a song is playing and retrieve its URI for review submission.

    function sendPlaybackCommand(action as String, volume as Number?) as Void {
        var payload = {
            "userId" => _userId,
            "action" => action
        };
        if (action == "volume" && volume != null) {
            payload["volume"] = volume;
        }

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
            System.println("sendPlaybackCommand FAILED: " + e.toString());
        }
    }

    function _onPlaybackResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        System.println("PlaybackProvider._onPlaybackResponse: responseCode=" + responseCode + " data=" + data);
    }
}