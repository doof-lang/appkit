import { NativeView } from "./native"
import { bindString, initialString, syncUI } from "./runtime"
import { Tint } from "./types"
import { View, measuredControl } from "./view"

// A large button with a tinted symbol badge and a wrapping title, for choosing
// between a few destinations. It keeps native keyboard activation, focus, and
// accessibility, and highlights on hover.
export function Tile(
  title: string | ((): string),
  symbol: string = "",
  tint: Tint = .Accent,
  onClick: (): none = (): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  toolTip: string = "",
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  native := NativeView.tile(initialString(title))
  native.setTile(tint.value, symbol)
  native.setToolTip(toolTip)
  view := measuredControl(native)
  bindString(title, (next): none => native.setText(next))
  native.setAction((value: string, checked: bool): none => { onClick(); syncUI() })
  view.enabled(enabled).hidden(hidden).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return view
}
