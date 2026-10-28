import type { LatLng } from '../api/types'

// Squared distance is enough to compare "which vertex is closer" on the small,
// local scale this app operates at — no need for true geodesic distance.
function squaredDistance(a: LatLng, b: LatLng): number {
  const dLat = a.lat - b.lat
  const dLng = a.lng - b.lng
  return dLat * dLat + dLng * dLng
}

export function nearestIndexOnPolyline(point: LatLng, polyline: LatLng[]): number {
  let bestIndex = 0
  let bestDistance = Infinity
  polyline.forEach((vertex, index) => {
    const distance = squaredDistance(point, vertex)
    if (distance < bestDistance) {
      bestDistance = distance
      bestIndex = index
    }
  })
  return bestIndex
}

/**
 * Google returns one combined polyline per route, not segmented per via
 * point, so a newly-clicked via point's position in `via[]` is found by
 * comparing its nearest-vertex index against the existing via points'
 * nearest-vertex indices.
 */
export function findViaInsertionIndex(
  clickPoint: LatLng,
  polyline: LatLng[],
  existingVia: LatLng[],
): number {
  const clickIndex = nearestIndexOnPolyline(clickPoint, polyline)
  const viaIndices = existingVia.map((p) => nearestIndexOnPolyline(p, polyline))

  let insertAt = 0
  for (const viaIndex of viaIndices) {
    if (viaIndex <= clickIndex) {
      insertAt++
    } else {
      break
    }
  }
  return insertAt
}
