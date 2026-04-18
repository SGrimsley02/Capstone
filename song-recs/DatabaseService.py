'''
Database service for managing song ratings and user data in DynamoDB.
Handles all persistence operations for the REMix song recommendation system.

Last updated: 4.17.26
By: Kiara
'''

import boto3
from typing import List, Dict, Optional
from decimal import Decimal
import logging

logger = logging.getLogger(__name__)


class DatabaseService:
    def __init__(self):
        '''
        Initialize the DatabaseService with DynamoDB connection.

        Input:
        table_name[str] = name of the DynamoDB table for ratings
        region[str] = AWS region for DynamoDB
        '''
        self.dynamodb = boto3.resource('dynamodb', region_name='us-east-2')
        self.ratings_table = self.dynamodb.Table('song-ratings')
        self.users_table = self.dynamodb.Table('users')

    # ===============================
    # Rating Management Functions
    # ===============================

    def get_ratings_by_sleep_quality(self, username: str, sleep_quality: str,
                                     min_rating: Optional[int] = None) -> List[Dict]:
        '''
        Get all ratings for a user filtered by sleep quality and optional minimum rating.

        Input:
        username[str] = REMix username
        sleep_quality[str] = sleep quality to filter by ("good", "average", "poor")
        min_rating[int] = optional minimum rating threshold (1-5)

        Output:
        ratings[List[Dict]] = list of rating records with track_uri and rating
        '''
        try:
            expression_values = {
                ':username': username,
                ':quality': sleep_quality,
            }
            filter_expression = 'sleep_quality = :quality'
            if min_rating is not None:
                filter_expression += ' AND rating >= :min_rating'
                expression_values[':min_rating'] = Decimal(str(min_rating))

            response = self.ratings_table.query(
                KeyConditionExpression='username = :username',
                FilterExpression=filter_expression,
                ExpressionAttributeValues=expression_values
            )

            ratings = response.get('Items', [])
            logger.info(f"Retrieved {len(ratings)} ratings for {username} ({sleep_quality})")
            return ratings
        except Exception as e:
            logger.error(f"Failed to query ratings for {username}: {str(e)}")
            return []

    def get_positive_seeds(self, username: str, sleep_quality: str,
                          threshold: int = 4) -> List[str]:
        '''
        Get track URIs that the user rated highly for a specific sleep quality.

        Input:
        username[str] = REMix username
        sleep_quality[str] = sleep quality category
        threshold[int] = minimum rating to consider as "positive" (default: 4)

        Output:
        track_uris[List[str]] = list of Spotify track URIs
        '''
        ratings = self.get_ratings_by_sleep_quality(username, sleep_quality, min_rating=threshold)
        return [item['track_uri'] for item in ratings]

    def get_negative_seeds(self, username: str, sleep_quality: str,
                          threshold: int = 4) -> List[str]:
        '''
        Get track URIs that the user rated poorly for a specific sleep quality.

        Input:
        username[str] = REMix username
        sleep_quality[str] = sleep quality category
        threshold[int] = maximum rating to consider as "negative" (default: 4)

        Output:
        track_uris[List[str]] = list of Spotify track URIs with ratings < threshold
        '''
        try:
            response = self.ratings_table.query(
                KeyConditionExpression='username = :username',
                FilterExpression='sleep_quality = :quality AND rating < :threshold',
                ExpressionAttributeValues={
                    ':username': username,
                    ':quality': sleep_quality,
                    ':threshold': Decimal(str(threshold))
                }
            )

            ratings = response.get('Items', [])
            track_uris = [item['track_uri'] for item in ratings]
            logger.info(f"Retrieved {len(track_uris)} negative seeds for {username} ({sleep_quality})")
            return track_uris
        except Exception as e:
            logger.error(f"Failed to query negative seeds for {username}: {str(e)}")
            return []

    # ===============================
    # Playlist Management Functions
    # ===============================

    def store_playlist_mapping(self, username: str, sleep_quality: str,
                              playlist_id: str) -> bool:
        '''
        Store the mapping between a user, sleep quality, and their Spotify playlist ID.
        Updates the user record in the users table.

        Input:
        username[str] = REMix username
        sleep_quality[str] = sleep quality ("good", "average", "poor")
        playlist_id[str] = Spotify playlist ID

        Output:
        success[bool] = whether the operation succeeded
        '''
        try:
            playlist_key = f"playlist_{sleep_quality}_sleep"

            self.users_table.update_item(
                Key={'username': username},
                UpdateExpression=f'SET {playlist_key} = :playlist_id',
                ExpressionAttributeValues={
                    ':playlist_id': playlist_id
                }
            )
            logger.info(f"Stored playlist mapping for {username}: {sleep_quality} -> {playlist_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to store playlist mapping for {username}: {str(e)}")
            return False

    def get_playlist_id(self, username: str, sleep_quality: str) -> Optional[str]:
        '''
        Retrieve the Spotify playlist ID for a user's specific sleep quality.

        Input:
        username[str] = REMix username
        sleep_quality[str] = sleep quality ("good", "average", "poor")

        Output:
        playlist_id[Optional[str]] = Spotify playlist ID or None if not found
        '''
        try:
            response = self.users_table.get_item(Key={'username': username})
            user = response.get('Item', {})
            playlist_key = f"playlist_{sleep_quality}_sleep"
            playlist_id = user.get(playlist_key)

            if not playlist_id:
                logger.warning(f"Playlist not found for {username} ({sleep_quality})")
                return None

            return playlist_id
        except Exception as e:
            logger.error(f"Failed to retrieve playlist for {username}: {str(e)}")
            return None

    def get_all_playlist_ids(self, username: str) -> Dict[str, str]:
        '''
        Retrieve all playlist IDs for a user across all sleep qualities.

        Input:
        username[str] = REMix username

        Output:
        playlists[Dict[str, str]] = mapping of sleep_quality -> playlist_id
        '''
        try:
            response = self.users_table.get_item(Key={'username': username})
            user = response.get('Item', {})

            playlists = {
                'good': user.get('playlist_good_sleep'),
                'average': user.get('playlist_average_sleep'),
                # Backward compatibility for older field naming.
                'poor': user.get('playlist_poor_sleep') or user.get('playlist_bad_sleep')
            }

            return {k: v for k, v in playlists.items() if v}
        except Exception as e:
            logger.error(f"Failed to retrieve all playlists for {username}: {str(e)}")
            return {}
