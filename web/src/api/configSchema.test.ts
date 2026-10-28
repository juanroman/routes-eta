import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { validateConfig } from './configSchema'

// The one config fixture api/ and web/ tests both load (prd.md §11), so the
// two schemas can't silently diverge. See api/tests/unit/test_config_models.py's
// test_shared_sample_config_fixture_validates for the Python side.
// process.cwd() is reliably web/ here, however the suite is invoked
// (npm run test, npm run check, or the root check.sh) — import.meta.url
// isn't a real file:// URL under Vitest's module transform.
const FIXTURE_PATH = resolve(process.cwd(), '..', 'fixtures', 'sample-config.json')

function loadSampleConfig(): unknown {
  return JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8'))
}

describe('validateConfig', () => {
  it('accepts the shared sample config fixture', () => {
    const config = validateConfig(loadSampleConfig())

    expect(config.origin?.label).toBe('Work')
    expect(config.routes.map((r) => r.name)).toEqual(['City', 'Mordor'])
  })

  it('accepts null origin/destination and an empty routes list', () => {
    const config = validateConfig({
      timezone: 'America/Mexico_City',
      schedule: { weekdays: ['mon'], time: '18:30' },
      origin: null,
      destination: null,
      routes: [],
    })

    expect(config.origin).toBeNull()
    expect(config.routes).toEqual([])
  })

  it('rejects an out-of-range latitude', () => {
    const sample = loadSampleConfig() as Record<string, unknown>
    const bad = { ...sample, origin: { ...(sample.origin as object), lat: 999 } }

    expect(() => validateConfig(bad)).toThrow(/lat/)
  })

  it('rejects a malformed color', () => {
    const sample = loadSampleConfig() as { routes: Record<string, unknown>[] }
    const bad = {
      ...sample,
      routes: [{ ...sample.routes[0], color: 'blue' }],
    }

    expect(() => validateConfig(bad)).toThrow(/color/)
  })

  it('rejects a malformed schedule time', () => {
    const sample = loadSampleConfig() as { schedule: Record<string, unknown> }
    const bad = { ...sample, schedule: { ...sample.schedule, time: '9:30am' } }

    expect(() => validateConfig(bad)).toThrow(/time/)
  })

  it('rejects an unknown weekday', () => {
    const sample = loadSampleConfig() as { schedule: Record<string, unknown> }
    const bad = {
      ...sample,
      schedule: { ...sample.schedule, weekdays: ['funday'] },
    }

    expect(() => validateConfig(bad)).toThrow(/weekday/)
  })

  it('rejects duplicate route names', () => {
    const sample = loadSampleConfig() as { routes: Record<string, unknown>[] }
    const bad = {
      ...sample,
      routes: [sample.routes[0], { ...sample.routes[0] }],
    }

    expect(() => validateConfig(bad)).toThrow(/unique/)
  })

  it('throws with every problem listed when there are multiple', () => {
    expect(() => validateConfig({})).toThrow(/timezone/)
  })
})
