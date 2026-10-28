import { Polyline } from 'react-leaflet'
import type { LeafletMouseEvent } from 'leaflet'
import type { LatLng } from '../api/types'
import type { RouteUI } from '../state/types'
import { findViaInsertionIndex } from './polylineGeometry'
import { useOffsetPositions } from './routeOffset'
import { ViaPointHandle } from './ViaPointHandle'

interface Props {
  route: RouteUI
  offsetPx: [number, number]
  onAddViaPoint: (point: LatLng, insertAt: number) => void
  onMoveViaPoint: (index: number, point: LatLng) => void
  onRemoveViaPoint: (index: number) => void
}

export function RouteLayer({
  route,
  offsetPx,
  onAddViaPoint,
  onMoveViaPoint,
  onRemoveViaPoint,
}: Props) {
  const polyline = route.previewPolyline
  const positions = useOffsetPositions(polyline, offsetPx)
  if (!polyline || polyline.length === 0) return null

  function handlePolylineClick(e: LeafletMouseEvent) {
    const clickPoint: LatLng = { lat: e.latlng.lat, lng: e.latlng.lng }
    const insertAt = findViaInsertionIndex(clickPoint, polyline!, route.via)
    onAddViaPoint(clickPoint, insertAt)
  }

  return (
    <>
      <Polyline
        positions={positions}
        pathOptions={{ color: route.color, weight: 5 }}
        eventHandlers={{ click: handlePolylineClick }}
      />
      {route.via.map((point, index) => (
        <ViaPointHandle
          // via points have no stable id; position in the ordered array is
          // the identity the rest of the app addresses them by.
          key={index}
          point={point}
          color={route.color}
          onMove={(newPoint) => onMoveViaPoint(index, newPoint)}
          onRemove={() => onRemoveViaPoint(index)}
        />
      ))}
    </>
  )
}
