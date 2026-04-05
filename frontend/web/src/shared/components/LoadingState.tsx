type LoadingStateProps = {
  label?: string
}

export function LoadingState({ label = 'Đang tải dữ liệu...' }: LoadingStateProps) {
  return (
    <div className='loading-state'>
      <span className='loading-dot' />
      <span>{label}</span>
    </div>
  )
}
