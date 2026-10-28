import { render } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { MapView } from './MapView'
import { initialState } from '../state/routesStore'

const noop = () => {}

describe('MapView', () => {
  it('mounts without crashing on an empty builder state', () => {
    const { container } = render(
      <MapView
        state={initialState()}
        onMapClick={noop}
        onAddViaPoint={vi.fn()}
        onMoveViaPoint={vi.fn()}
        onRemoveViaPoint={vi.fn()}
      />,
    )

    expect(container.querySelector('.leaflet-container')).not.toBeNull()
  })
})
