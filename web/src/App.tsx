import { useEffect, useState } from 'react'
import { ApiError, getConfig, runNow, saveConfig } from './api/client'
import type { Config, LatLng, RunNowResponse } from './api/types'
import { CommuteTabs } from './commute-panel/CommuteTabs'
import { ScheduleEditor } from './commute-panel/ScheduleEditor'
import { MapView } from './map/MapView'
import { RoutePanel } from './routes-panel/RoutePanel'
import {
  addCommute,
  addRoute,
  addScheduleRule,
  addViaPoint,
  buildConfigPayload,
  deleteCommute,
  deleteRoute,
  fromConfig,
  initialState,
  moveRoute,
  moveViaPoint,
  recolorRoute,
  removeScheduleRule,
  removeViaPoint,
  renameCommute,
  renameRoute,
  selectCommute,
  setDestination,
  setMode,
  setOrigin,
  setPreviewError,
  setPreviewLoading,
  setPreviewResult,
  updateScheduleRule,
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

  const selectedCommute =
    state.commutes.find((c) => c.id === state.selectedCommuteId) ?? null

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
    if (!selectedCommute) return
    if (state.mode === 'settingOrigin') {
      setState((prev) =>
        setOrigin(prev, selectedCommute.id, { label: 'Work', ...point }),
      )
    } else if (state.mode === 'settingDestination') {
      setState((prev) =>
        setDestination(prev, selectedCommute.id, { label: 'Home', ...point }),
      )
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
    if (!selectedCommute) return
    setRunStatus('running')
    setRunError(null)
    try {
      const result = await runNow(selectedCommute.name)
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
          state={{
            origin: selectedCommute?.origin ?? null,
            destination: selectedCommute?.destination ?? null,
            routes: selectedCommute?.routes ?? [],
          }}
          onMapClick={handleMapClick}
          onAddViaPoint={(routeId, point, insertAt) => {
            if (!selectedCommute) return
            const commuteId = selectedCommute.id
            setState((prev) => addViaPoint(prev, commuteId, routeId, point, insertAt))
          }}
          onMoveViaPoint={(routeId, index, point) => {
            if (!selectedCommute) return
            const commuteId = selectedCommute.id
            setState((prev) => moveViaPoint(prev, commuteId, routeId, index, point))
          }}
          onRemoveViaPoint={(routeId, index) => {
            if (!selectedCommute) return
            const commuteId = selectedCommute.id
            setState((prev) => removeViaPoint(prev, commuteId, routeId, index))
          }}
        />
      </div>
      <div className="side-panel">
        <CommuteTabs
          commutes={state.commutes}
          selectedCommuteId={state.selectedCommuteId}
          onSelect={(id) => setState((prev) => selectCommute(prev, id))}
          onRename={(id, name) => setState((prev) => renameCommute(prev, id, name))}
          onDelete={(id) => setState((prev) => deleteCommute(prev, id))}
          onAdd={() => setState((prev) => addCommute(prev))}
        />

        {!selectedCommute && (
          <p className="status-message">Create a commute to get started.</p>
        )}

        {selectedCommute && (
          <>
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

            <ScheduleEditor
              schedules={selectedCommute.schedules}
              onAdd={() =>
                setState((prev) => addScheduleRule(prev, selectedCommute.id))
              }
              onUpdate={(index, rule) =>
                setState((prev) =>
                  updateScheduleRule(prev, selectedCommute.id, index, rule),
                )
              }
              onRemove={(index) =>
                setState((prev) => removeScheduleRule(prev, selectedCommute.id, index))
              }
            />

            <RoutePanel
              routes={selectedCommute.routes}
              origin={selectedCommute.origin}
              destination={selectedCommute.destination}
              onRename={(id, name) =>
                setState((prev) => renameRoute(prev, selectedCommute.id, id, name))
              }
              onRecolor={(id, color) =>
                setState((prev) => recolorRoute(prev, selectedCommute.id, id, color))
              }
              onDelete={(id) =>
                setState((prev) => deleteRoute(prev, selectedCommute.id, id))
              }
              onMoveUp={(id) =>
                setState((prev) => moveRoute(prev, selectedCommute.id, id, 'up'))
              }
              onMoveDown={(id) =>
                setState((prev) => moveRoute(prev, selectedCommute.id, id, 'down'))
              }
              onAddRoute={() => setState((prev) => addRoute(prev, selectedCommute.id))}
              onPreviewLoading={(id) =>
                setState((prev) => setPreviewLoading(prev, selectedCommute.id, id))
              }
              onPreviewSuccess={(id, polyline, distanceMeters) =>
                setState((prev) =>
                  setPreviewResult(
                    prev,
                    selectedCommute.id,
                    id,
                    polyline,
                    distanceMeters,
                  ),
                )
              }
              onPreviewError={(id, message) =>
                setState((prev) =>
                  setPreviewError(prev, selectedCommute.id, id, message),
                )
              }
            />
          </>
        )}

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
          disabled={runStatus === 'running' || !selectedCommute}
        >
          Send ETAs now
        </button>
        {runStatus === 'done' && runResult && (
          <ul className="run-result">
            {runResult.results.map((result) => {
              const color = selectedCommute?.routes.find(
                (r) => r.name === result.name,
              )?.color
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
