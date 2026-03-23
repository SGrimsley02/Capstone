# -*- coding: utf-8 -*-
"""
Deduplication of news articles parsed from RSS feeds.

Strategy:
  1. Exact match on normalized URL/GUID -- catches identical articles republished
     across feeds (e.g. syndicated content).
  2. Combined content score (title Jaccard * 0.6 + description Jaccard * 0.4)
     above a threshold, gated by a publication-date proximity window -- catches
     the same story covered by multiple outlets under different headlines and
     URLs within the same news cycle.
"""

import html.entities
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Article:
    title: str
    url: str
    description: str = ""
    pub_date: str = ""
    source: str = ""          # feed title / channel name
    guid: str = ""


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

# Namespace map used by some feeds (NYT uses atom:link, dc:creator, ...)
_NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "dc":   "http://purl.org/dc/elements/1.1/",
    "media":"http://search.yahoo.com/mrss/",
}


# Namespace declarations injected when feeds omit them (common in RSS 2.0).
# Covers standard feed namespaces plus podcast/syndication namespaces used
# by Substack (itunes:, googleplay:) and WashingtonPost (sy:).
_IMPLICIT_NAMESPACES = {
    "atom":       "http://www.w3.org/2005/Atom",
    "dc":         "http://purl.org/dc/elements/1.1/",
    "media":      "http://search.yahoo.com/mrss/",
    "content":    "http://purl.org/rss/1.0/modules/content/",
    "itunes":     "http://www.itunes.com/dtds/podcast-1.0.dtd",
    "googleplay": "http://www.google.com/schemas/play-podcasts/1.0",
    "sy":         "http://purl.org/rss/1.0/modules/syndication/",
}


def _fix_namespaces(xml_text: str) -> str:
    """Inject missing XML namespace declarations into the root element.

    Many RSS 2.0 feeds use prefixes like ``atom:link`` or ``dc:creator``
    without declaring the corresponding namespace on the root element.
    Python's ``xml.etree.ElementTree`` is strict about this, so we patch the
    raw text before parsing.
    """
    declarations = " ".join(
        f'xmlns:{prefix}="{uri}"'
        for prefix, uri in _IMPLICIT_NAMESPACES.items()
        if f"{prefix}:" in xml_text and f'xmlns:{prefix}=' not in xml_text
    )
    if not declarations:
        return xml_text
    # Insert before the first '>' of the root element
    return xml_text.replace("<rss ", f"<rss {declarations} ", 1)


def _fix_bare_ampersands(xml_text: str) -> str:
    """Escape bare ``&`` characters that are not part of a valid XML entity.

    Some feeds include unescaped ``&`` in titles/descriptions (e.g.
    "Tables & Chairs"), which is invalid XML.  We replace only the ones that
    are not already a valid entity reference (``&amp;``, ``&lt;``, ``&#42;``
    etc.) so that we don't double-escape well-formed entities.
    """
    return re.sub(r"&(?!(?:[a-zA-Z][a-zA-Z0-9]*|#[0-9]+|#x[0-9a-fA-F]+);)", "&amp;", xml_text)


# Full mapping of HTML 4.0 named entities -> Unicode characters, built from
# stdlib so we don't maintain a hand-curated list.  XML 1.0 only defines five
# built-in entities; everything else (e.g. &nbsp; &mdash; &iacute;) must be
# replaced before passing the text to an XML parser.
_HTML_ENTITIES: dict[str, str] = {
    f"&{name};": chr(cp)
    for name, cp in html.entities.name2codepoint.items()
}
_HTML_ENTITY_RE = re.compile(
    "|".join(re.escape(k) for k in sorted(_HTML_ENTITIES, key=len, reverse=True))
)

# XML 1.0 forbids control characters except tab (0x09), LF (0x0A), CR (0x0D).
_INVALID_XML_CHARS_RE = re.compile(
    r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\ufffe\uffff]"
)

# Lone surrogates can appear when UTF-8 was mis-decoded from Latin-1.
_LONE_SURROGATE_RE = re.compile(r"[\ud800-\udfff]")

