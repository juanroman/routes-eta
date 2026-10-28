import { Polyline } from 'react-leaflet'
import type { LatLng } from '../api/types'
import { useOffsetPositions } from './routeOffset'

interface Props {
  polyline: LatLng[] | null
  offsetPx: [number, number]
}

// White casing drawn under every route's colored line, in its own render
// pass before any colored line, so overlapping routes interleave instead of
// one route's casing blotting out another's color (prd.md risk: routes that
// share a road should stay visually separable).
export function RouteCasing({ polyline, offsetPx }: Props) {
  const positions = useOffsetPositions(polyline, offsetPx)
  if (positions.length === 0) return null

  return <Polyline positions={positions} pathOptions={{ color: 'white', weight: 9 }} />
}
