import { MapContainer, TileLayer, useMapEvents } from 'react-leaflet'
import type { LatLng, NamedPoint } from '../api/types'
import type { RouteUI } from '../state/types'
import { OriginDestinationMarkers } from './OriginDestinationMarkers'
import { RouteCasing } from './RouteCasing'
import { RouteLayer } from './RouteLayer'
import { offsetForIndex } from './routeOffset'

// Mexico City — just a sensible default center before an origin is set.
const DEFAULT_CENTER: LatLng = { lat: 19.4326, lng: -99.1332 }
const DEFAULT_ZOOM = 12

// The selected commute's editable slice — MapView never needs the full
// commute list or which one is selected, just what it's currently drawing.
export interface MapViewState {
  origin: NamedPoint | null
  destination: NamedPoint | null
  routes: RouteUI[]
}

interface Props {
  state: MapViewState
  onMapClick: (point: LatLng) => void
  onAddViaPoint: (routeId: string, point: LatLng, insertAt: number) => void
  onMoveViaPoint: (routeId: string, index: number, point: LatLng) => void
  onRemoveViaPoint: (routeId: string, index: number) => void
}

function ClickHandler({ onClick }: { onClick: (point: LatLng) => void }) {
  useMapEvents({
    click(e) {
      onClick({ lat: e.latlng.lat, lng: e.latlng.lng })
    },
  })
  return null
}

export function MapView({
  state,
  onMapClick,
  onAddViaPoint,
  onMoveViaPoint,
  onRemoveViaPoint,
}: Props) {
  const center = state.origin ?? DEFAULT_CENTER

  return (
    <MapContainer
      center={[center.lat, center.lng]}
      zoom={DEFAULT_ZOOM}
      style={{ height: '100%', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <ClickHandler onClick={onMapClick} />
      <OriginDestinationMarkers origin={state.origin} destination={state.destination} />
      {/* Casings painted in their own pass, before any colored line, so one
          route's casing never covers another route's color at an overlap. */}
      {state.routes.map((route, index) => (
        <RouteCasing
          key={`${route.id}-casing`}
          polyline={route.previewPolyline}
          offsetPx={offsetForIndex(index)}
        />
      ))}
      {state.routes.map((route, index) => (
        <RouteLayer
          key={route.id}
          route={route}
          offsetPx={offsetForIndex(index)}
          onAddViaPoint={(point, insertAt) => onAddViaPoint(route.id, point, insertAt)}
          onMoveViaPoint={(index2, point) => onMoveViaPoint(route.id, index2, point)}
          onRemoveViaPoint={(index2) => onRemoveViaPoint(route.id, index2)}
        />
      ))}
    </MapContainer>
  )
}
