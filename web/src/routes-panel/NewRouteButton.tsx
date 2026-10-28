interface Props {
  onClick: () => void
}

export function NewRouteButton({ onClick }: Props) {
  return (
    <button type="button" className="new-route-button" onClick={onClick}>
      + New route
    </button>
  )
}
