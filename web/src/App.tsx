import { useEffect, useState } from 'react'
import { ApiError, getConfig, runNow, saveConfig } from './api/client'
import type { Config, LatLng, RunNowResponse } from './api/types'
import { MapView } from './map/MapView'
import { RoutePanel } from './routes-panel/RoutePanel'
import {
  addRoute,
  addViaPoint,
  buildConfigPayload,
  deleteRoute,
  fromConfig,
  initialState,
  moveRoute,
  moveViaPoint,
  recolorRoute,
  removeViaPoint,
  renameRoute,
  setDestination,
  setMode,
  setOrigin,
  setPreviewError,
  setPreviewLoading,
  setPreviewResult,
} from './state/routesStore'
import type { BuilderState } from './state/types'

type LoadStatus = 'loading' | 'ready' | 'error'
type SaveStatus = 'idle' | 'saving' | 'saved' | 'error'
type RunStatus = 'idle' | 'running' | 'done' | 'error'

function App() {
  const [state, setState] = useState<BuilderState>(initialState())
  const [baseConfig, setBaseConfig] = useState<Config | null>(null)
  const [loadStatus, setLoadStatus] = useState<LoadStatus>('loading')
  const [saveStatus, setSaveStatus] = useState<SaveStatus>('idle')
  const [saveError, setSaveError] = useState<string | null>(null)
  const [runStatus, setRunStatus] = useState<RunStatus>('idle')
  const [runResult, setRunResult] = useState<RunNowResponse | null>(null)
  const [runError, setRunError] = useState<string | null>(null)

  useEffect(() => {
    getConfig()
      .then((config) => {
        setBaseConfig(config)
        setState(fromConfig(config))
        setLoadStatus('ready')
      })
      .catch(() => setLoadStatus('error'))
  }, [])

  function handleMapClick(point: LatLng) {
    if (state.mode === 'settingOrigin') {
      setState((prev) => setOrigin(prev, { label: 'Work', ...point }))
    } else if (state.mode === 'settingDestination') {
      setState((prev) => setDestination(prev, { label: 'Home', ...point }))
    }
  }

  async function handleSave() {
    if (!baseConfig) return
    setSaveStatus('saving')
    setSaveError(null)
    try {
      const saved = await saveConfig(buildConfigPayload(state, baseConfig))
      setBaseConfig(saved)
      setSaveStatus('saved')
    } catch (err) {
      setSaveStatus('error')
      setSaveError(err instanceof ApiError ? err.message : 'Save failed')
    }
  }

  async function handleRunNow() {
    setRunStatus('running')
    setRunError(null)
    try {
      const result = await runNow()
      setRunStatus('done')
      setRunResult(result)
    } catch (err) {
      setRunStatus('error')
      setRunError(err instanceof ApiError ? err.message : 'Could not send ETAs')
    }
  }

  if (loadStatus === 'loading') return <p>Loading…</p>
  if (loadStatus === 'error') return <p>Could not load the config from the API.</p>

  return (
    <div className="app-layout">
      <div className="map-pane">
        <MapView
          state={state}
          onMapClick={handleMapClick}
          onAddViaPoint={(routeId, point, insertAt) =>
            setState((prev) => addViaPoint(prev, routeId, point, insertAt))
          }
          onMoveViaPoint={(routeId, index, point) =>
            setState((prev) => moveViaPoint(prev, routeId, index, point))
          }
          onRemoveViaPoint={(routeId, index) =>
            setState((prev) => removeViaPoint(prev, routeId, index))
          }
        />
      </div>
      <div className="side-panel">
        <div className="origin-destination-controls">
          <button
            type="button"
            className={state.mode === 'settingOrigin' ? 'active' : ''}
            onClick={() => setState((prev) => setMode(prev, 'settingOrigin'))}
          >
            Set origin here
          </button>
          <button
            type="button"
            className={state.mode === 'settingDestination' ? 'active' : ''}
            onClick={() => setState((prev) => setMode(prev, 'settingDestination'))}
          >
            Set destination here
          </button>
        </div>

        <RoutePanel
          routes={state.routes}
          origin={state.origin}
          destination={state.destination}
          onRename={(id, name) => setState((prev) => renameRoute(prev, id, name))}
          onRecolor={(id, color) => setState((prev) => recolorRoute(prev, id, color))}
          onDelete={(id) => setState((prev) => deleteRoute(prev, id))}
          onMoveUp={(id) => setState((prev) => moveRoute(prev, id, 'up'))}
          onMoveDown={(id) => setState((prev) => moveRoute(prev, id, 'down'))}
          onAddRoute={() => setState((prev) => addRoute(prev))}
          onPreviewLoading={(id) => setState((prev) => setPreviewLoading(prev, id))}
          onPreviewSuccess={(id, polyline, distanceMeters) =>
            setState((prev) => setPreviewResult(prev, id, polyline, distanceMeters))
          }
          onPreviewError={(id, message) =>
            setState((prev) => setPreviewError(prev, id, message))
          }
        />

        <button
          type="button"
          onClick={() => void handleSave()}
          disabled={saveStatus === 'saving'}
        >
          Save
        </button>
        {saveStatus === 'saved' && <p className="status-message">Saved.</p>}
        {saveStatus === 'error' && (
          <p className="status-message error">Could not save: {saveError}</p>
        )}

        <button
          type="button"
          onClick={() => void handleRunNow()}
          disabled={runStatus === 'running'}
        >
          Send ETAs now
        </button>
        {runStatus === 'done' && runResult && (
          <ul className="run-result">
            {runResult.results.map((result) => {
              const color = state.routes.find((r) => r.name === result.name)?.color
              const failed = result.minutes === null
              return (
                <li
                  key={result.name}
                  className={`run-result-chip${failed ? ' failed' : ''}`}
                  title={failed ? (result.error ?? undefined) : undefined}
                >
                  <span className="route-color-swatch" style={{ background: color }} />
                  <span>{result.name}</span>
                  <span className="eta">{failed ? '?' : `${result.minutes} min`}</span>
                </li>
              )
            })}
          </ul>
        )}
        {runStatus === 'error' && (
          <p className="status-message error">Could not send ETAs: {runError}</p>
        )}
      </div>
    </div>
  )
}

export default App
