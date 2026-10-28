import type { LatLng, NamedPoint, RouteDef } from '../api/types'

export type PreviewStatus = 'idle' | 'loading' | 'error'

export interface RouteUI extends RouteDef {
  id: string
  previewPolyline: LatLng[] | null
  previewStatus: PreviewStatus
  previewError?: string
  previewDistanceMeters?: number
}

export type Mode = 'idle' | 'settingOrigin' | 'settingDestination'

export interface BuilderState {
  origin: NamedPoint | null
  destination: NamedPoint | null
  routes: RouteUI[]
  mode: Mode
}
