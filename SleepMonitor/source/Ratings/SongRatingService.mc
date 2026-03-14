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

// Posts a star rating for a song to the REMix backend.
//
// userId  - identifier of the currently logged-in user
// song    - the song object that was played (type/structure TBD)
// rating  - integer star rating from 1 to 5 (inclusive)
//
// TODO: implement — make an authenticated HTTP POST to the ratings endpoint.
function submitSongRating(userId as Object, song as Object, rating as Number) as Void {
    System.println("submitSongRating: userId=" + userId + " song=" + song + " rating=" + rating);
}
