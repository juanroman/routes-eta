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

interface SampleCommute {
  name: string
  origin: { label: string; lat: number; lng: number } | null
  destination: unknown
  routes: Record<string, unknown>[]
  schedules: Record<string, unknown>[]
}

function loadSampleConfig(): { timezone: string; commutes: SampleCommute[] } {
  return JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8'))
}

describe('validateConfig', () => {
  it('accepts the shared sample config fixture', () => {
    const config = validateConfig(loadSampleConfig())

    expect(config.commutes.map((c) => c.name)).toEqual(['Work to Home', 'Home to Work'])
    expect(config.commutes[0].origin?.label).toBe('Work')
    expect(config.commutes[0].routes.map((r) => r.name)).toEqual(['City', 'Mordor'])
  })

  it('accepts an empty commutes list', () => {
    const config = validateConfig({ timezone: 'America/Mexico_City', commutes: [] })
    expect(config.commutes).toEqual([])
  })

  it('accepts null origin/destination and an empty routes/schedules list', () => {
    const config = validateConfig({
      timezone: 'America/Mexico_City',
      commutes: [
        {
          name: 'Work to Home',
          origin: null,
          destination: null,
          routes: [],
          schedules: [],
        },
      ],
    })

    expect(config.commutes[0].origin).toBeNull()
    expect(config.commutes[0].routes).toEqual([])
  })

  it('rejects an out-of-range latitude', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        { ...sample.commutes[0], origin: { ...sample.commutes[0].origin, lat: 999 } },
        sample.commutes[1],
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/lat/)
  })

  it('rejects a malformed color', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        {
          ...sample.commutes[0],
          routes: [{ ...sample.commutes[0].routes[0], color: 'blue' }],
        },
        sample.commutes[1],
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/color/)
  })

  it('rejects a malformed schedule time', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        {
          ...sample.commutes[0],
          schedules: [{ ...sample.commutes[0].schedules[0], time: '9:30am' }],
        },
        sample.commutes[1],
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/time/)
  })

  it('rejects an unknown weekday', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        {
          ...sample.commutes[0],
          schedules: [{ ...sample.commutes[0].schedules[0], weekdays: ['funday'] }],
        },
        sample.commutes[1],
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/weekday/)
  })

  it('rejects duplicate route names within a commute', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        {
          ...sample.commutes[0],
          routes: [sample.commutes[0].routes[0], { ...sample.commutes[0].routes[0] }],
        },
        sample.commutes[1],
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/route names must be unique/)
  })

  it('rejects duplicate commute names', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        sample.commutes[0],
        { ...sample.commutes[1], name: sample.commutes[0].name },
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/commute names must be unique/)
  })

  it('rejects a weekday scheduled by more than one rule in the same commute', () => {
    const sample = loadSampleConfig()
    const bad = {
      ...sample,
      commutes: [
        sample.commutes[0],
        {
          ...sample.commutes[1],
          schedules: [
            { weekdays: ['mon'], time: '06:30' },
            { weekdays: ['mon', 'tue'], time: '07:30' },
          ],
        },
      ],
    }

    expect(() => validateConfig(bad)).toThrow(/scheduled by more than one rule/)
  })

  it('throws with every problem listed when there are multiple', () => {
    expect(() => validateConfig({})).toThrow(/timezone/)
  })
})