# Fields in RSS/Atom that legitimately hold HTML markup.  When feeds embed
# raw HTML here without CDATA wrapping, void elements like <br> and <img>
# break strict XML parsers.  We wrap the content in CDATA so ET sees them as
# opaque character data instead of markup.
_HTML_CONTENT_FIELDS_RE = re.compile(
    r"(<(?:description|content:encoded|summary|itunes:summary)>)"
    r"(.*?)"
    r"(</(?:description|content:encoded|summary|itunes:summary)>)",
    re.DOTALL,
)


def _fix_html_entities(xml_text: str) -> str:
    """Replace named HTML entities with their Unicode characters.

    XML 1.0 only defines five built-in entities (``&amp;``, ``&lt;``,
    ``&gt;``, ``&apos;``, ``&quot;``).  RSS feeds frequently contain HTML
    entities like ``&nbsp;`` or ``&iacute;`` which cause strict XML parsers to
    fail.  The replacement set covers all HTML 4.0 named entities via stdlib.
    """
    return _HTML_ENTITY_RE.sub(lambda m: _HTML_ENTITIES[m.group(0)], xml_text)


def _wrap_html_content_in_cdata(xml_text: str) -> str:
    """Wrap raw HTML inside RSS content fields with CDATA sections.

    Feeds such as FoxNews, Yahoo Sports, and Yahoo College embed raw HTML in
    ``<description>`` and ``<content:encoded>`` without CDATA wrapping.  Void
    HTML elements like ``<br>`` and ``<img>`` have no closing tag, which is
    valid HTML5 but illegal XML.  Wrapping the block in ``<![CDATA[...]]>``
    makes the XML parser treat the content as opaque text, avoiding parse
    failures while preserving the text for similarity matching.
    """
    def _wrap(m: re.Match) -> str:
        open_tag, content, close_tag = m.group(1), m.group(2), m.group(3)
        # Already CDATA-wrapped -- leave as-is.
        if "![CDATA[" in content:
            return m.group(0)
        # Only wrap if the block actually contains HTML markup.
        if re.search(r"<[a-zA-Z/!]", content):
            return f"{open_tag}<![CDATA[{content}]]>{close_tag}"
        return m.group(0)

    return _HTML_CONTENT_FIELDS_RE.sub(_wrap, xml_text)


def _strip_invalid_xml_chars(xml_text: str) -> str:
    """Remove characters that are illegal in XML 1.0.

    This covers null bytes, most C0/C1 control characters, and lone UTF-16
    surrogates that sometimes appear when feed content has been mangled by
    encoding mismatches.
    """
    xml_text = _INVALID_XML_CHARS_RE.sub("", xml_text)
    xml_text = _LONE_SURROGATE_RE.sub("", xml_text)
    return xml_text


def _strip_xml_declaration(xml_text: str) -> str:
    """Remove a leading XML declaration if present.

    ``ET.fromstring`` rejects an XML declaration when the input is a ``str``
    (as opposed to ``bytes``) because the encoding has already been resolved.
    """
    return re.sub(r"^\s*<\?xml[^?]*\?>\s*", "", xml_text, count=1)


def _preprocess(xml_text: str) -> str:
    """Apply all sanitisation steps to raw RSS XML text before parsing."""
    xml_text = _strip_xml_declaration(xml_text)
    xml_text = _strip_invalid_xml_chars(xml_text)
    xml_text = _fix_html_entities(xml_text)
    xml_text = _wrap_html_content_in_cdata(xml_text)
    xml_text = _fix_bare_ampersands(xml_text)
    xml_text = _fix_namespaces(xml_text)
    return xml_text


def _text(element: Optional[ET.Element]) -> str:
    """Return stripped text from an element, or '' if None."""
    if element is None:
        return ""
    return (element.text or "").strip()


def parse_feed(xml_source: str) -> list[Article]:
    """Parse an RSS 2.0 feed and return a list of Articles.

    Args:
        xml_source: File path or raw XML string.

    Returns:
        List of Article objects found in the feed.
    """
    try:
        if xml_source.strip().startswith("<"):
            root = ET.fromstring(_preprocess(xml_source))
        else:
            with open(xml_source, "r", encoding="utf-8", errors="replace") as fh:
                raw = fh.read()
            root = ET.fromstring(_preprocess(raw))
    except ET.ParseError as exc:
        raise ValueError(f"Failed to parse RSS feed: {exc}") from exc

    channel = root.find("channel")
    if channel is None:
        raise ValueError("No <channel> element found -- not a valid RSS 2.0 feed.")

    source = _text(channel.find("title"))
    articles: list[Article] = []

    for item in channel.findall("item"):
        title = _text(item.find("title"))
        url   = _text(item.find("link"))
        desc  = _text(item.find("description"))
        date  = _text(item.find("pubDate"))

        guid_el = item.find("guid")
        guid    = _text(guid_el) if guid_el is not None else url

        if not title:
            continue  # skip malformed items

        articles.append(Article(
            title=title,
            url=url,
            description=desc,
            pub_date=date,
            source=source,
            guid=guid or url,
        ))

    return articles


