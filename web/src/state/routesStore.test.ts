import { describe, expect, it } from 'vitest'
import {
  addRoute,
  addViaPoint,
  buildConfigPayload,
  deleteRoute,
  fromConfig,
  initialState,
  moveRoute,
  moveViaPoint,
  recolorRoute,
  removeViaPoint,
  renameRoute,
} from './routesStore'
import type { Config } from '../api/types'

const SAMPLE_CONFIG: Config = {
  timezone: 'America/Mexico_City',
  schedule: { weekdays: ['mon', 'tue', 'wed', 'thu', 'fri'], time: '18:30' },
  origin: { label: 'Work', lat: 19.4284, lng: -99.1677 },
  destination: { label: 'Home', lat: 19.5095, lng: -99.2383 },
  routes: [
    { name: 'City', color: '#2563eb', via: [{ lat: 19.455, lng: -99.205 }] },
    { name: 'Mordor', color: '#dc2626', via: [] },
  ],
}

describe('addRoute', () => {
  it('appends a route with a default name and an unused color', () => {
    const state = addRoute(fromConfig(SAMPLE_CONFIG))
    expect(state.routes).toHaveLength(3)
    const added = state.routes[2]
    expect(added.name).toBe('Route 3')
    expect(added.color).not.toBe('#2563eb')
    expect(added.color).not.toBe('#dc2626')
  })
})

describe('renameRoute / recolorRoute', () => {
  it('updates only the targeted route', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = state.routes[0].id
    const renamed = renameRoute(state, id, 'Shortcut')
    expect(renamed.routes[0].name).toBe('Shortcut')
    expect(renamed.routes[1].name).toBe('Mordor')

    const recolored = recolorRoute(renamed, id, '#000000')
    expect(recolored.routes[0].color).toBe('#000000')
  })
})

describe('deleteRoute', () => {
  it('removes the targeted route only', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = state.routes[0].id
    const result = deleteRoute(state, id)
    expect(result.routes).toHaveLength(1)
    expect(result.routes[0].name).toBe('Mordor')
  })
})

describe('moveRoute', () => {
  it('swaps with the previous route when moving up', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = state.routes[1].id
    const result = moveRoute(state, id, 'up')
    expect(result.routes.map((r) => r.name)).toEqual(['Mordor', 'City'])
  })

  it('is a no-op at the boundary', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = state.routes[0].id
    const result = moveRoute(state, id, 'up')
    expect(result.routes.map((r) => r.name)).toEqual(['City', 'Mordor'])
  })
})

describe('via point operations', () => {
  it('adds, moves and removes a via point', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const id = state.routes[1].id // Mordor, starts with no via points

    const added = addViaPoint(state, id, { lat: 1, lng: 1 }, 0)
    expect(added.routes[1].via).toEqual([{ lat: 1, lng: 1 }])

    const moved = moveViaPoint(added, id, 0, { lat: 2, lng: 2 })
    expect(moved.routes[1].via).toEqual([{ lat: 2, lng: 2 }])

    const removed = removeViaPoint(moved, id, 0)
    expect(removed.routes[1].via).toEqual([])
  })
})

describe('buildConfigPayload', () => {
  it('strips client-only fields and keeps base schedule/timezone', () => {
    const state = fromConfig(SAMPLE_CONFIG)
    const payload = buildConfigPayload(state, SAMPLE_CONFIG)

    expect(payload.timezone).toBe(SAMPLE_CONFIG.timezone)
    expect(payload.schedule).toEqual(SAMPLE_CONFIG.schedule)
    expect(payload.routes).toEqual([
      { name: 'City', color: '#2563eb', via: [{ lat: 19.455, lng: -99.205 }] },
      { name: 'Mordor', color: '#dc2626', via: [] },
    ])
  })

  it('reflects an empty starting state', () => {
    const payload = buildConfigPayload(initialState(), SAMPLE_CONFIG)
    expect(payload.origin).toBeNull()
    expect(payload.destination).toBeNull()
    expect(payload.routes).toEqual([])
  })
})
