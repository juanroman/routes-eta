// Leaflet's default marker icon resolves its image URLs relative to the
// stylesheet, which breaks under Vite bundling. This re-points them at the
// bundled asset URLs. Side-effecting module — import once (in main.tsx) for
// its effect, not its (empty) exports.
import L from 'leaflet'
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png'
import markerIcon from 'leaflet/dist/images/marker-icon.png'
import markerShadow from 'leaflet/dist/images/marker-shadow.png'

interface IconDefaultPrototype {
  _getIconUrl?: string
}

delete (L.Icon.Default.prototype as unknown as IconDefaultPrototype)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow,
})