# ---------------------------------------------------------------------------
# Similarity helpers
# ---------------------------------------------------------------------------

_STOPWORDS = frozenset({
    "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
    "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
    "being", "have", "has", "had", "do", "does", "did", "will", "would",
    "could", "should", "may", "might", "can", "its", "it", "this", "that",
    "as", "up", "out", "into", "over", "after", "s", "us",
})


def _normalize_url(url: str) -> str:
    """Strip query strings and fragments for URL comparison."""
    url = url.strip().lower()
    url = re.sub(r"[?#].*$", "", url)
    url = url.rstrip("/")
    return url


def _tokenize(text: str) -> frozenset[str]:
    """Lowercase, strip punctuation, remove stopwords."""
    tokens = re.findall(r"[a-z0-9]+", text.lower())
    return frozenset(t for t in tokens if t not in _STOPWORDS)


def _jaccard(a: frozenset, b: frozenset) -> float:
    if not a and not b:
        return 1.0
    intersection = len(a & b)
    union = len(a | b)
    return intersection / union if union else 0.0


def _overlap_coefficient(a: frozenset, b: frozenset) -> float:
    """Fraction of the *smaller* token set that appears in the *larger* set.

    Unlike Jaccard, this is not penalised when one title is much shorter than
    the other -- a common pattern for cross-outlet coverage where a wire
    headline ("Khamenei's Son Named Supreme Leader in Iran") is a token-subset
    of a fuller headline ("Who Is Mojtaba Khamenei, Iran's New Supreme
    Leader?").  The overlap coefficient for those two is 4/6 ~ 0.67 vs a
    Jaccard of 4/9 ~ 0.44.
    """
    if not a and not b:
        return 1.0
    smaller = min(len(a), len(b))
    if smaller == 0:
        return 0.0
    return len(a & b) / smaller


def _field_similarity(a: frozenset, b: frozenset, min_tokens: int = 4) -> float:
    """Similarity measure with a minimum-token guard.

    Uses the **overlap coefficient** (|A&B| / min(|A|, |B|)) when both token
    sets have at least *min_tokens* meaningful words.  This is appropriate for
    both titles and long descriptions from different outlets, where one text
    is often a paraphrase or subset of the other and Jaccard's large-union
    penalty would under-measure the true similarity.

    Falls back to Jaccard when either set is smaller than *min_tokens*, to
    avoid false positives from very short texts (e.g. a 2-token section
    headline like "Trump's War" matching any article that contains both words).
    """
    if not a and not b:
        return 1.0
    if min(len(a), len(b)) < min_tokens:
        return _jaccard(a, b)
    return _overlap_coefficient(a, b)


# Keep the old name as an alias so existing call-sites don't break.
_title_similarity = _field_similarity


def _parse_date(pub_date: str) -> Optional[datetime]:
    """Parse an RFC 2822 pub_date string into an aware datetime, or None."""
    if not pub_date:
        return None
    try:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(pub_date)
    except Exception:
        return None


def _within_date_window(a: Optional[datetime], b: Optional[datetime], hours: float) -> bool:
    """Return True if both dates are absent or within *hours* of each other."""
    if a is None or b is None:
        return True  # can't rule out by date -- let content score decide
    return abs((a - b).total_seconds()) <= hours * 3600


