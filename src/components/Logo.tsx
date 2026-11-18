import { MARK_ACCENT, MARK_DIAL_PATH, MARK_KEY_PATH, MARK_VIEW_BOX } from './logoMark'

interface LogoProps {
  size?: number
  style?: React.CSSProperties
}

// The dial follows the text colour; the key notch keeps its teal.
export default function Logo({ size = 24, style }: LogoProps) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox={MARK_VIEW_BOX}
      width={size}
      height={size}
      style={style}
      aria-hidden="true"
    >
      <path d={MARK_DIAL_PATH} fill="currentColor" />
      <path d={MARK_KEY_PATH} fill={MARK_ACCENT} />
    </svg>
  )
}
