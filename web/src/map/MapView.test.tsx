import { render } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { MapView } from './MapView'

const noop = () => {}

describe('MapView', () => {
  it('mounts without crashing on an empty state', () => {
    const { container } = render(
      <MapView
        state={{ origin: null, destination: null, routes: [] }}
        onMapClick={noop}
        onAddViaPoint={vi.fn()}
        onMoveViaPoint={vi.fn()}
        onRemoveViaPoint={vi.fn()}
      />,
    )

    expect(container.querySelector('.leaflet-container')).not.toBeNull()
  })
})
