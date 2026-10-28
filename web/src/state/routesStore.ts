import type { Config, LatLng, NamedPoint, RouteDef } from '../api/types'
import type { BuilderState, Mode, RouteUI } from './types'

const DEFAULT_COLORS = [
  '#2563eb',
  '#dc2626',
  '#16a34a',
  '#d97706',
  '#7c3aed',
  '#0891b2',
]

function createId(): string {
  return crypto.randomUUID()
}

function pickUnusedColor(routes: RouteUI[]): string {
  const used = new Set(routes.map((r) => r.color))
  return DEFAULT_COLORS.find((c) => !used.has(c)) ?? DEFAULT_COLORS[0]
}

function toRouteUI(route: RouteDef): RouteUI {
  return {
    ...route,
    id: createId(),
    previewPolyline: null,
    previewStatus: 'idle',
  }
}

function updateRoute(
  state: BuilderState,
  id: string,
  fn: (route: RouteUI) => RouteUI,
): BuilderState {
  return {
    ...state,
    routes: state.routes.map((r) => (r.id === id ? fn(r) : r)),
  }
}

export function initialState(): BuilderState {
  return { origin: null, destination: null, routes: [], mode: 'idle' }
}

export function fromConfig(config: Config): BuilderState {
  return {
    origin: config.origin,
    destination: config.destination,
    routes: config.routes.map(toRouteUI),
    mode: 'idle',
  }
}

export function buildConfigPayload(state: BuilderState, base: Config): Config {
  return {
    ...base,
    origin: state.origin,
    destination: state.destination,
    routes: state.routes.map((r): RouteDef => ({
      name: r.name,
      color: r.color,
      via: r.via,
    })),
  }
}

export function setMode(state: BuilderState, mode: Mode): BuilderState {
  return { ...state, mode }
}

export function setOrigin(state: BuilderState, point: NamedPoint): BuilderState {
  return { ...state, origin: point, mode: 'idle' }
}

export function setDestination(state: BuilderState, point: NamedPoint): BuilderState {
  return { ...state, destination: point, mode: 'idle' }
}

export function addRoute(state: BuilderState): BuilderState {
  const route: RouteUI = {
    id: createId(),
    name: `Route ${state.routes.length + 1}`,
    color: pickUnusedColor(state.routes),
    via: [],
    previewPolyline: null,
    previewStatus: 'idle',
  }
  return { ...state, routes: [...state.routes, route] }
}

export function renameRoute(
  state: BuilderState,
  id: string,
  name: string,
): BuilderState {
  return updateRoute(state, id, (r) => ({ ...r, name }))
}

export function recolorRoute(
  state: BuilderState,
  id: string,
  color: string,
): BuilderState {
  return updateRoute(state, id, (r) => ({ ...r, color }))
}

export function deleteRoute(state: BuilderState, id: string): BuilderState {
  return { ...state, routes: state.routes.filter((r) => r.id !== id) }
}

export function moveRoute(
  state: BuilderState,
  id: string,
  direction: 'up' | 'down',
): BuilderState {
  const index = state.routes.findIndex((r) => r.id === id)
  if (index === -1) return state
  const swapWith = direction === 'up' ? index - 1 : index + 1
  if (swapWith < 0 || swapWith >= state.routes.length) return state

  const routes = [...state.routes]
  const temp = routes[index]
  routes[index] = routes[swapWith]
  routes[swapWith] = temp
  return { ...state, routes }
}

export function addViaPoint(
  state: BuilderState,
  routeId: string,
  point: LatLng,
  insertAt: number,
): BuilderState {
  return updateRoute(state, routeId, (r) => {
    const via = [...r.via]
    via.splice(insertAt, 0, point)
    return { ...r, via }
  })
}

export function moveViaPoint(
  state: BuilderState,
  routeId: string,
  index: number,
  point: LatLng,
): BuilderState {
  return updateRoute(state, routeId, (r) => {
    const via = [...r.via]
    via[index] = point
    return { ...r, via }
  })
}

export function removeViaPoint(
  state: BuilderState,
  routeId: string,
  index: number,
): BuilderState {
  return updateRoute(state, routeId, (r) => ({
    ...r,
    via: r.via.filter((_, i) => i !== index),
  }))
}

export function setPreviewLoading(state: BuilderState, routeId: string): BuilderState {
  return updateRoute(state, routeId, (r) => ({ ...r, previewStatus: 'loading' }))
}

export function setPreviewResult(
  state: BuilderState,
  routeId: string,
  polyline: LatLng[],
  distanceMeters: number,
): BuilderState {
  return updateRoute(state, routeId, (r) => ({
    ...r,
    previewPolyline: polyline,
    previewStatus: 'idle',
    previewError: undefined,
    previewDistanceMeters: distanceMeters,
  }))
}

export function setPreviewError(
  state: BuilderState,
  routeId: string,
  error: string,
): BuilderState {
  return updateRoute(state, routeId, (r) => ({
    ...r,
    previewStatus: 'error',
    previewError: error,
  }))
}
