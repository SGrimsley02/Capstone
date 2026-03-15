# -*- coding: utf-8 -*-
"""Tests for prioritization.py."""

import unittest
from datetime import datetime, timedelta, timezone

from deduplication import Article
from prioritization import (
    _article_quality_score,
    _description_score,
    _recency_score,
    _title_quality_score,
    _topic_similarity,
    select_top_stories,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _article(
    title: str,
    url: str = "",
    source: str = "Feed",
    description: str = "",
    pub_date: str = "",
    guid: str = "",
) -> Article:
    return Article(
        title=title,
        url=url,
        guid=guid or url,
        source=source,
        description=description,
        pub_date=pub_date,
    )


# Fixed reference "now" used across tests so results are deterministic.
_NOW = datetime(2026, 3, 9, 12, 0, 0, tzinfo=timezone.utc)

def _rfc2822(dt: datetime) -> str:
    """Convert a UTC datetime to an RFC 2822 string for pub_date fields."""
    return dt.strftime("%a, %d %b %Y %H:%M:%S +0000")


# ---------------------------------------------------------------------------
# _recency_score
# ---------------------------------------------------------------------------

class TestRecencyScore(unittest.TestCase):

    def test_just_published_returns_one(self):
        self.assertAlmostEqual(_recency_score(_NOW, _NOW), 1.0)

    def test_none_date_returns_zero(self):
        self.assertEqual(_recency_score(None, _NOW), 0.0)

    def test_at_max_age_returns_zero(self):
        pub = _NOW - timedelta(hours=72)
        self.assertAlmostEqual(_recency_score(pub, _NOW), 0.0)

    def test_older_than_max_age_clamped_to_zero(self):
        pub = _NOW - timedelta(hours=100)
        self.assertEqual(_recency_score(pub, _NOW), 0.0)

    def test_halfway_returns_half(self):
        pub = _NOW - timedelta(hours=36)
        self.assertAlmostEqual(_recency_score(pub, _NOW), 0.5)

    def test_naive_pub_date_treated_as_utc(self):
        # A naive datetime equal to _NOW should give recency 1.0.
        naive = datetime(2026, 3, 9, 12, 0, 0)  # no tzinfo
        self.assertAlmostEqual(_recency_score(naive, _NOW), 1.0)

    def test_naive_now_treated_as_utc(self):
        pub = datetime(2026, 3, 9, 12, 0, 0)
        naive_now = datetime(2026, 3, 9, 12, 0, 0)
        self.assertAlmostEqual(_recency_score(pub, naive_now), 1.0)

    def test_future_pub_date_clamped_to_one(self):
        # Pre-scheduled articles are as-fresh as possible.
        pub = _NOW + timedelta(hours=5)
        self.assertAlmostEqual(_recency_score(pub, _NOW), 1.0)

    def test_custom_max_age(self):
        pub = _NOW - timedelta(hours=12)
        score = _recency_score(pub, _NOW, max_age_hours=24.0)
        self.assertAlmostEqual(score, 0.5)

    def test_score_in_unit_interval(self):
        for hours_ago in [0, 10, 36, 72, 100]:
            pub = _NOW - timedelta(hours=hours_ago)
            s = _recency_score(pub, _NOW)
            self.assertGreaterEqual(s, 0.0)
            self.assertLessEqual(s, 1.0)


# ---------------------------------------------------------------------------
# _description_score
# ---------------------------------------------------------------------------

class TestDescriptionScore(unittest.TestCase):

    def test_empty_tokens_returns_zero(self):
        self.assertEqual(_description_score(frozenset()), 0.0)

    def test_at_target_returns_one(self):
        tokens = frozenset(f"word{i}" for i in range(40))
        self.assertAlmostEqual(_description_score(tokens), 1.0)

    def test_above_target_clamped_to_one(self):
        tokens = frozenset(f"word{i}" for i in range(100))
        self.assertAlmostEqual(_description_score(tokens), 1.0)

    def test_half_target_returns_half(self):
        tokens = frozenset(f"word{i}" for i in range(20))
        self.assertAlmostEqual(_description_score(tokens), 0.5)

    def test_custom_target(self):
        tokens = frozenset(f"word{i}" for i in range(10))
        self.assertAlmostEqual(_description_score(tokens, target_tokens=20), 0.5)

    def test_score_in_unit_interval(self):
        for n in [0, 5, 20, 40, 80]:
            s = _description_score(frozenset(f"w{i}" for i in range(n)))
            self.assertGreaterEqual(s, 0.0)
            self.assertLessEqual(s, 1.0)


# ---------------------------------------------------------------------------
# _title_quality_score
# ---------------------------------------------------------------------------

class TestTitleQualityScore(unittest.TestCase):

    def test_zero_tokens_returns_zero(self):
        self.assertEqual(_title_quality_score(frozenset()), 0.0)

    def test_at_target_returns_one(self):
        tokens = frozenset(f"word{i}" for i in range(8))
        self.assertAlmostEqual(_title_quality_score(tokens), 1.0)

    def test_above_target_clamped_to_one(self):
        tokens = frozenset(f"word{i}" for i in range(20))
        self.assertAlmostEqual(_title_quality_score(tokens), 1.0)

    def test_stub_title_penalised(self):
        # A 2-token title should score strictly less than a 3-token title.
        two = frozenset(["trump", "war"])
        three = frozenset(["trump", "declares", "war"])
        self.assertLess(_title_quality_score(two), _title_quality_score(three))

    def test_score_is_monotonically_non_decreasing(self):
        """Adding tokens must never lower the score (regression test for the
        discontinuity bug where n=3 scored lower than n=2)."""
        scores = [
            _title_quality_score(frozenset(f"word{i}" for i in range(n)))
            for n in range(12)
        ]
        for i in range(1, len(scores)):
            self.assertGreaterEqual(
                scores[i], scores[i - 1],
                msg=(
                    f"Score decreased going from {i-1} to {i} tokens: "
                    f"{scores[i-1]:.4f} → {scores[i]:.4f}"
                ),
            )

    def test_min_token_boundary_no_regression(self):
        """Score at exactly min_tokens must be >= score at min_tokens-1."""
        below = frozenset(["word0", "word1"])          # n=2
        at    = frozenset(["word0", "word1", "word2"]) # n=3
        self.assertLessEqual(_title_quality_score(below), _title_quality_score(at))

    def test_score_in_unit_interval(self):
        for n in range(12):
            s = _title_quality_score(frozenset(f"w{i}" for i in range(n)))
            self.assertGreaterEqual(s, 0.0)
            self.assertLessEqual(s, 1.0)


# ---------------------------------------------------------------------------
# _article_quality_score
# ---------------------------------------------------------------------------

class TestArticleQualityScore(unittest.TestCase):

    def _fresh_rich_article(self, source: str = "Feed") -> Article:
        """A recently-published, richly-described, well-titled article."""
        desc = " ".join(f"keyword{i}" for i in range(40))
        return _article(
            "Breaking News Big Story Happening Today Now",
            url="https://a.com/fresh",
            source=source,
            description=desc,
            pub_date=_rfc2822(_NOW),
        )

    def test_high_quality_article_scores_high(self):
        score = _article_quality_score(self._fresh_rich_article(), _NOW)
        self.assertGreater(score, 0.7)

    def test_old_article_scores_lower_than_fresh(self):
        old_pub = _rfc2822(_NOW - timedelta(hours=70))
        desc = " ".join(f"word{i}" for i in range(40))
        old   = _article("Old News Story Breaking Today Here", pub_date=old_pub, description=desc)
        fresh = _article("Old News Story Breaking Today Here", pub_date=_rfc2822(_NOW), description=desc)
        self.assertLess(
            _article_quality_score(old, _NOW),
            _article_quality_score(fresh, _NOW),
        )

    def test_no_description_scores_lower_than_with_description(self):
        pub = _rfc2822(_NOW)
        with_desc = _article("Good Breaking News Title Here Today", pub_date=pub,
                              description="detailed news description content " * 5)
        no_desc   = _article("Good Breaking News Title Here Today", pub_date=pub)
        self.assertLess(
            _article_quality_score(no_desc, _NOW),
            _article_quality_score(with_desc, _NOW),
        )

    def test_stub_title_scores_lower_than_rich_title(self):
        pub = _rfc2822(_NOW)
        stub = _article("Trump's War", pub_date=pub)
        rich = _article("Trump Declares New Trade War Against China Europe", pub_date=pub)
        self.assertLess(
            _article_quality_score(stub, _NOW),
            _article_quality_score(rich, _NOW),
        )

    def test_score_in_unit_interval_all_combinations(self):
        cases = [
            _article("A", pub_date=_rfc2822(_NOW)),
            _article("A Good Descriptive Title With Many Words", pub_date=_rfc2822(_NOW),
                     description=" ".join(f"w{i}" for i in range(40))),
            _article("No Date No Desc"),
            _article("Old Article", pub_date=_rfc2822(_NOW - timedelta(hours=100))),
        ]
        for a in cases:
            s = _article_quality_score(a, _NOW)
            self.assertGreaterEqual(s, 0.0, msg=f"Score < 0 for {a.title!r}")
            self.assertLessEqual(s, 1.0,    msg=f"Score > 1 for {a.title!r}")

    def test_missing_pub_date_gives_zero_recency(self):
        # Without a date the recency component contributes 0, so the score is
        # bounded by description_weight + title_weight (= 0.60 by default).
        a = _article("Good Long Informative Title Words Here")
        score = _article_quality_score(a, _NOW)
        self.assertLessEqual(score, 0.61)  # small float buffer


# ---------------------------------------------------------------------------
# _topic_similarity
# ---------------------------------------------------------------------------

class TestTopicSimilarity(unittest.TestCase):

    def test_identical_titles_return_one(self):
        a = _article("Breaking News Earthquake Destroys City")
        b = _article("Breaking News Earthquake Destroys City")
        self.assertAlmostEqual(_topic_similarity(a, b), 1.0)

    def test_completely_different_topics_return_low(self):
        a = _article("Earthquake Destroys Downtown Buildings")
        b = _article("Olympic Swimming Champion Wins Gold Medal")
        self.assertLess(_topic_similarity(a, b), 0.2)

    def test_highly_overlapping_titles_return_high(self):
        a = _article("Massive Earthquake Destroys Downtown Tokyo Buildings")
        b = _article("Earthquake Destroys Tokyo Downtown Buildings")
        self.assertGreater(_topic_similarity(a, b), 0.7)

    def test_symmetric(self):
        a = _article("Senate Passes New Healthcare Reform Bill")
        b = _article("Congress Approves Major Climate Legislation")
        self.assertAlmostEqual(_topic_similarity(a, b), _topic_similarity(b, a))

    def test_empty_titles_return_one(self):
        # Two articles with no meaningful tokens are treated as identical.
        a = _article("the")
        b = _article("a an")
        self.assertAlmostEqual(_topic_similarity(a, b), 1.0)


# ---------------------------------------------------------------------------
# select_top_stories
# ---------------------------------------------------------------------------

class TestSelectTopStoriesEdgeCases(unittest.TestCase):

    def test_empty_input_returns_empty(self):
        self.assertEqual(select_top_stories([]), [])

    def test_n_zero_returns_empty(self):
        arts = [_article("Some Story", url="https://a.com/1")]
        self.assertEqual(select_top_stories(arts, n=0), [])

    def test_fewer_articles_than_n_returns_all(self):
        arts = [
            _article(f"Unique Topic Story {i} Event", url=f"https://a.com/{i}", source=f"S{i}")
            for i in range(3)
        ]
        result = select_top_stories(arts, n=10)
        self.assertEqual(len(result), 3)

    def test_single_article_returned(self):
        arts = [_article("Only Story Here", url="https://a.com/1")]
        result = select_top_stories(arts, n=5)
        self.assertEqual(len(result), 1)

    def test_source_cap_zero_returns_empty(self):
        arts = [_article("Story", url="https://a.com/1", source="Feed")]
        self.assertEqual(select_top_stories(arts, n=5, max_per_source=0), [])

    def test_all_same_source_capped(self):
        arts = [
            _article(f"Different Unique Topic Story {i}", url=f"https://cnn.com/{i}",
                     source="CNN")
            for i in range(8)
        ]
        result = select_top_stories(arts, n=5, max_per_source=2)
        self.assertLessEqual(len(result), 2)


class TestSelectTopStoriesQuality(unittest.TestCase):

    def test_returns_at_most_n_articles(self):
        arts = [
            _article(f"Unique Story Topic {i} Event News", url=f"https://example.com/{i}",
                     source=f"Source{i}")
            for i in range(10)
        ]
        result = select_top_stories(arts, n=5)
        self.assertLessEqual(len(result), 5)

    def test_best_quality_article_selected_first_no_diversity(self):
        """With diversity_weight=0, the highest-quality article is ranked first."""
        desc = " ".join(f"word{i}" for i in range(40))
        arts = [
            _article("Old Vague", url="https://a.com/old", source="A",
                     pub_date=_rfc2822(_NOW - timedelta(hours=70))),
            _article("Breaking Fresh Important News Story Today",
                     url="https://b.com/fresh", source="B",
                     pub_date=_rfc2822(_NOW), description=desc),
        ]
        result = select_top_stories(arts, n=1, diversity_weight=0.0)
        self.assertEqual(result[0].url, "https://b.com/fresh")

    def test_result_ordered_best_first(self):
        pub = _rfc2822(_NOW)
        desc = " ".join(f"word{i}" for i in range(40))
        arts = [
            _article("Vague", url="https://b.com/1", source="B"),
            _article("Breaking News Important Long Informative Story Today",
                     url="https://a.com/2", source="A",
                     description=desc, pub_date=pub),
        ]
        result = select_top_stories(arts, n=2, diversity_weight=0.0)
        self.assertEqual(result[0].url, "https://a.com/2")

    def test_all_results_are_unique_articles(self):
        arts = [
            _article(f"Story About Different Topic {i}", url=f"https://a.com/{i}",
                     source=f"S{i}")
            for i in range(10)
        ]
        result = select_top_stories(arts, n=5)
        urls = [a.url for a in result]
        self.assertEqual(len(urls), len(set(urls)))


class TestSelectTopStoriesSourceCap(unittest.TestCase):

    def test_source_cap_respected(self):
        pub = _rfc2822(_NOW)
        desc = " ".join(f"word{i}" for i in range(40))
        arts = [
            _article(f"Unique Different Article {i} Topic Events",
                     url=f"https://nyt.com/{i}", source="NYT",
                     pub_date=pub, description=desc)
            for i in range(6)
        ] + [
            _article("Completely Different Climate Change Science",
                     url="https://bbc.com/1", source="BBC",
                     pub_date=pub, description=desc),
        ]
        result = select_top_stories(arts, n=5, max_per_source=2)
        nyt_count = sum(1 for a in result if a.source == "NYT")
        self.assertLessEqual(nyt_count, 2)

    def test_source_cap_one_per_outlet(self):
        pub = _rfc2822(_NOW)
        desc = " ".join(f"word{i}" for i in range(40))
        arts = [
            _article(f"Different Story Topic Event {i}",
                     url=f"https://feed.com/{i}", source="SingleFeed",
                     pub_date=pub, description=desc)
            for i in range(5)
        ]
        result = select_top_stories(arts, n=5, max_per_source=1)
        self.assertLessEqual(len(result), 1)

    def test_multiple_sources_each_capped(self):
        pub = _rfc2822(_NOW)
        arts = (
            [_article(f"CNN Story {i} Topic", url=f"https://cnn.com/{i}", source="CNN",
                      pub_date=pub) for i in range(4)]
            + [_article(f"BBC Story {i} Topic", url=f"https://bbc.com/{i}", source="BBC",
                        pub_date=pub) for i in range(4)]
        )
        result = select_top_stories(arts, n=6, max_per_source=2)
        cnn_count = sum(1 for a in result if a.source == "CNN")
        bbc_count = sum(1 for a in result if a.source == "BBC")
        self.assertLessEqual(cnn_count, 2)
        self.assertLessEqual(bbc_count, 2)


class TestSelectTopStoriesDiversity(unittest.TestCase):

    def test_high_diversity_weight_avoids_topic_clustering(self):
        """High diversity_weight should prefer a different-topic article over a
        near-duplicate of the already-selected article."""
        pub = _rfc2822(_NOW)
        desc = " ".join(f"word{i}" for i in range(40))

        eq1  = _article("Massive Earthquake Destroys City Downtown Buildings",
                         url="https://a.com/eq1", source="A", pub_date=pub, description=desc)
        eq2  = _article("Strong Earthquake Hits City Downtown Buildings Destroyed",
                         url="https://b.com/eq2", source="B", pub_date=pub, description=desc)
        tech = _article("Tech Company Launches Revolutionary New Smartphone Product",
                        url="https://c.com/tech", source="C", pub_date=pub, description=desc)

        result = select_top_stories([eq1, eq2, tech], n=2,
                                    diversity_weight=0.95, max_per_source=2)
        selected_urls = {a.url for a in result}
        # The tech article covers a completely different topic — it should be
        # preferred as the second pick over the near-duplicate earthquake article.
        self.assertIn("https://c.com/tech", selected_urls)

    def test_zero_diversity_weight_pure_quality_selection(self):
        """diversity_weight=0.0 should behave like pure quality ranking."""
        pub = _rfc2822(_NOW)
        desc = " ".join(f"word{i}" for i in range(40))

        best = _article("Breaking Fresh Important Long Title Story News",
                        url="https://best.com/1", source="A", pub_date=pub, description=desc)
        arts = [
            _article("Vague Short", url="https://z.com/1", source="B"),
            best,
            _article("Old Article", url="https://z.com/2", source="C",
                     pub_date=_rfc2822(_NOW - timedelta(hours=71))),
        ]
        result = select_top_stories(arts, n=1, diversity_weight=0.0)
        self.assertEqual(result[0].url, "https://best.com/1")


if __name__ == "__main__":
    unittest.main()
