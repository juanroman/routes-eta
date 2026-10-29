import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ScheduleEditor } from './ScheduleEditor'
import type { ScheduleRule } from '../api/types'

const noop = () => {}

describe('ScheduleEditor', () => {
  it('renders one row per schedule rule with the weekday toggles reflecting state', () => {
    const schedules: ScheduleRule[] = [{ weekdays: ['mon', 'wed'], time: '06:30' }]
    render(
      <ScheduleEditor
        schedules={schedules}
        onAdd={noop}
        onUpdate={noop}
        onRemove={noop}
      />,
    )

    expect(screen.getByLabelText('mon')).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getByLabelText('tue')).toHaveAttribute('aria-pressed', 'false')
    expect(screen.getByLabelText('Schedule time')).toHaveValue('06:30')
  })

  it('toggles a weekday on', () => {
    const onUpdate = vi.fn()
    const schedules: ScheduleRule[] = [{ weekdays: ['mon'], time: '06:30' }]
    render(
      <ScheduleEditor
        schedules={schedules}
        onAdd={noop}
        onUpdate={onUpdate}
        onRemove={noop}
      />,
    )

    fireEvent.click(screen.getByLabelText('tue'))
    expect(onUpdate).toHaveBeenCalledWith(0, {
      weekdays: ['mon', 'tue'],
      time: '06:30',
    })
  })

  it('toggles a weekday off', () => {
    const onUpdate = vi.fn()
    const schedules: ScheduleRule[] = [{ weekdays: ['mon', 'tue'], time: '06:30' }]
    render(
      <ScheduleEditor
        schedules={schedules}
        onAdd={noop}
        onUpdate={onUpdate}
        onRemove={noop}
      />,
    )

    fireEvent.click(screen.getByLabelText('mon'))
    expect(onUpdate).toHaveBeenCalledWith(0, { weekdays: ['tue'], time: '06:30' })
  })

  it('updates the time', () => {
    const onUpdate = vi.fn()
    const schedules: ScheduleRule[] = [{ weekdays: ['mon'], time: '06:30' }]
    render(
      <ScheduleEditor
        schedules={schedules}
        onAdd={noop}
        onUpdate={onUpdate}
        onRemove={noop}
      />,
    )

    fireEvent.change(screen.getByLabelText('Schedule time'), {
      target: { value: '07:00' },
    })
    expect(onUpdate).toHaveBeenCalledWith(0, { weekdays: ['mon'], time: '07:00' })
  })

  it('removes a rule', async () => {
    const onRemove = vi.fn()
    const schedules: ScheduleRule[] = [{ weekdays: ['mon'], time: '06:30' }]
    render(
      <ScheduleEditor
        schedules={schedules}
        onAdd={noop}
        onUpdate={noop}
        onRemove={onRemove}
      />,
    )

    await userEvent.click(screen.getByLabelText('Remove schedule'))
    expect(onRemove).toHaveBeenCalledWith(0)
  })

  it('calls onAdd from the add-schedule button', async () => {
    const onAdd = vi.fn()
    render(
      <ScheduleEditor schedules={[]} onAdd={onAdd} onUpdate={noop} onRemove={noop} />,
    )

    await userEvent.click(screen.getByText('+ Add schedule'))
    expect(onAdd).toHaveBeenCalled()
  })
})
