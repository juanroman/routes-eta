import { useEffect, useRef } from 'react'
import { ApiError, previewRoute } from '../api/client'
import type { LatLng, NamedPoint } from '../api/types'

const DEBOUNCE_MS = 400

export interface RoutePreviewCallbacks {
  onLoading: () => void
  onSuccess: (polyline: LatLng[], distanceMeters: number) => void
  onError: (message: string) => void
}

/**
 * Debounces a preview call whenever a route's geometry (origin, destination
 * or via points) changes. Label/color/order edits never reach this hook, so
 * they never trigger a Google call.
 */
export function useRoutePreview(
  origin: NamedPoint | null,
  destination: NamedPoint | null,
  via: LatLng[],
  callbacks: RoutePreviewCallbacks,
): void {
  const callbacksRef = useRef(callbacks)
  useEffect(() => {
    callbacksRef.current = callbacks
  })

  const viaKey = JSON.stringify(via)

  useEffect(() => {
    if (!origin || !destination) return

    const timer = setTimeout(() => {
      callbacksRef.current.onLoading()
      previewRoute({ origin, destination, via })
        .then((result) => {
          callbacksRef.current.onSuccess(
            result.polyline.map(([lat, lng]) => ({ lat, lng })),
            result.distance_meters,
          )
        })
        .catch((err: unknown) => {
          const message = err instanceof ApiError ? err.message : 'Preview failed'
          callbacksRef.current.onError(message)
        })
    }, DEBOUNCE_MS)

    return () => clearTimeout(timer)
    // via is compared by its serialized value (viaKey) rather than identity.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [origin, destination, viaKey])
}
