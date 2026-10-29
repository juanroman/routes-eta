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

export interface ScheduleRule {
  weekdays: Weekday[]
  time: string
}

export interface RouteDef {
  name: string
  color: string
  via: LatLng[]
}

export interface Commute {
  name: string
  origin: NamedPoint | null
  destination: NamedPoint | null
  routes: RouteDef[]
  schedules: ScheduleRule[]
}

export interface Config {
  timezone: string
  commutes: Commute[]
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
  commute: string
  message: string
  results: RouteResult[]
}
