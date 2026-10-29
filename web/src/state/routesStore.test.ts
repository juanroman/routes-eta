import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  addCommute,
  addRoute,
  addScheduleRule,
  addViaPoint,
  buildConfigPayload,
  deleteCommute,
  deleteRoute,
  fromConfig,
  initialState,
  moveRoute,
  moveViaPoint,
  recolorRoute,
  removeScheduleRule,
  removeViaPoint,
  renameCommute,
  renameRoute,
  selectCommute,
  updateScheduleRule,
} from './routesStore'
import { validateConfig } from '../api/configSchema'

// Shared with api/'s tests (prd.md §11) — see fixtures/sample-config.json.
// process.cwd() is reliably web/ here; see configSchema.test.ts for why
// this doesn't use import.meta.url.
const FIXTURE_PATH = resolve(process.cwd(), '..', 'fixtures', 'sample-config.json')
const SAMPLE_CONFIG = validateConfig(JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8')))

function workToHomeId(state: ReturnType<typeof fromConfig>): string {
  return state.commutes[0].id
}

describe('fromConfig', () => {
  it('builds a commute per config entry and selects the first', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    expect(state.commutes.map((c) => c.name)).toEqual(['Work to Home', 'Home to Work'])
    expect(state.selectedCommuteId).toBe(state.commutes[0].id)
  })
})

describe('addCommute', () => {
  it('appends a commute with a default name and selects it', () => {
    const state = addCommute(fromConfig(SAMPLE_CONFIG))
    expect(state.commutes).toHaveLength(3)
    const added = state.commutes[2]
    expect(added.name).toBe('Commute 3')
    expect(added.routes).toEqual([])
    expect(state.selectedCommuteId).toBe(added.id)
  })
})

describe('renameCommute / deleteCommute / selectCommute', () => {
  it('renames only the targeted commute', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = workToHomeId(state)
    const renamed = renameCommute(state, id, 'Evening commute')
    expect(renamed.commutes[0].name).toBe('Evening commute')
    expect(renamed.commutes[1].name).toBe('Home to Work')
  })

  it('selects a commute by id', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const secondId = state.commutes[1].id
    const selected = selectCommute(state, secondId)
    expect(selected.selectedCommuteId).toBe(secondId)
  })

  it('deletes a commute and falls back to the first remaining one when selected', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const firstId = workToHomeId(state)
    const result = deleteCommute(state, firstId)
    expect(result.commutes).toHaveLength(1)
    expect(result.commutes[0].name).toBe('Home to Work')
    expect(result.selectedCommuteId).toBe(result.commutes[0].id)
  })

  it('deleting a non-selected commute keeps the current selection', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const firstId = workToHomeId(state)
    const secondId = state.commutes[1].id
    const result = deleteCommute(state, secondId)
    expect(result.selectedCommuteId).toBe(firstId)
  })

  it('deleting the last commute leaves no selection', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const firstId = workToHomeId(state)
    const secondId = state.commutes[1].id
    const afterFirst = deleteCommute(state, firstId)
    const afterSecond = deleteCommute(afterFirst, secondId)
    expect(afterSecond.commutes).toHaveLength(0)
    expect(afterSecond.selectedCommuteId).toBeNull()
  })
})

describe('schedule rule mutators', () => {
  it('adds, updates and removes a schedule rule', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = workToHomeId(state)

    const added = addScheduleRule(state, id)
    expect(added.commutes[0].schedules).toHaveLength(2)

    const updated = updateScheduleRule(added, id, 1, {
      weekdays: ['sat'],
      time: '09:00',
    })
    expect(updated.commutes[0].schedules[1]).toEqual({
      weekdays: ['sat'],
      time: '09:00',
    })

    const removed = removeScheduleRule(updated, id, 0)
    expect(removed.commutes[0].schedules).toEqual([
      { weekdays: ['sat'], time: '09:00' },
    ])
  })
})

describe('addRoute', () => {
  it('appends a route with a default name and an unused color, scoped to the commute', () => {
    const before = fromConfig(SAMPLE_CONFIG)
    const state = addRoute(before, workToHomeId(before))
    expect(state.commutes[0].routes).toHaveLength(3)
    const added = state.commutes[0].routes[2]
    expect(added.name).toBe('Route 3')
    expect(added.color).not.toBe('#2563eb')
    expect(added.color).not.toBe('#dc2626')
    // The other commute is untouched.
    expect(state.commutes[1].routes).toHaveLength(1)
  })
})

describe('renameRoute / recolorRoute', () => {
  it('updates only the targeted route', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const commuteId = workToHomeId(state)
    const id = state.commutes[0].routes[0].id
    const renamed = renameRoute(state, commuteId, id, 'Shortcut')
    expect(renamed.commutes[0].routes[0].name).toBe('Shortcut')
    expect(renamed.commutes[0].routes[1].name).toBe('Mordor')

    const recolored = recolorRoute(renamed, commuteId, id, '#000000')
    expect(recolored.commutes[0].routes[0].color).toBe('#000000')
  })
})

describe('deleteRoute', () => {
  it('removes the targeted route only', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const commuteId = workToHomeId(state)
    const id = state.commutes[0].routes[0].id
    const result = deleteRoute(state, commuteId, id)
    expect(result.commutes[0].routes).toHaveLength(1)
    expect(result.commutes[0].routes[0].name).toBe('Mordor')
  })
})

describe('moveRoute', () => {
  it('swaps with the previous route when moving up', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const commuteId = workToHomeId(state)
    const id = state.commutes[0].routes[1].id
    const result = moveRoute(state, commuteId, id, 'up')
    expect(result.commutes[0].routes.map((r) => r.name)).toEqual(['Mordor', 'City'])
  })

  it('is a no-op at the boundary', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const commuteId = workToHomeId(state)
    const id = state.commutes[0].routes[0].id
    const result = moveRoute(state, commuteId, id, 'up')
    expect(result.commutes[0].routes.map((r) => r.name)).toEqual(['City', 'Mordor'])
  })
})

describe('via point operations', () => {
  it('adds, moves and removes a via point', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const commuteId = workToHomeId(state)
    const id = state.commutes[0].routes[1].id // Mordor, starts with no via points

    const added = addViaPoint(state, commuteId, id, { lat: 1, lng: 1 }, 0)
    expect(added.commutes[0].routes[1].via).toEqual([{ lat: 1, lng: 1 }])

    const moved = moveViaPoint(added, commuteId, id, 0, { lat: 2, lng: 2 })
    expect(moved.commutes[0].routes[1].via).toEqual([{ lat: 2, lng: 2 }])

    const removed = removeViaPoint(moved, commuteId, id, 0)
    expect(removed.commutes[0].routes[1].via).toEqual([])
  })
})

describe('buildConfigPayload', () => {
  it('strips client-only fields and keeps base timezone', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const payload = buildConfigPayload(state, SAMPLE_CONFIG)

    expect(payload.timezone).toBe(SAMPLE_CONFIG.timezone)
    expect(payload.commutes).toEqual(SAMPLE_CONFIG.commutes)
  })

  it('reflects an empty starting state', () => {
    const payload = buildConfigPayload(initialState(), SAMPLE_CONFIG)
    expect(payload.commutes).toEqual([])
  })
})
