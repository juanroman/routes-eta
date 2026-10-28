// Runtime validator for the config schema (prd.md §11): config_models.py
// validates this shape server-side with Pydantic, but web/'s TypeScript
// interfaces (./types.ts) are erased at runtime, so a malformed /config
// response would otherwise silently produce broken UI state. This mirrors
// config_models.py's exact field constraints by hand rather than adding a
// validation library, matching this project's existing no-new-dependency
// precedent (see PROGRESS.md: route reordering via buttons, not drag-and-drop).

import type { Config, Weekday } from './types'

const WEEKDAYS: readonly Weekday[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
const COLOR_PATTERN = /^#[0-9a-fA-F]{6}$/
const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function checkLatLng(value: unknown, path: string, errors: string[]): void {
  if (!isRecord(value)) {
    errors.push(`${path}: expected an object`)
    return
  }
  if (typeof value.lat !== 'number' || value.lat < -90 || value.lat > 90) {
    errors.push(`${path}.lat: expected a number between -90 and 90`)
  }
  if (typeof value.lng !== 'number' || value.lng < -180 || value.lng > 180) {
    errors.push(`${path}.lng: expected a number between -180 and 180`)
  }
}

function checkNamedPoint(value: unknown, path: string, errors: string[]): void {
  checkLatLng(value, path, errors)
  if (isRecord(value) && typeof value.label !== 'string') {
    errors.push(`${path}.label: expected a string`)
  }
}

function checkSchedule(value: unknown, errors: string[]): void {
  if (!isRecord(value)) {
    errors.push('schedule: expected an object')
    return
  }
  if (!Array.isArray(value.weekdays) || value.weekdays.length === 0) {
    errors.push('schedule.weekdays: expected a non-empty array')
  } else {
    for (const day of value.weekdays) {
      if (!WEEKDAYS.includes(day as Weekday)) {
        errors.push(`schedule.weekdays: "${String(day)}" is not a valid weekday`)
      }
    }
  }
  if (typeof value.time !== 'string' || !TIME_PATTERN.test(value.time)) {
    errors.push('schedule.time: expected "HH:MM" 24-hour local time')
  }
}

function checkRoute(value: unknown, index: number, errors: string[]): void {
  const path = `routes[${index}]`
  if (!isRecord(value)) {
    errors.push(`${path}: expected an object`)
    return
  }
  if (typeof value.name !== 'string' || value.name.length === 0) {
    errors.push(`${path}.name: expected a non-empty string`)
  }
  if (typeof value.color !== 'string' || !COLOR_PATTERN.test(value.color)) {
    errors.push(`${path}.color: expected a "#rrggbb" hex color`)
  }
  if (!Array.isArray(value.via)) {
    errors.push(`${path}.via: expected an array`)
  } else {
    value.via.forEach((point, i) => checkLatLng(point, `${path}.via[${i}]`, errors))
  }
}

function checkRoutes(value: unknown, errors: string[]): void {
  if (!Array.isArray(value)) {
    errors.push('routes: expected an array')
    return
  }
  value.forEach((route, i) => checkRoute(route, i, errors))

  const names = value
    .filter(isRecord)
    .map((route) => route.name)
    .filter((name): name is string => typeof name === 'string')
  if (new Set(names).size !== names.length) {
    errors.push('routes: route names must be unique')
  }
}

/** Validates an unknown value against the Config schema (prd.md §8),
 * mirroring config_models.py's constraints. Throws a single Error listing
 * every problem found if `data` doesn't match. */
export function validateConfig(data: unknown): Config {
  if (!isRecord(data)) {
    throw new Error('Config: expected an object')
  }

  const errors: string[] = []
  if (typeof data.timezone !== 'string') {
    errors.push('timezone: expected a string')
  }
  checkSchedule(data.schedule, errors)
  if (data.origin !== null) checkNamedPoint(data.origin, 'origin', errors)
  if (data.destination !== null)
    checkNamedPoint(data.destination, 'destination', errors)
  checkRoutes(data.routes, errors)

  if (errors.length > 0) {
    throw new Error(`Config failed schema validation:\n- ${errors.join('\n- ')}`)
  }

  return data as unknown as Config
}
