import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, getConfig, previewRoute, runNow, saveConfig } from './client'
import type { Config, PreviewRequest } from './types'

const EMPTY_CONFIG: Config = {
  timezone: 'America/Mexico_City',
  commutes: [],
}

function mockFetchOnce(status: number, body: unknown): void {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({
      ok: status >= 200 && status < 300,
      status,
      json: () => Promise.resolve(body),
    }),
  )
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('getConfig', () => {
  it('fetches /api/config', async () => {
    mockFetchOnce(200, EMPTY_CONFIG)
    const config = await getConfig()
    expect(config).toEqual(EMPTY_CONFIG)
    expect(fetch).toHaveBeenCalledWith(
      '/api/config',
      expect.objectContaining({ headers: { 'Content-Type': 'application/json' } }),
    )
  })

  it('throws ApiError when the response fails config-schema validation', async () => {
    mockFetchOnce(200, {
      ...EMPTY_CONFIG,
      commutes: [
        { name: 'Work to Home', schedules: [{ weekdays: ['mon'], time: 'noon' }] },
      ],
    })

    await expect(getConfig()).rejects.toThrow(ApiError)
    await expect(getConfig()).rejects.toThrow(/schema validation/)
  })
})

describe('saveConfig', () => {
  it('PUTs the config as JSON', async () => {
    mockFetchOnce(200, EMPTY_CONFIG)
    await saveConfig(EMPTY_CONFIG)
    expect(fetch).toHaveBeenCalledWith(
      '/api/config',
      expect.objectContaining({ method: 'PUT', body: JSON.stringify(EMPTY_CONFIG) }),
    )
  })
})

describe('previewRoute', () => {
  const request: PreviewRequest = {
    origin: { lat: 0, lng: 0 },
    destination: { lat: 1, lng: 1 },
    via: [],
  }

  it('POSTs to /api/preview and returns the result', async () => {
    mockFetchOnce(200, { distance_meters: 100, polyline: [[0, 0]] })
    const result = await previewRoute(request)
    expect(result.distance_meters).toBe(100)
  })

  it('throws ApiError with the detail message on a non-2xx response', async () => {
    mockFetchOnce(502, { detail: 'Google Routes API returned 403' })
    await expect(previewRoute(request)).rejects.toThrow(ApiError)
    await expect(previewRoute(request)).rejects.toThrow(
      'Google Routes API returned 403',
    )
  })

  it('falls back to a generic message when the error body has no detail', async () => {
    mockFetchOnce(500, {})
    await expect(previewRoute(request)).rejects.toThrow('failed with status 500')
  })
})

describe('runNow', () => {
  it('POSTs to /api/run-now with the commute name and returns the result', async () => {
    mockFetchOnce(200, {
      commute: 'Work to Home',
      message: 'Work to Home: City 56',
      results: [{ name: 'City', minutes: 56, error: null }],
    })

    const result = await runNow('Work to Home')

    expect(result.message).toBe('Work to Home: City 56')
    expect(fetch).toHaveBeenCalledWith(
      '/api/run-now',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ commute: 'Work to Home' }),
      }),
    )
  })

  it('throws ApiError with the detail message on a non-2xx response', async () => {
    mockFetchOnce(400, { detail: 'no routes are configured' })
    await expect(runNow('Work to Home')).rejects.toThrow(ApiError)
    await expect(runNow('Work to Home')).rejects.toThrow('no routes are configured')
  })
})
