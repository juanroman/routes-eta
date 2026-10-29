"""The config schema: the only contract between the builder and the checker.

Everything is optional/defaulted so a brand-new, never-saved config is valid —
the owner defines origin, destination and routes entirely through the builder
UI (see prd.md FR-1..FR-7), not by hand-editing this file.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator

Weekday = Literal["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

# Google's computeRoutes allows up to 25 intermediates; 23 leaves headroom in
# case a future revision wants to inject one or two fixed waypoints.
MAX_VIA_POINTS = 23


class LatLng(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class NamedPoint(LatLng):
    label: str


class RouteDef(BaseModel):
    name: str = Field(min_length=1)
    color: str = Field(pattern=r"^#[0-9a-fA-F]{6}$")
    via: list[LatLng] = Field(default_factory=list, max_length=MAX_VIA_POINTS)


class ScheduleRule(BaseModel):
    weekdays: list[Weekday] = Field(min_length=1)
    # HH:MM, 24-hour, local time in `Config.timezone`.
    time: str = Field(default="18:30", pattern=r"^([01]\d|2[0-3]):[0-5]\d$")


class Commute(BaseModel):
    name: str = Field(min_length=1)
    origin: NamedPoint | None = None
    destination: NamedPoint | None = None
    routes: list[RouteDef] = Field(default_factory=list)
    schedules: list[ScheduleRule] = Field(default_factory=list)

    @field_validator("routes")
    @classmethod
    def _unique_route_names(cls, routes: list[RouteDef]) -> list[RouteDef]:
        names = [r.name for r in routes]
        if len(names) != len(set(names)):
            raise ValueError("route names must be unique")
        return routes

    @field_validator("schedules")
    @classmethod
    def _no_overlapping_weekdays(
        cls, schedules: list[ScheduleRule]
    ) -> list[ScheduleRule]:
        seen: set[Weekday] = set()
        for rule in schedules:
            for day in rule.weekdays:
                if day in seen:
                    raise ValueError(
                        f"weekday {day!r} is scheduled by more than one rule"
                    )
                seen.add(day)
        return schedules


class Config(BaseModel):
    timezone: str = "America/Mexico_City"
    commutes: list[Commute] = Field(default_factory=list)

    @field_validator("commutes")
    @classmethod
    def _unique_commute_names(cls, commutes: list[Commute]) -> list[Commute]:
        names = [c.name for c in commutes]
        if len(names) != len(set(names)):
            raise ValueError("commute names must be unique")
        return commutes
