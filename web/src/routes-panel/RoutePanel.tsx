import type { LatLng, NamedPoint } from '../api/types'
import type { RouteUI } from '../state/types'
import { NewRouteButton } from './NewRouteButton'
import { RouteListItem } from './RouteListItem'

interface Props {
  routes: RouteUI[]
  origin: NamedPoint | null
  destination: NamedPoint | null
  onRename: (id: string, name: string) => void
  onRecolor: (id: string, color: string) => void
  onDelete: (id: string) => void
  onMoveUp: (id: string) => void
  onMoveDown: (id: string) => void
  onAddRoute: () => void
  onPreviewLoading: (id: string) => void
  onPreviewSuccess: (id: string, polyline: LatLng[], distanceMeters: number) => void
  onPreviewError: (id: string, message: string) => void
}

export function RoutePanel({
  routes,
  origin,
  destination,
  onRename,
  onRecolor,
  onDelete,
  onMoveUp,
  onMoveDown,
  onAddRoute,
  onPreviewLoading,
  onPreviewSuccess,
  onPreviewError,
}: Props) {
  return (
    <div className="route-panel">
      <ul>
        {routes.map((route, index) => (
          <RouteListItem
            key={route.id}
            route={route}
            origin={origin}
            destination={destination}
            canMoveUp={index > 0}
            canMoveDown={index < routes.length - 1}
            onRename={(name) => onRename(route.id, name)}
            onRecolor={(color) => onRecolor(route.id, color)}
            onDelete={() => onDelete(route.id)}
            onMoveUp={() => onMoveUp(route.id)}
            onMoveDown={() => onMoveDown(route.id)}
            onPreviewLoading={() => onPreviewLoading(route.id)}
            onPreviewSuccess={(polyline, distanceMeters) =>
              onPreviewSuccess(route.id, polyline, distanceMeters)
            }
            onPreviewError={(message) => onPreviewError(route.id, message)}
          />
        ))}
      </ul>
      <NewRouteButton onClick={onAddRoute} />
    </div>
  )
}
