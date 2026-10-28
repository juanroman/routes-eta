import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { RoutePanel } from './RoutePanel'
import type { RouteUI } from '../state/types'

function makeRoute(overrides: Partial<RouteUI>): RouteUI {
  return {
    id: 'route-1',
    name: 'City',
    color: '#2563eb',
    via: [],
    previewPolyline: null,
    previewStatus: 'idle',
    ...overrides,
  }
}

// origin/destination are null throughout — useRoutePreview short-circuits
// with no origin/destination, so no network calls happen in these tests.
const noop = () => {}

describe('RoutePanel', () => {
  it('renames a route', async () => {
    const onRename = vi.fn()
    render(
      <RoutePanel
        routes={[makeRoute({})]}
        origin={null}
        destination={null}
        onRename={onRename}
        onRecolor={noop}
        onDelete={noop}
        onMoveUp={noop}
        onMoveDown={noop}
        onAddRoute={noop}
        onPreviewLoading={noop}
        onPreviewSuccess={noop}
        onPreviewError={noop}
      />,
    )

    const input = screen.getByLabelText('Route name')
    fireEvent.change(input, { target: { value: 'Shortcut' } })

    expect(onRename).toHaveBeenCalledWith('route-1', 'Shortcut')
  })

  it('deletes a route', async () => {
    const onDelete = vi.fn()
    render(
      <RoutePanel
        routes={[makeRoute({})]}
        origin={null}
        destination={null}
        onRename={noop}
        onRecolor={noop}
        onDelete={onDelete}
        onMoveUp={noop}
        onMoveDown={noop}
        onAddRoute={noop}
        onPreviewLoading={noop}
        onPreviewSuccess={noop}
        onPreviewError={noop}
      />,
    )

    await userEvent.click(screen.getByLabelText('Delete route'))
    expect(onDelete).toHaveBeenCalledWith('route-1')
  })

  it('disables move-up for the first route and move-down for the last', () => {
    render(
      <RoutePanel
        routes={[makeRoute({ id: 'a', name: 'A' }), makeRoute({ id: 'b', name: 'B' })]}
        origin={null}
        destination={null}
        onRename={noop}
        onRecolor={noop}
        onDelete={noop}
        onMoveUp={noop}
        onMoveDown={noop}
        onAddRoute={noop}
        onPreviewLoading={noop}
        onPreviewSuccess={noop}
        onPreviewError={noop}
      />,
    )

    const moveUpButtons = screen.getAllByLabelText('Move up')
    const moveDownButtons = screen.getAllByLabelText('Move down')
    expect(moveUpButtons[0]).toBeDisabled()
    expect(moveDownButtons[1]).toBeDisabled()
  })

  it('calls onAddRoute from the new-route button', async () => {
    const onAddRoute = vi.fn()
    render(
      <RoutePanel
        routes={[]}
        origin={null}
        destination={null}
        onRename={noop}
        onRecolor={noop}
        onDelete={noop}
        onMoveUp={noop}
        onMoveDown={noop}
        onAddRoute={onAddRoute}
        onPreviewLoading={noop}
        onPreviewSuccess={noop}
        onPreviewError={noop}
      />,
    )

    await userEvent.click(screen.getByText('+ New route'))
    expect(onAddRoute).toHaveBeenCalled()
  })
})
