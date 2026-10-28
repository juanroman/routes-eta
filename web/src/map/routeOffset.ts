import { useEffect, useState } from 'react'
import L from 'leaflet'
import { useMap } from 'react-leaflet'
import type { LatLng } from '../api/types'

// Small, constant on-screen pixel nudges per route (by its position in the
// routes list). Invisible when routes are far apart; separates them into
// parallel lines exactly where they'd otherwise sit on the same road.
const OFFSETS_PX: [number, number][] = [
  [0, 0],
  [4, 0],
  [-4, 0],
  [0, 4],
  [0, -4],
]

export function offsetForIndex(index: number): [number, number] {
  return OFFSETS_PX[index % OFFSETS_PX.length]
}

/**
 * Nudges a route's polyline by a constant on-screen pixel amount, using the
 * map's own projection so the offset stays a fixed screen distance across
 * zoom levels. Pan doesn't require recomputation — project/unproject work in
 * per-zoom pixel space, independent of the current viewport.
 */
export function useOffsetPositions(
  polyline: LatLng[] | null,
  offsetPx: [number, number],
): [number, number][] {
  const map = useMap()
  const [zoom, setZoom] = useState(() => map.getZoom())

  useEffect(() => {
    function handleZoomEnd() {
      setZoom(map.getZoom())
    }
    map.on('zoomend', handleZoomEnd)
    return () => {
      map.off('zoomend', handleZoomEnd)
    }
  }, [map])

  if (!polyline) return []

  const [dx, dy] = offsetPx
  if (dx === 0 && dy === 0) {
    return polyline.map((p): [number, number] => [p.lat, p.lng])
  }

  return polyline.map((p): [number, number] => {
    const point = map.project([p.lat, p.lng], zoom)
    const shifted = L.point(point.x + dx, point.y + dy)
    const latLng = map.unproject(shifted, zoom)
    return [latLng.lat, latLng.lng]
  })
}
