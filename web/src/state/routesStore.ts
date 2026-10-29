import type {
  Commute,
  Config,
  LatLng,
  NamedPoint,
  RouteDef,
  ScheduleRule,
} from '../api/types'
import type { BuilderState, CommuteUI, Mode, RouteUI } from './types'

const DEFAULT_COLORS = [
  '#2563eb',
  '#dc2626',
  '#16a34a',
  '#d97706',
  '#7c3aed',
  '#0891b2',
]

const DEFAULT_SCHEDULE_RULE: ScheduleRule = {
  weekdays: ['mon', 'tue', 'wed', 'thu', 'fri'],
  time: '18:30',
}

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

function toCommuteUI(commute: Commute): CommuteUI {
  return {
    id: createId(),
    name: commute.name,
    origin: commute.origin,
    destination: commute.destination,
    routes: commute.routes.map(toRouteUI),
    schedules: commute.schedules,
  }
}

function updateCommute(
  state: BuilderState,
  commuteId: string,
  fn: (commute: CommuteUI) => CommuteUI,
): BuilderState {
  return {
    ...state,
    commutes: state.commutes.map((c) => (c.id === commuteId ? fn(c) : c)),
  }
}

function updateRouteInCommute(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  fn: (route: RouteUI) => RouteUI,
): BuilderState {
  return updateCommute(state, commuteId, (c) => ({
    ...c,
    routes: c.routes.map((r) => (r.id === routeId ? fn(r) : r)),
  }))
}

export function initialState(): BuilderState {
  return { commutes: [], selectedCommuteId: null, mode: 'idle' }
}

export function fromConfig(config: Config): BuilderState {
  const commutes = config.commutes.map(toCommuteUI)
  return { commutes, selectedCommuteId: commutes[0]?.id ?? null, mode: 'idle' }
}

export function buildConfigPayload(state: BuilderState, base: Config): Config {
  return {
    ...base,
    commutes: state.commutes.map((c): Commute => ({
      name: c.name,
      origin: c.origin,
      destination: c.destination,
      routes: c.routes.map((r): RouteDef => ({
        name: r.name,
        color: r.color,
        via: r.via,
      })),
      schedules: c.schedules,
    })),
  }
}

export function setMode(state: BuilderState, mode: Mode): BuilderState {
  return { ...state, mode }
}

export function addCommute(state: BuilderState): BuilderState {
  const commute: CommuteUI = {
    id: createId(),
    name: `Commute ${state.commutes.length + 1}`,
    origin: null,
    destination: null,
    routes: [],
    schedules: [],
  }
  return {
    ...state,
    commutes: [...state.commutes, commute],
    selectedCommuteId: commute.id,
    mode: 'idle',
  }
}

export function renameCommute(
  state: BuilderState,
  commuteId: string,
  name: string,
): BuilderState {
  return updateCommute(state, commuteId, (c) => ({ ...c, name }))
}

export function deleteCommute(state: BuilderState, commuteId: string): BuilderState {
  const commutes = state.commutes.filter((c) => c.id !== commuteId)
  const selectedCommuteId =
    state.selectedCommuteId === commuteId
      ? (commutes[0]?.id ?? null)
      : state.selectedCommuteId
  return { ...state, commutes, selectedCommuteId, mode: 'idle' }
}

export function selectCommute(state: BuilderState, commuteId: string): BuilderState {
  return { ...state, selectedCommuteId: commuteId, mode: 'idle' }
}

export function setOrigin(
  state: BuilderState,
  commuteId: string,
  point: NamedPoint,
): BuilderState {
  return {
    ...updateCommute(state, commuteId, (c) => ({ ...c, origin: point })),
    mode: 'idle',
  }
}

export function setDestination(
  state: BuilderState,
  commuteId: string,
  point: NamedPoint,
): BuilderState {
  return {
    ...updateCommute(state, commuteId, (c) => ({ ...c, destination: point })),
    mode: 'idle',
  }
}

export function addRoute(state: BuilderState, commuteId: string): BuilderState {
  return updateCommute(state, commuteId, (c) => {
    const route: RouteUI = {
      id: createId(),
      name: `Route ${c.routes.length + 1}`,
      color: pickUnusedColor(c.routes),
      via: [],
      previewPolyline: null,
      previewStatus: 'idle',
    }
    return { ...c, routes: [...c.routes, route] }
  })
}

export function renameRoute(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  name: string,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => ({ ...r, name }))
}

export function recolorRoute(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  color: string,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => ({ ...r, color }))
}

export function deleteRoute(
  state: BuilderState,
  commuteId: string,
  routeId: string,
): BuilderState {
  return updateCommute(state, commuteId, (c) => ({
    ...c,
    routes: c.routes.filter((r) => r.id !== routeId),
  }))
}

export function moveRoute(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  direction: 'up' | 'down',
): BuilderState {
  return updateCommute(state, commuteId, (c) => {
    const index = c.routes.findIndex((r) => r.id === routeId)
    if (index === -1) return c
    const swapWith = direction === 'up' ? index - 1 : index + 1
    if (swapWith < 0 || swapWith >= c.routes.length) return c

    const routes = [...c.routes]
    const temp = routes[index]
    routes[index] = routes[swapWith]
    routes[swapWith] = temp
    return { ...c, routes }
  })
}

export function addViaPoint(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  point: LatLng,
  insertAt: number,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => {
    const via = [...r.via]
    via.splice(insertAt, 0, point)
    return { ...r, via }
  })
}

export function moveViaPoint(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  index: number,
  point: LatLng,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => {
    const via = [...r.via]
    via[index] = point
    return { ...r, via }
  })
}

export function removeViaPoint(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  index: number,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => ({
    ...r,
    via: r.via.filter((_, i) => i !== index),
  }))
}

export function setPreviewLoading(
  state: BuilderState,
  commuteId: string,
  routeId: string,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => ({
    ...r,
    previewStatus: 'loading',
  }))
}

export function setPreviewResult(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  polyline: LatLng[],
  distanceMeters: number,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => ({
    ...r,
    previewPolyline: polyline,
    previewStatus: 'idle',
    previewError: undefined,
    previewDistanceMeters: distanceMeters,
  }))
}

export function setPreviewError(
  state: BuilderState,
  commuteId: string,
  routeId: string,
  error: string,
): BuilderState {
  return updateRouteInCommute(state, commuteId, routeId, (r) => ({
    ...r,
    previewStatus: 'error',
    previewError: error,
  }))
}

export function addScheduleRule(state: BuilderState, commuteId: string): BuilderState {
  return updateCommute(state, commuteId, (c) => ({
    ...c,
    schedules: [...c.schedules, { ...DEFAULT_SCHEDULE_RULE }],
  }))
}

export function updateScheduleRule(
  state: BuilderState,
  commuteId: string,
  index: number,
  rule: ScheduleRule,
): BuilderState {
  return updateCommute(state, commuteId, (c) => {
    const schedules = [...c.schedules]
    schedules[index] = rule
    return { ...c, schedules }
  })
}

export function removeScheduleRule(
  state: BuilderState,
  commuteId: string,
  index: number,
): BuilderState {
  return updateCommute(state, commuteId, (c) => ({
    ...c,
    schedules: c.schedules.filter((_, i) => i !== index),
  }))
}
