from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

_UTC = ZoneInfo("UTC")


def resolve_zone(tz_name: str | None) -> ZoneInfo:
    """Look up a tenant/branch timezone name, falling back to UTC if unset or invalid."""
    if not tz_name:
        return _UTC
    try:
        return ZoneInfo(tz_name)
    except ZoneInfoNotFoundError:
        return _UTC


def local_day_start_utc(d: date, tz_name: str | None) -> datetime:
    """UTC instant corresponding to midnight of `d` in the given local timezone."""
    local_midnight = datetime(d.year, d.month, d.day, tzinfo=resolve_zone(tz_name))
    return local_midnight.astimezone(timezone.utc)


def local_day_end_utc(d: date, tz_name: str | None) -> datetime:
    """Exclusive UTC end boundary — start of the next local day.

    Must recompute local midnight for d+1 rather than adding a flat 24h to
    d's start — on a DST-transition day the local calendar day is 23 or 25
    hours long, so start(d) + 24h lands an hour short of or past the real
    next-midnight boundary.
    """
    return local_day_start_utc(d + timedelta(days=1), tz_name)
