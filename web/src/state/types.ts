import type { LatLng, NamedPoint, RouteDef, ScheduleRule } from '../api/types'

export type PreviewStatus = 'idle' | 'loading' | 'error'

export interface RouteUI extends RouteDef {
  id: string
  previewPolyline: LatLng[] | null
  previewStatus: PreviewStatus
  previewError?: string
  previewDistanceMeters?: number
}

export type Mode = 'idle' | 'settingOrigin' | 'settingDestination'

export interface CommuteUI {
  id: string
  name: string
  origin: NamedPoint | null
  destination: NamedPoint | null
  routes: RouteUI[]
  schedules: ScheduleRule[]
}

export interface BuilderState {
  commutes: CommuteUI[]
  selectedCommuteId: string | null
  mode: Mode
}
