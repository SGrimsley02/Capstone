/*
Name: source/Ratings/SongRatingService.mc
Description: Service layer for submitting song ratings to the REMix backend.
             Called by RatingDelegate when the user confirms a star rating.
Authors: Kiara Rose
Created: March 14, 2026
Last Modified: March 14, 2026
*/

import Toybox.Lang;
import Toybox.System;
import Toybox.Communications;

class SongRatingService {

    function initialize() {
    }

    // Call this method explicitly AFTER creating the object
    function submitRating(userId as String, song as String, rating as Number, sleepScore as Number?) as Void {
        var url = "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/storage/song-rating";

        // Failsafe: Prevent nulls from crashing the Garmin network API
        if (userId == null || song == null || rating == null) {
            System.println("Error: Null value passed to submitRating");
            return;
        }

        var payload = {
            "userId" => userId,
            "track_uri" => song,
            "rating" => rating,
            "sleep_score" => sleepScore
        };

        try {
            Communications.makeWebRequest(
                url,
                payload,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :headers => {
                        "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onRatingResponse)
            );
        } catch (ex) {
            System.println("submitSongRating FAILED: " + ex.toString());
        }
    }

    // FIX: Removed 'private' to ensure safe symbol resolution
    function onRatingResponse(responseCode as Number, responseData as Dictionary or String or Null) as Void {
        System.println("SongRatingService.onRatingResponse: responseCode=" + responseCode);
        if (responseData != null) {
            System.println("SongRatingService.onRatingResponse: responseData=" + responseData.toString());
        }
    }
}