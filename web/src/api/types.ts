// Mirrors api/app/config_models.py and api/app/schemas.py.

export interface LatLng {
  lat: number
  lng: number
}

export interface NamedPoint {
  label: string
  lat: number
  lng: number
}

export type Weekday = 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun'

export interface Schedule {
  weekdays: Weekday[]
  time: string
}

export interface RouteDef {
  name: string
  color: string
  via: LatLng[]
}

export interface Config {
  timezone: string
  schedule: Schedule
  origin: NamedPoint | null
  destination: NamedPoint | null
  routes: RouteDef[]
}

export interface PreviewRequest {
  origin: LatLng
  destination: LatLng
  via: LatLng[]
}

export interface PreviewResponse {
  distance_meters: number
  polyline: [number, number][]
}

export interface RouteResult {
  name: string
  minutes: number | null
  error: string | null
}

export interface RunNowResponse {
  message: string
  results: RouteResult[]
}
