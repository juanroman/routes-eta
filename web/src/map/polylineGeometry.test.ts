import { describe, expect, it } from 'vitest'
import { findViaInsertionIndex, nearestIndexOnPolyline } from './polylineGeometry'
import type { LatLng } from '../api/types'

const STRAIGHT_LINE: LatLng[] = [
  { lat: 0, lng: 0 },
  { lat: 0, lng: 1 },
  { lat: 0, lng: 2 },
  { lat: 0, lng: 3 },
]

describe('nearestIndexOnPolyline', () => {
  it('finds the closest vertex', () => {
    expect(nearestIndexOnPolyline({ lat: 0, lng: 0.1 }, STRAIGHT_LINE)).toBe(0)
    expect(nearestIndexOnPolyline({ lat: 0, lng: 2.9 }, STRAIGHT_LINE)).toBe(3)
    expect(nearestIndexOnPolyline({ lat: 0, lng: 1.6 }, STRAIGHT_LINE)).toBe(2)
  })
})

describe('findViaInsertionIndex', () => {
  it('inserts at the start when before all existing via points', () => {
    const existingVia: LatLng[] = [{ lat: 0, lng: 2 }]
    const insertAt = findViaInsertionIndex(
      { lat: 0, lng: 0.5 },
      STRAIGHT_LINE,
      existingVia,
    )
    expect(insertAt).toBe(0)
  })

  it('inserts at the end when after all existing via points', () => {
    const existingVia: LatLng[] = [{ lat: 0, lng: 0.5 }]
    const insertAt = findViaInsertionIndex(
      { lat: 0, lng: 2.5 },
      STRAIGHT_LINE,
      existingVia,
    )
    expect(insertAt).toBe(1)
  })

  it('inserts in the middle between two existing via points', () => {
    const existingVia: LatLng[] = [
      { lat: 0, lng: 0.2 },
      { lat: 0, lng: 2.8 },
    ]
    const insertAt = findViaInsertionIndex(
      { lat: 0, lng: 1.5 },
      STRAIGHT_LINE,
      existingVia,
    )
    expect(insertAt).toBe(1)
  })

  it('returns 0 for an empty via list', () => {
    expect(findViaInsertionIndex({ lat: 0, lng: 1 }, STRAIGHT_LINE, [])).toBe(0)
  })
})