def _content_score(
    title_a: frozenset,
    desc_a: frozenset,
    title_b: frozenset,
    desc_b: frozenset,
    title_weight: float = 0.6,
    desc_weight: float = 0.4,
) -> float:
    """Weighted combination of title and description similarity.

    Both title and description similarity use :func:`_field_similarity`, which
    applies the overlap coefficient when both texts are long enough (>=4 tokens)
    and falls back to Jaccard for short texts.

    The overlap coefficient avoids Jaccard's large-union penalty: two long
    descriptions that paraphrase the same event with different vocabulary will
    still share most of their *key* tokens, giving a high overlap score even
    when Jaccard would be low.

    Description signal is omitted entirely when both descriptions are empty,
    so the full weight falls on the title.
    """
    title_sim = _field_similarity(title_a, title_b)

    if desc_a or desc_b:
        desc_sim = _field_similarity(desc_a, desc_b)
        return title_sim * title_weight + desc_sim * desc_weight
    else:
        return title_sim


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------

def deduplicate(
    articles: list[Article],
    score_threshold: float = 0.35,
    date_window_hours: float = 48.0,
) -> list[Article]:
    """Remove duplicate articles from a mixed list of RSS articles.

    Two articles are considered duplicates when **any** of the following hold:

    1. Their normalised URLs or GUIDs match exactly (same article re-syndicated).
    2. Their combined content score meets or exceeds *score_threshold* **and**
       their publication dates are within *date_window_hours* of each other.

    The combined content score is:
        ``title_overlap_coefficient * 0.6 + description_jaccard * 0.4``

    **Title** similarity uses the overlap coefficient (|A&B| / min(|A|, |B|))
    rather than Jaccard.  This correctly handles cross-outlet coverage where a
    short wire headline shares most of its tokens with a longer article title --
    a pattern Jaccard under-scores because of the large union denominator.

    **Description** similarity also uses the overlap coefficient (with the same
    minimum-token guard), so long paraphrased descriptions from different
    outlets contribute a meaningful signal even when their Jaccard score would
    be low due to different but synonymous vocabulary.

    Publication date is used as a guard: two articles published more than
    *date_window_hours* apart are treated as distinct stories (e.g. follow-up
    reporting on the same topic).

    The first-seen article is always kept; later duplicates are discarded.

    Args:
        articles:          Flat list of Article objects (from one or more feeds).
        score_threshold:   Combined content score in [0, 1] required to call two
                           articles duplicates.  Defaults to 0.35.
        date_window_hours: Maximum age difference (in hours) between two articles
                            before they are exempted from content-based dedup.
                            Defaults to 48.

    Returns:
        De-duplicated list preserving original ordering.
    """
    seen_urls: set[str] = set()

    # Each accepted article contributes a record for content comparison.
    seen: list[tuple[frozenset, frozenset, Optional[datetime]]] = []  # (title_tokens, desc_tokens, date)

    unique: list[Article] = []

    for article in articles:
        norm_url  = _normalize_url(article.url  or article.guid)
        norm_guid = _normalize_url(article.guid or article.url)

        # 1. Exact URL / GUID match -- fast path
        if norm_url in seen_urls or norm_guid in seen_urls:
            continue

        # 2. Combined content + date similarity
        title_tok = _tokenize(article.title)
        desc_tok  = _tokenize(article.description)
        pub_date  = _parse_date(article.pub_date)

        is_dup = False
        for prev_title, prev_desc, prev_date in seen:
            if not _within_date_window(pub_date, prev_date, date_window_hours):
                continue
            if _content_score(title_tok, desc_tok, prev_title, prev_desc) >= score_threshold:
                is_dup = True
                break
        if is_dup:
            continue

        # Accept this article
        seen_urls.add(norm_url)
        seen_urls.add(norm_guid)
        seen.append((title_tok, desc_tok, pub_date))
        unique.append(article)

    return unique


def deduplicate_feeds(
    xml_sources: list[str],
    score_threshold: float = 0.35,
    date_window_hours: float = 48.0,
) -> list[Article]:
    """Parse multiple RSS feeds and return a deduplicated list of articles.

    Args:
        xml_sources:       List of file paths or raw XML strings.
        score_threshold:   Minimum content similarity score to consider two articles duplicates.
        date_window_hours: Maximum age difference (in hours) between two articles before they are exempted from content-based deduplication.

    Returns:
        Flat, de-duplicated list of Article objects.
    """
    all_articles: list[Article] = []
    for src in xml_sources:
        all_articles.extend(parse_feed(src))
    return deduplicate(all_articles,
                        score_threshold=score_threshold,
                        date_window_hours=date_window_hours)
