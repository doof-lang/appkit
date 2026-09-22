import { LayoutEdges, LayoutStyle } from "std/layout"

import { NativeView } from "./native"
import { bindString, initialString } from "./runtime"
import { View, ViewElement, layoutContainer } from "./view"

// The native content insets participate in ordinary layout measurement, so a
// group sizes to its children and can grow, nest, or scroll like a Column.
export function GroupBox(
  title: string | ((): string),
  children: ViewElement[] = [],
  gap: double = 8.0,
  grow: double = 0.0,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
  padding: double = 0.0,
): View {
  if gap < 0.0 { panic("GroupBox gap cannot be negative") }
  if grow < 0.0 { panic("GroupBox grow cannot be negative") }
  if padding < 0.0 { panic("GroupBox padding cannot be negative") }
  native := NativeView.groupBox(initialString(title))
  style := LayoutStyle { direction: .Column, gap, grow }
  if grow > 0.0 { style.flexBasis = 0.0 }
  view := layoutContainer(native, style)
  bindString(title, (next): none => {
    native.setText(next)
    metrics := native.groupBoxMetrics()
    style.padding = LayoutEdges {
      top: metrics[0] + padding, right: metrics[1] + padding,
      bottom: metrics[2] + padding, left: metrics[3] + padding,
    }
    style.minWidth = metrics[4] + 2.0 * padding
  })
  for child of children { view.append(child.asView()) }
  return view.hidden(hidden)
    .accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
}
