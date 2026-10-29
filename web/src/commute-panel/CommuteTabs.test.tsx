import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { CommuteTabs } from './CommuteTabs'
import type { CommuteUI } from '../state/types'

function makeCommute(overrides: Partial<CommuteUI>): CommuteUI {
  return {
    id: 'commute-1',
    name: 'Work to Home',
    origin: null,
    destination: null,
    routes: [],
    schedules: [],
    ...overrides,
  }
}

const noop = () => {}

describe('CommuteTabs', () => {
  it('renders a tab per commute, marking the selected one active', () => {
    const { container } = render(
      <CommuteTabs
        commutes={[
          makeCommute({}),
          makeCommute({ id: 'commute-2', name: 'Home to Work' }),
        ]}
        selectedCommuteId="commute-2"
        onSelect={noop}
        onRename={noop}
        onDelete={noop}
        onAdd={noop}
      />,
    )

    const tabs = container.querySelectorAll('.commute-tab')
    expect(tabs).toHaveLength(2)
    expect(tabs[1].className).toContain('active')
    expect(tabs[0].className).not.toContain('active')
  })

  it('selects a commute when its name input is focused', async () => {
    const onSelect = vi.fn()
    render(
      <CommuteTabs
        commutes={[makeCommute({})]}
        selectedCommuteId={null}
        onSelect={onSelect}
        onRename={noop}
        onDelete={noop}
        onAdd={noop}
      />,
    )

    await userEvent.click(screen.getByLabelText('Commute name'))
    expect(onSelect).toHaveBeenCalledWith('commute-1')
  })

  it('renames a commute', () => {
    const onRename = vi.fn()
    render(
      <CommuteTabs
        commutes={[makeCommute({})]}
        selectedCommuteId="commute-1"
        onSelect={noop}
        onRename={onRename}
        onDelete={noop}
        onAdd={noop}
      />,
    )

    fireEvent.change(screen.getByLabelText('Commute name'), {
      target: { value: 'Evening commute' },
    })
    expect(onRename).toHaveBeenCalledWith('commute-1', 'Evening commute')
  })

  it('deletes a commute', async () => {
    const onDelete = vi.fn()
    render(
      <CommuteTabs
        commutes={[makeCommute({})]}
        selectedCommuteId="commute-1"
        onSelect={noop}
        onRename={noop}
        onDelete={onDelete}
        onAdd={noop}
      />,
    )

    await userEvent.click(screen.getByLabelText('Delete commute'))
    expect(onDelete).toHaveBeenCalledWith('commute-1')
  })

  it('calls onAdd from the new-commute button', async () => {
    const onAdd = vi.fn()
    render(
      <CommuteTabs
        commutes={[]}
        selectedCommuteId={null}
        onSelect={noop}
        onRename={noop}
        onDelete={noop}
        onAdd={onAdd}
      />,
    )

    await userEvent.click(screen.getByText('+ New commute'))
    expect(onAdd).toHaveBeenCalled()
  })
})
