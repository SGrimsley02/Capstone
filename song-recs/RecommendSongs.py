'''
This program handles recommending songs to users based on their ratings.
Implements the SongRecommender class, interacting with MusicAPI and database
to get user data and update playlists.
- createInitialPlaylists: creates initial playlists for the user based on their top and saved songs
- updateAllPlaylists: updates all playlists for the user based on their latest ratings

Last updated: 4.17.26
By: Kiara
'''

from MusicAPI import MusicAPI
from DatabaseService import DatabaseService
import logging

logger = logging.getLogger(__name__)

class SongRecommender:
    def __init__(self, userId: str, userSecret: str, remixUsername: str):
        '''
        Initialize the SongRecommender with the MusicAPI and DatabaseService.
        Input:
        userId[str] = the Spotify client ID for the user
        userSecret[str] = the Spotify client secret for the user
        remixUsername[str] = the REMix username for the user
        '''
        self.music_api = MusicAPI(spotify_client_id=userId, spotify_client_secret=userSecret)
        self.db_service = DatabaseService()
        self.username = remixUsername
        self.user_playlists = self._get_or_create_playlists()

    def _get_or_create_playlists(self) -> dict:
        '''
        Return existing user playlists if present, otherwise create and store them.
        '''
        existing_playlists = self.db_service.get_all_playlist_ids(self.username)
        if len(existing_playlists) == 3:
            return existing_playlists
        return self.createInitialPlaylists()

    # ===============================
    # Playlist Management Functions
    # ===============================

    def createInitialPlaylists(self) -> dict:
        '''
        Create initial playlists for the user.
        Good, Average, Poor sleep playlists depending on how well they slept.
        Initial songs recommended based on their top and saved songs.

        Output:
        playlist_ids[dict] = a dictionary containing the playlist IDs for the user
        '''

        playlist_ids = {
            "good": self.music_api.create_playlist(name="REMix: Good Sleep", public=False, description="Music to energize your morning after a great night's sleep"),
            "average": self.music_api.create_playlist(name="REMix: Average Sleep", public=False, description="Music to wake up to after only sleeping okay"),
            "poor": self.music_api.create_playlist(name="REMix: Poor Sleep", public=False, description="Music to ease into your morning after rough sleep")
        }

        # Store playlist IDs in database for the user
        for sleep_quality, playlist_id in playlist_ids.items():
            success = self.db_service.store_playlist_mapping(self.username, sleep_quality, playlist_id)
            if not success:
                logger.error(f"Failed to store playlist mapping for {sleep_quality} sleep")

        # Initialize user's playlists with songs based on their top songs and saved songs
        top_songs = self.music_api.get_user_top_tracks(time_range="medium_term", limit=50)
        saved_songs = self.music_api.get_user_saved_tracks(limit=50)
        seeds = [song["uri"] for song in top_songs + saved_songs]

        # Good sleep -> energetic
        # Average sleep -> lofi, calm
        # Poor sleep -> slow, instrumental

        good_sleep_songs = self.music_api.get_recommendations(
            size=20,
            seeds=seeds,
            danceability=0.8,
            energy=0.8,
            valence=0.8,
            popularity=80,
            mode=1,
            featureWeight=4.0
        )
        average_sleep_songs = self.music_api.get_recommendations(
            size=20,
            seeds=seeds,
            danceability=0.4,
            acousticness=0.8,
            energy=0.5,
            instrumentalness=0.2,
            liveness=0.4,
            popularity=70,
            featureWeight=2.5
        )
        poor_sleep_songs = self.music_api.get_recommendations(
            size=20,
            seeds=seeds,
            danceability=0.2,
            acousticness=0.9,
            energy=0.2,
            instrumentalness=0.6,
            liveness=0.4,
            mode=0,
            valence=0.4,
            popularity=70,
            featureWeight=4.0
        )
        self.addSongsToPlaylist(playlist_ids["good"], [song["uri"] for song in good_sleep_songs])
        self.addSongsToPlaylist(playlist_ids["average"], [song["uri"] for song in average_sleep_songs])
        self.addSongsToPlaylist(playlist_ids["poor"], [song["uri"] for song in poor_sleep_songs])

        return playlist_ids

    def updateAllPlaylists(self) -> None:
        '''
        Update all playlists for the user based on their latest ratings.
        Implements weekly replacement strategy: clears each playlist and repopulates with fresh recommendations.
        '''

        playlist_ids = self.user_playlists or self.db_service.get_all_playlist_ids(self.username)

        for sleep_quality, playlist_id in playlist_ids.items():
            if not playlist_id:
                logger.warning(f"Playlist not found for {sleep_quality} sleep, skipping update")
                continue

            try:
                # Get current playlist tracks to remove them (weekly replacement strategy)
                current_tracks = self._get_all_playlist_tracks(playlist_id)
                if current_tracks:
                    track_uris = [track["uri"] for track in current_tracks]
                    self.removeSongsFromPlaylist(playlist_id, track_uris)
                    logger.info(f"Cleared {len(track_uris)} tracks from {sleep_quality} sleep playlist")

                # Generate and add new recommendations
                new_recommendations = self.recommendSongs(sleep_quality, playlist_id)
                if new_recommendations:
                    self.addSongsToPlaylist(playlist_id, new_recommendations)
                    logger.info(f"Added {len(new_recommendations)} new recommendations to {sleep_quality} sleep playlist")
                else:
                    logger.warning(f"No new recommendations generated for {sleep_quality} sleep")

            except Exception as e:
                logger.error(f"Failed to update {sleep_quality} sleep playlist: {str(e)}")

    def _get_all_playlist_tracks(self, playlist_id: str) -> list:
        '''
        Retrieve all tracks in a playlist by paging through Spotify results.
        '''
        all_tracks = []
        limit = 50
        offset = 0

        while True:
            page = self.music_api.get_playlist_item(playlist_id=playlist_id, limit=limit, offset=offset)
            if not page:
                break

            all_tracks.extend(page)
            if len(page) < limit:
                break

            offset += limit

        return all_tracks

    # ===============================
    # Helper Functions
    # ===============================

    def getPositiveSeeds(self, sleep_quality: str) -> list:
        '''
        Get positive seed songs for the user from the database ratings based on their sleep quality.
        Positive seeds are songs the user rated 4-5 stars during sessions with the given sleep quality.

        Input:
        sleep_quality[str] = the user's sleep quality ("good", "average", "poor")

        Output:
        positive_seeds[list] = a list of song URIs with ratings >= 4 for the given sleep quality
        '''
        try:
            positive_seeds = self.db_service.get_positive_seeds(self.username, sleep_quality)
            logger.info(f"Retrieved {len(positive_seeds)} positive seeds for {sleep_quality} sleep")
            return positive_seeds
        except Exception as e:
            logger.error(f"Failed to retrieve positive seeds for {sleep_quality}: {str(e)}")
            return []

    def getNegativeSeeds(self, sleep_quality: str) -> list:
        '''
        Get negative seed songs for the user from the database ratings based on their sleep quality.
        Negative seeds are songs the user rated 1-3 stars during sessions with the given sleep quality.

        Input:
        sleep_quality[str] = the user's sleep quality ("good", "average", "poor")

        Output:
        negative_seeds[list] = a list of song URIs with ratings < 4 for the given sleep quality
        '''
        try:
            negative_seeds = self.db_service.get_negative_seeds(self.username, sleep_quality)
            logger.info(f"Retrieved {len(negative_seeds)} negative seeds for {sleep_quality} sleep")
            return negative_seeds
        except Exception as e:
            logger.error(f"Failed to retrieve negative seeds for {sleep_quality}: {str(e)}")
            return []


    def recommendSongs(self, sleep_quality: str, playlist_id: str) -> list:
        '''
        Get recommended songs for the user based on their sleep quality.
        Uses positive seeds (highly-rated songs) and negative seeds (poorly-rated songs)
        to guide Spotify recommendations. Seeds are drawn from the user's historical ratings.

        Input:
        sleep_quality[str] = the user's sleep quality ("good", "average", "poor")
        playlist_id[str] = the Spotify playlist ID to use for supplementing seeds if needed

        Output:
        recommended_uris[list] = list of Spotify track URIs for new recommendations
        '''
        try:
            positive_seeds = self.getPositiveSeeds(sleep_quality)
            negative_seeds = self.getNegativeSeeds(sleep_quality)

            # If we don't have enough positive seeds, grab from existing playlist to fill in gaps
            if len(positive_seeds) < 5:
                try:
                    if playlist_id:
                        previous_songs = self.music_api.get_playlist_item(playlist_id=playlist_id, limit=10)
                        previous_uris = [song["uri"] for song in previous_songs
                                        if song["uri"] not in positive_seeds and song["uri"] not in negative_seeds]
                        positive_seeds.extend(previous_uris)
                        logger.info(f"Supplemented seeds with {len(previous_uris)} tracks from existing playlist")
                except Exception as e:
                    logger.warning(f"Could not supplement seeds from existing playlist: {str(e)}")

            # Ensure we have at least some seeds for recommendation
            if not positive_seeds:
                logger.warning(f"No positive seeds available for {sleep_quality} sleep, using generic recommendations")
                # Fallback: use user's top tracks as seeds if no rated songs exist
                top_tracks = self.music_api.get_user_top_tracks(time_range="short_term", limit=5)
                positive_seeds = [track["uri"] for track in top_tracks]

            # Get recommendations from ReccoBeats
            new_recommendations = self.music_api.get_recommendations(
                size=20,
                seeds=positive_seeds[:5],  # Recco API limit: max 5 seeds (need to double check, docs not clear)
                negative_seeds=negative_seeds[:5] if negative_seeds else None
            )

            recommended_uris = [song["uri"] for song in new_recommendations]
            logger.info(f"Generated {len(recommended_uris)} recommendations for {sleep_quality} sleep")
            return recommended_uris

        except Exception as e:
            logger.error(f"Failed to generate recommendations for {sleep_quality}: {str(e)}")
            return []

    def addSongsToPlaylist(self, playlist_id: str, song_ids: list) -> None:
        '''
        Add songs to the user's playlist.

        Input:
        playlist_id[str] = the Spotify playlist ID to add songs to
        song_ids[list] = a list of Spotify song URIs to add to the playlist
        '''
        self.music_api.update_playlist_items(playlist_id=playlist_id, uris=song_ids)

    def removeSongsFromPlaylist(self, playlist_id: str, song_ids: list) -> None:
        '''
        Remove songs from the user's playlist.
        Used for weekly playlist replacement strategy to clear old recommendations.

        Input:
        playlist_id[str] = the Spotify playlist ID to remove songs from
        song_ids[list] = a list of Spotify song URIs to remove from the playlist
        '''
        try:
            if not song_ids:
                logger.info(f"No songs to remove from playlist {playlist_id}")
                return

            # Clear playlist, in batches to avoid hitting API limits
            batch_size = 100
            for i in range(0, len(song_ids), batch_size):
                batch = song_ids[i:i + batch_size]
                self.music_api.remove_playlist_item(playlist_id=playlist_id, uris=batch)
                logger.info(f"Removed {len(batch)} tracks from playlist {playlist_id}")

        except Exception as e:
            logger.error(f"Failed to remove songs from playlist {playlist_id}: {str(e)}")
