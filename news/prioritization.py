# -*- coding: utf-8 -*-
"""
Prioritization of deduplicated news articles.

Selects the top-N most valuable and diverse stories from a list of
deduplicated Article objects produced by :mod:`deduplication`.

Strategy
--------
1. **Quality score** – each article receives a composite score that rewards
   recency, a substantive description, and a meaningful (non-stub) title.

2. **Diversity-aware greedy selection (MMR)** – articles are chosen one at a
   time using Maximal Marginal Relevance: at each step the article that
   maximises ``(1 - λ) * quality - λ * max_topic_similarity_to_selected``
   is picked.  This balances picking the best individual stories while
   avoiding clustering on a single topic.

3. **Source cap** – at most *max_per_source* articles from the same outlet
   are included, preventing any one feed from dominating the result.

Typical pipeline::

    from deduplication import deduplicate_feeds
    from prioritization import select_top_stories

    articles = deduplicate_feeds(xml_sources)
    top5 = select_top_stories(articles, n=5)
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from deduplication import Article, _field_similarity, _parse_date, _tokenize, deduplicate_feeds


# ---------------------------------------------------------------------------
# Quality scoring helpers
# ---------------------------------------------------------------------------

def _recency_score(
    pub_date: Optional[datetime],
    now: datetime,
    max_age_hours: float = 72.0,
) -> float:
    """Return a [0, 1] recency score; 1.0 = just published, 0.0 = max_age_hours old or older."""
    if pub_date is None:
        return 0.0  # unknown date: no recency credit

    # Ensure both are timezone-aware for subtraction.
    if pub_date.tzinfo is None:
        pub_date = pub_date.replace(tzinfo=timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)

    age_hours = max(0.0, (now - pub_date).total_seconds() / 3600)
    return max(0.0, 1.0 - age_hours / max_age_hours)


def _description_score(desc_tokens: frozenset, target_tokens: int = 40) -> float:
    """Return a [0, 1] score based on description richness; saturates at *target_tokens*."""
    return min(1.0, len(desc_tokens) / target_tokens)


def _title_quality_score(
    title_tokens: frozenset,
    min_tokens: int = 3,
    target_tokens: int = 8,
) -> float:
    """Return a [0, 1] score that penalises stub titles (e.g. two-word section headers).

    Scoring is monotonically non-decreasing: each additional token can only
    raise or maintain the score, never lower it.  Titles below *min_tokens*
    receive a proportional stub penalty on top of the base linear ramp, so
    that the two regimes meet continuously at ``n == min_tokens``.
    """
    n = len(title_tokens)
    base = min(1.0, n / target_tokens)
    if n < min_tokens:
        # Apply a proportional penalty for stub titles; the formula is
        # continuous at n == min_tokens (penalty factor becomes 1.0 there).
        base *= n / min_tokens
    return base


def _article_quality_score(
    article: Article,
    now: datetime,
    recency_weight: float = 0.40,
    description_weight: float = 0.35,
    title_weight: float = 0.25,
    max_age_hours: float = 72.0,
) -> float:
    """Return a composite quality score in [0, 1] for a single article.

    The score is a weighted average of:

    * **Recency** (40 %): how recently the article was published relative to
      *max_age_hours*.
    * **Description richness** (35 %): whether the article has a substantial
      description (saturates at ~40 meaningful tokens).
    * **Title quality** (25 %): whether the title has enough tokens to be
      informative (penalises two-word stub headlines like "Trump's War").

    Args:
        article:            The article to score.
        now:                Reference time for recency calculation.
        recency_weight:     Weight for recency component (default 0.40).
        description_weight: Weight for description richness (default 0.35).
        title_weight:       Weight for title quality (default 0.25).
        max_age_hours:      Articles older than this are scored 0 for recency.

    Returns:
        Float in [0, 1].
    """
    title_tokens = _tokenize(article.title)
    desc_tokens  = _tokenize(article.description)
    pub_date     = _parse_date(article.pub_date)

    recency  = _recency_score(pub_date, now, max_age_hours)
    desc_q   = _description_score(desc_tokens)
    title_q  = _title_quality_score(title_tokens)

    return (
        recency_weight     * recency +
        description_weight * desc_q  +
        title_weight       * title_q
    )


# ---------------------------------------------------------------------------
# Topic similarity
# ---------------------------------------------------------------------------

def _topic_similarity(a: Article, b: Article) -> float:
    """Title-token similarity between two articles, used to measure topic overlap."""
    return _field_similarity(_tokenize(a.title), _tokenize(b.title))


# ---------------------------------------------------------------------------
# Diversity-aware top-N selection (MMR)
# ---------------------------------------------------------------------------

def select_top_stories(
    articles: list[Article],
    n: int = 5,
    diversity_weight: float = 0.40,
    max_per_source: int = 2,
    max_age_hours: float = 72.0,
) -> list[Article]:
    """Select the top-*n* stories balancing quality and variety.

    Uses **Maximal Marginal Relevance (MMR)**: at each step the unselected
    article that maximises the MMR score is chosen::

        MMR = (1 - diversity_weight) * quality_score
              - diversity_weight     * max_topic_similarity_to_selected

    A source cap (*max_per_source*) prevents any single feed from taking
    more than that many slots in the final list.

    Args:
        articles:         Deduplicated list of Article objects.
        n:                Number of top stories to select.
        diversity_weight: Blend between quality (0.0) and diversity (1.0).
                          Default 0.4 gives a modest diversity boost while
                          still prioritising quality.
        max_per_source:   Maximum articles from any single source outlet.
        max_age_hours:    Age cap used when computing recency scores.

    Returns:
        List of up to *n* Article objects ordered by selection rank (best first).
    """
    if not articles:
        return []

    now = datetime.now(tz=timezone.utc)

    # Pre-compute quality scores and title tokens for all candidates once,
    # avoiding repeated _tokenize() calls inside the O(n²·k) inner loop.
    quality: list[float] = [
        _article_quality_score(a, now, max_age_hours=max_age_hours)
        for a in articles
    ]
    title_tokens: list[frozenset] = [_tokenize(a.title) for a in articles]

    selected: list[Article] = []
    selected_indices: set[int] = set()
    source_counts: dict[str, int] = {}

    for _ in range(min(n, len(articles))):
        best_idx: Optional[int] = None
        best_mmr: float = float("-inf")

        for i, article in enumerate(articles):
            if i in selected_indices:
                continue
            # Enforce per-source cap.
            if source_counts.get(article.source, 0) >= max_per_source:
                continue

            q = quality[i]

            # Penalise by similarity to the most similar already-chosen article.
            # Uses pre-computed token sets to avoid O(n·k) re-tokenization.
            if selected:
                max_sim = max(
                    _field_similarity(title_tokens[i], title_tokens[j])
                    for j in selected_indices
                )
            else:
                max_sim = 0.0

            mmr = (1.0 - diversity_weight) * q - diversity_weight * max_sim

            if mmr > best_mmr:
                best_mmr = mmr
                best_idx = i

        if best_idx is None:
            break  # all remaining candidates are source-capped or exhausted

        chosen = articles[best_idx]
        selected.append(chosen)
        selected_indices.add(best_idx)
        source_counts[chosen.source] = source_counts.get(chosen.source, 0) + 1

    return selected


# ---------------------------------------------------------------------------
# Convenience pipeline: feeds → dedup → prioritise
# ---------------------------------------------------------------------------

def get_top_stories(
    xml_sources: list[str],
    n: int = 5,
    score_threshold: float = 0.35,
    date_window_hours: float = 48.0,
    diversity_weight: float = 0.40,
    max_per_source: int = 2,
    max_age_hours: float = 72.0,
) -> list[Article]:
    """Parse RSS feeds, deduplicate, and return the top-*n* prioritised stories.

    This is a convenience wrapper that chains :func:`~deduplication.deduplicate_feeds`
    with :func:`select_top_stories`.

    Args:
        xml_sources:       List of file paths or raw XML strings.
        n:                 Number of top stories to return.
        score_threshold:   Deduplication similarity threshold (see
                           :func:`~deduplication.deduplicate`).
        date_window_hours: Deduplication date window (see
                           :func:`~deduplication.deduplicate`).
        diversity_weight:  MMR diversity blend (see :func:`select_top_stories`).
        max_per_source:    Max articles per source outlet in the result.
        max_age_hours:     Age cap for recency scoring.

    Returns:
        List of up to *n* Article objects.
    """
    articles = deduplicate_feeds(
        xml_sources,
        score_threshold=score_threshold,
        date_window_hours=date_window_hours,
    )
    return select_top_stories(
        articles,
        n=n,
        diversity_weight=diversity_weight,
        max_per_source=max_per_source,
        max_age_hours=max_age_hours,
    )
