import type { LatLng, NamedPoint } from '../api/types'
import { useRoutePreview } from '../hooks/useRoutePreview'
import type { RouteUI } from '../state/types'

interface Props {
  route: RouteUI
  origin: NamedPoint | null
  destination: NamedPoint | null
  canMoveUp: boolean
  canMoveDown: boolean
  onRename: (name: string) => void
  onRecolor: (color: string) => void
  onDelete: () => void
  onMoveUp: () => void
  onMoveDown: () => void
  onPreviewLoading: () => void
  onPreviewSuccess: (polyline: LatLng[], distanceMeters: number) => void
  onPreviewError: (message: string) => void
}

export function RouteListItem({
  route,
  origin,
  destination,
  canMoveUp,
  canMoveDown,
  onRename,
  onRecolor,
  onDelete,
  onMoveUp,
  onMoveDown,
  onPreviewLoading,
  onPreviewSuccess,
  onPreviewError,
}: Props) {
  useRoutePreview(origin, destination, route.via, {
    onLoading: onPreviewLoading,
    onSuccess: onPreviewSuccess,
    onError: onPreviewError,
  })

  return (
    <li className="route-list-item">
      <span className="route-color-swatch" style={{ background: route.color }} />
      <input
        aria-label="Route name"
        value={route.name}
        onChange={(e) => onRename(e.target.value)}
      />
      <input
        aria-label="Route color"
        type="color"
        value={route.color}
        onChange={(e) => onRecolor(e.target.value)}
      />
      <span className="route-status">
        {route.previewStatus === 'loading' && 'Updating…'}
        {route.previewStatus === 'error' && `Error: ${route.previewError}`}
        {route.previewStatus === 'idle' &&
          route.previewDistanceMeters != null &&
          `${(route.previewDistanceMeters / 1000).toFixed(1)} km`}
      </span>
      <button
        type="button"
        onClick={onMoveUp}
        disabled={!canMoveUp}
        aria-label="Move up"
      >
        {'↑'}
      </button>
      <button
        type="button"
        onClick={onMoveDown}
        disabled={!canMoveDown}
        aria-label="Move down"
      >
        {'↓'}
      </button>
      <button type="button" onClick={onDelete} aria-label="Delete route">
        Delete
      </button>
    </li>
  )
}
