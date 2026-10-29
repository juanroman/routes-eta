import type { ScheduleRule, Weekday } from '../api/types'

const WEEKDAYS: { day: Weekday; label: string }[] = [
  { day: 'mon', label: 'M' },
  { day: 'tue', label: 'T' },
  { day: 'wed', label: 'W' },
  { day: 'thu', label: 'T' },
  { day: 'fri', label: 'F' },
  { day: 'sat', label: 'S' },
  { day: 'sun', label: 'S' },
]

interface Props {
  schedules: ScheduleRule[]
  onAdd: () => void
  onUpdate: (index: number, rule: ScheduleRule) => void
  onRemove: (index: number) => void
}

function toggleWeekday(rule: ScheduleRule, day: Weekday): ScheduleRule {
  const weekdays = rule.weekdays.includes(day)
    ? rule.weekdays.filter((d) => d !== day)
    : [...rule.weekdays, day]
  return { ...rule, weekdays }
}

export function ScheduleEditor({ schedules, onAdd, onUpdate, onRemove }: Props) {
  return (
    <div className="schedule-editor">
      <ul>
        {schedules.map((rule, index) => (
          <li key={index} className="schedule-rule">
            <div className="schedule-rule-weekdays">
              {WEEKDAYS.map(({ day, label }) => (
                <button
                  key={day}
                  type="button"
                  aria-label={day}
                  aria-pressed={rule.weekdays.includes(day)}
                  className={rule.weekdays.includes(day) ? 'active' : ''}
                  onClick={() => onUpdate(index, toggleWeekday(rule, day))}
                >
                  {label}
                </button>
              ))}
            </div>
            <input
              aria-label="Schedule time"
              type="time"
              value={rule.time}
              onChange={(e) => onUpdate(index, { ...rule, time: e.target.value })}
            />
            <button
              type="button"
              onClick={() => onRemove(index)}
              aria-label="Remove schedule"
            >
              Remove
            </button>
          </li>
        ))}
      </ul>
      <button type="button" onClick={onAdd}>
        + Add schedule
      </button>
    </div>
  )
}
