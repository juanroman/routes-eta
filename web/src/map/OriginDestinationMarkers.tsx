import { Marker, Popup } from 'react-leaflet'
import type { NamedPoint } from '../api/types'

interface Props {
  origin: NamedPoint | null
  destination: NamedPoint | null
}

export function OriginDestinationMarkers({ origin, destination }: Props) {
  return (
    <>
      {origin && (
        <Marker position={[origin.lat, origin.lng]}>
          <Popup>{origin.label}</Popup>
        </Marker>
      )}
      {destination && (
        <Marker position={[destination.lat, destination.lng]}>
          <Popup>{destination.label}</Popup>
        </Marker>
      )}
    </>
  )
}
