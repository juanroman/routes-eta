import { useRef } from 'react'
import L from 'leaflet'
import type { Marker as LeafletMarker } from 'leaflet'
import { Marker, Popup } from 'react-leaflet'
import type { LatLng } from '../api/types'

interface Props {
  point: LatLng
  color: string
  onMove: (point: LatLng) => void
  onRemove: () => void
}

// Large hit target per prd.md FR-10 (touch-friendly handles).
function viaPointIcon(color: string): L.DivIcon {
  return L.divIcon({
    className: 'via-point-handle',
    html: `<span style="background:${color}"></span>`,
    iconSize: [28, 28],
  })
}

export function ViaPointHandle({ point, color, onMove, onRemove }: Props) {
  const markerRef = useRef<LeafletMarker>(null)

  return (
    <Marker
      position={[point.lat, point.lng]}
      draggable
      icon={viaPointIcon(color)}
      ref={markerRef}
      eventHandlers={{
        dragend: () => {
          const marker = markerRef.current
          if (!marker) return
          const { lat, lng } = marker.getLatLng()
          onMove({ lat, lng })
        },
      }}
    >
      <Popup>
        <button type="button" onClick={onRemove}>
          Remove point
        </button>
      </Popup>
    </Marker>
  )
}
