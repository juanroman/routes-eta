import type { Config, PreviewRequest, PreviewResponse } from './types'

export class ApiError extends Error {}

interface ErrorBody {
  detail?: string
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`/api${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  })

  if (!response.ok) {
    const body: ErrorBody | null = await response.json().catch(() => null)
    throw new ApiError(
      body?.detail ?? `Request to ${path} failed with status ${response.status}`,
    )
  }

  return response.json() as Promise<T>
}

export function getConfig(): Promise<Config> {
  return request<Config>('/config')
}

export function saveConfig(config: Config): Promise<Config> {
  return request<Config>('/config', {
    method: 'PUT',
    body: JSON.stringify(config),
  })
}

export function previewRoute(req: PreviewRequest): Promise<PreviewResponse> {
  return request<PreviewResponse>('/preview', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}
