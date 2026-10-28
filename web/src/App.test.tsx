import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import App from './App'
import * as apiClient from './api/client'
import type { Config } from './api/types'

vi.mock('./map/MapView', () => ({
  MapView: () => <div data-testid="map-view-stub" />,
}))

const EMPTY_CONFIG: Config = {
  timezone: 'America/Mexico_City',
  schedule: { weekdays: ['mon', 'tue', 'wed', 'thu', 'fri'], time: '18:30' },
  origin: null,
  destination: null,
  routes: [],
}

describe('App', () => {
  it('loads the config on mount and renders an empty route list', async () => {
    const getConfigSpy = vi
      .spyOn(apiClient, 'getConfig')
      .mockResolvedValue(EMPTY_CONFIG)

    render(<App />)

    expect(await screen.findByTestId('map-view-stub')).toBeInTheDocument()
    expect(getConfigSpy).toHaveBeenCalledOnce()
    expect(screen.getByText('+ New route')).toBeInTheDocument()
    expect(screen.queryByLabelText('Route name')).not.toBeInTheDocument()
  })

  it('shows an error state when the config fails to load', async () => {
    vi.spyOn(apiClient, 'getConfig').mockRejectedValue(new Error('boom'))

    render(<App />)

    expect(
      await screen.findByText('Could not load the config from the API.'),
    ).toBeInTheDocument()
  })

  it('sends the ETAs now and shows a chip per route', async () => {
    vi.spyOn(apiClient, 'getConfig').mockResolvedValue(EMPTY_CONFIG)
    vi.spyOn(apiClient, 'runNow').mockResolvedValue({
      message: 'City 56 · Mordor ?',
      results: [
        { name: 'City', minutes: 56, error: null },
        { name: 'Mordor', minutes: null, error: 'timeout' },
      ],
    })

    render(<App />)
    await screen.findByTestId('map-view-stub')

    fireEvent.click(screen.getByText('Send ETAs now'))

    expect(await screen.findByText('City')).toBeInTheDocument()
    expect(await screen.findByText('56 min')).toBeInTheDocument()
    expect(await screen.findByText('Mordor')).toBeInTheDocument()
    expect(await screen.findByText('?')).toBeInTheDocument()
  })

  it('shows an error when sending the ETAs fails', async () => {
    vi.spyOn(apiClient, 'getConfig').mockResolvedValue(EMPTY_CONFIG)
    vi.spyOn(apiClient, 'runNow').mockRejectedValue(
      new apiClient.ApiError('no routes are configured'),
    )

    render(<App />)
    await screen.findByTestId('map-view-stub')

    fireEvent.click(screen.getByText('Send ETAs now'))

    expect(
      await screen.findByText('Could not send ETAs: no routes are configured'),
    ).toBeInTheDocument()
  })
})
