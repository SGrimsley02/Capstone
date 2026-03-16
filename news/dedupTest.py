"""Tests for the deduplicate function in deduplication.py."""

import unittest
from deduplication import Article, deduplicate


def _article(
    title: str,
    url: str = "",
    guid: str = "",
    source: str = "Feed",
    description: str = "",
    pub_date: str = "",
) -> Article:
    return Article(
        title=title,
        url=url,
        guid=guid or url,
        source=source,
        description=description,
        pub_date=pub_date,
    )


# Convenience RFC 2822 dates one hour apart, within a single news cycle.
_DATE_A = "Mon, 09 Mar 2026 08:00:00 +0000"
_DATE_B = "Mon, 09 Mar 2026 09:00:00 +0000"
# A date well outside the default 48-hour window.
_DATE_OLD = "Thu, 05 Mar 2026 08:00:00 +0000"


class TestDeduplicateExactUrl(unittest.TestCase):
    """Articles with identical normalised URLs are deduplicated."""

    def test_same_url_kept_once(self):
        arts = [
            _article("Story A", url="https://example.com/story-a"),
            _article("Story A (copy)", url="https://example.com/story-a"),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].title, "Story A")

    def test_url_trailing_slash_normalised(self):
        arts = [
            _article("Story B", url="https://example.com/story-b/"),
            _article("Story B again", url="https://example.com/story-b"),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_url_query_string_stripped(self):
        arts = [
            _article("Story C", url="https://example.com/story-c?ref=rss"),
            _article("Story C mirror", url="https://example.com/story-c"),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_same_guid_different_url(self):
        arts = [
            _article("Story D", url="https://site1.com/d", guid="guid-d"),
            _article("Story D syndicated", url="https://site2.com/d", guid="guid-d"),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)


class TestDeduplicateTitleSimilarity(unittest.TestCase):
    """Articles whose titles are sufficiently similar are deduplicated."""

    def test_identical_titles_kept_once(self):
        arts = [
            _article("Breaking: Earthquake Hits City", url="https://a.com/1", source="Feed A",
                     pub_date=_DATE_A),
            _article("Breaking: Earthquake Hits City", url="https://b.com/1", source="Feed B",
                     pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_cross_source_similar_titles_deduplicated(self):
        # High-overlap rewrite of the same story — clear cross-source duplicate.
        arts = [
            _article("Earthquake Destroys Downtown Buildings in Tokyo",
                     url="https://nyt.com/quake", source="NYT", pub_date=_DATE_A),
            _article("Powerful Earthquake Destroys Tokyo Downtown Buildings",
                     url="https://npr.org/quake", source="NPR", pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_different_titles_above_threshold_deduplicated(self):
        # Token overlap, different word order, some stop words — still the same story.
        arts = [
            _article("City Council Approves New Park Budget", url="https://a.com/park",
                     source="A", pub_date=_DATE_A),
            _article("Central Park Budget Passed by Local Council", url="https://b.com/news",
                     source="B", pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_clearly_different_titles_both_kept(self):
        arts = [
            _article("Tech Giant Announces New Smartphone", url="https://a.com/phone",
                     source="A", pub_date=_DATE_A),
            _article("Local Council Approves New Park Budget", url="https://b.com/park",
                     source="B", pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 2)

    def test_threshold_respected(self):
        # "Earthquake Devastates Turkish City" shares 3 of its 4 tokens with
        # "Massive Earthquake Devastates City in Turkey", giving title_sim 0.75.
        # With no descriptions, combined score equals title_sim (0.75).
        arts = [
            _article("Earthquake Devastates Turkish City",
                     url="https://a.com/quake", source="A", pub_date=_DATE_A),
            _article("Massive Earthquake Devastates City in Turkey",
                     url="https://b.com/quake", source="B", pub_date=_DATE_B),
        ]
        # Strict threshold: score (0.75) is below 0.80 → kept separate.
        self.assertEqual(len(deduplicate(arts, score_threshold=0.80)), 2)
        # Loose threshold: score (0.75) is above 0.50 → merged.
        self.assertEqual(len(deduplicate(arts, score_threshold=0.50)), 1)


class TestDeduplicateDescriptionSignal(unittest.TestCase):
    """Description similarity boosts the duplicate signal."""

    def test_matching_description_pushes_over_threshold(self):
        # Titles share only moderate overlap; matching descriptions push score over.
        desc = "Six people were killed in a US military strike on a vessel in the Pacific Ocean."
        arts = [
            _article("U.S. Strike Kills Six on Pacific Vessel",
                     url="https://nyt.com/strike", source="NYT",
                     description=desc, pub_date=_DATE_A),
            _article("Military Vessel Strike Kills Six",
                     url="https://npr.org/strike", source="NPR",
                     description=desc, pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_long_descriptions_same_story_deduplicated(self):
        # Even with different wording, the long descriptions share enough tokens to boost score.
        arts = [
            _article("Mayor Announces New Public Transit Plan", url="https://a.com/transit",
                        description="The mayor unveiled an ambitious public transit plan today, promising to expand bus and subway service across the city over the next decade.",
                        pub_date=_DATE_A),
            _article("Jane Doe's Public Transit Initiative", url="https://b.com/transit",
                        description="Today, mayor Jane Doe set forth a new public transit initiative that aims to add additional transit options throughout the city over the coming ten years.",
                        pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_mismatched_descriptions_not_enough_alone(self):
        # Same vague title, completely different descriptions — should not dedup.
        arts = [
            _article("Local Elections Results", url="https://a.com/elect",
                     description="City council race sees incumbent win by wide margin.",
                     pub_date=_DATE_A),
            _article("Local Elections Results", url="https://b.com/elect",
                     description="Presidential primary turnout breaks state record.",
                     pub_date=_DATE_B),
        ]
        # At a strict threshold these should remain distinct.
        result = deduplicate(arts, score_threshold=0.75)
        self.assertEqual(len(result), 2)


class TestDeduplicateDateWindow(unittest.TestCase):
    """Publication date proximity gates content-based deduplication."""

    def test_same_story_within_window_deduplicated(self):
        arts = [
            _article("Senate Votes on New Healthcare Bill",
                     url="https://a.com/senate", pub_date=_DATE_A,
                     description="The Senate passed sweeping healthcare reform legislation on Monday."),
            _article("Senate Passes Healthcare Reform Bill",
                     url="https://b.com/senate", pub_date=_DATE_B,
                     description="The Senate passed sweeping healthcare reform legislation Monday."),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_same_topic_outside_window_both_kept(self):
        # Same high-similarity title/desc but published 4 days apart — distinct stories.
        arts = [
            _article("Senate Votes on New Healthcare Bill",
                     url="https://a.com/senate", pub_date=_DATE_OLD,
                     description="The Senate passed a sweeping healthcare reform bill today."),
            _article("Senate Votes on New Healthcare Bill",
                     url="https://b.com/senate", pub_date=_DATE_A,
                     description="The Senate passed a sweeping healthcare reform bill today."),
        ]
        result = deduplicate(arts, date_window_hours=48.0)
        self.assertEqual(len(result), 2)

    def test_no_dates_falls_back_to_content(self):
        # Missing dates should not block deduplication — content alone decides.
        arts = [
            _article("Earthquake Strikes Northern Region",
                     url="https://a.com/eq",
                     description="A powerful quake hit the northern region causing widespread damage."),
            _article("Earthquake Strikes Northern Region",
                     url="https://b.com/eq",
                     description="A powerful quake hit the northern region causing widespread damage."),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)


class TestDeduplicateShortTitleGuard(unittest.TestCase):
    """Very short section-title headlines must not act as wildcard duplicates."""

    def test_two_token_title_does_not_over_match(self):
        # TIME-style "Trump's War" = {trump, war} — only 2 meaningful tokens.
        # Any article mentioning both words would score 1.0 via overlap
        # coefficient; the min-token guard falls back to Jaccard instead.
        arts = [
            _article("Trump's War",
                     url="https://time.com/trumpswar", source="TIME",
                     pub_date=_DATE_A),
            _article("Trump warns Iran will be hit very hard as war enters second week",
                     url="https://npr.org/trumpiran", source="NPR",
                     pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 2)

    def test_short_title_identical_to_another_still_deduped(self):
        # Two articles with the exact same short title are still duplicates.
        arts = [
            _article("Iran War", url="https://a.com/iran", source="A", pub_date=_DATE_A),
            _article("Iran War", url="https://b.com/iran", source="B", pub_date=_DATE_B),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)



    """First-seen article is always kept; duplicates following it are dropped."""

    def test_first_article_kept(self):
        arts = [
            _article("Senate Passes New Bill", url="https://a.com/bill",
                     source="Source A", pub_date=_DATE_A),
            _article("Senate Passes New Bill", url="https://b.com/bill",
                     source="Source B", pub_date=_DATE_A),
            _article("Senate Passes New Bill", url="https://c.com/bill",
                     source="Source C", pub_date=_DATE_A),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].source, "Source A")

    def test_unique_articles_preserve_order(self):
        articles = [
            _article("Economy Grows Faster Than Expected", url="https://example.com/0"),
            _article("Volcano Erupts Off Icelandic Coast", url="https://example.com/1"),
            _article("Championship Final Ends in Penalty Shootout", url="https://example.com/2"),
            _article("New Cancer Drug Approved by Regulators", url="https://example.com/3"),
            _article("Historic Bridge Reopens After Renovation", url="https://example.com/4"),
        ]
        result = deduplicate(articles)
        self.assertEqual([a.url for a in result], [a.url for a in articles])


class TestDeduplicateEdgeCases(unittest.TestCase):

    def test_empty_list(self):
        self.assertEqual(deduplicate([]), [])

    def test_single_article(self):
        arts = [_article("Only Article", url="https://example.com/only")]
        self.assertEqual(deduplicate(arts), arts)

    def test_no_url_or_guid(self):
        # Articles with empty URLs should still deduplicate on content similarity.
        arts = [
            _article("No URL Article", description="Same description text here."),
            _article("No URL Article", description="Same description text here."),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 1)

    def test_all_unique_returns_all(self):
        arts = [
            _article("Apple Reports Record Earnings", url="https://a.com/1"),
            _article("NASA Launches New Mars Probe", url="https://b.com/2"),
            _article("Olympic Games Begin in Paris", url="https://c.com/3"),
        ]
        result = deduplicate(arts)
        self.assertEqual(len(result), 3)


if __name__ == "__main__":
    unittest.main()
