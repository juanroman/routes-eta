import type { CommuteUI } from '../state/types'

interface Props {
  commutes: CommuteUI[]
  selectedCommuteId: string | null
  onSelect: (id: string) => void
  onRename: (id: string, name: string) => void
  onDelete: (id: string) => void
  onAdd: () => void
}

export function CommuteTabs({
  commutes,
  selectedCommuteId,
  onSelect,
  onRename,
  onDelete,
  onAdd,
}: Props) {
  return (
    <div className="commute-tabs">
      <ul>
        {commutes.map((commute) => (
          <li
            key={commute.id}
            className={`commute-tab${commute.id === selectedCommuteId ? ' active' : ''}`}
          >
            <input
              aria-label="Commute name"
              value={commute.name}
              onFocus={() => onSelect(commute.id)}
              onChange={(e) => onRename(commute.id, e.target.value)}
            />
            <button
              type="button"
              onClick={() => onDelete(commute.id)}
              aria-label="Delete commute"
            >
              Delete
            </button>
          </li>
        ))}
      </ul>
      <button type="button" onClick={onAdd}>
        + New commute
      </button>
    </div>
  )
}
