import { NativeView } from "./native"
import { OutlineData, OutlineSnapshot } from "./outline_data"
import { syncUI } from "./runtime"
import { View, ViewElement, growingControl } from "./view"

// A native, single-column tree. AppKit owns disclosure, scrolling, focus,
// keyboard navigation, and selection; Doof owns the typed data snapshot.
export class OutlineView<Row> implements ViewElement {
  private data: OutlineData<Row>
  private native: NativeView
  private content: View

  static constructor(
    rows: Row[],
    rowKey: (row: Row): string,
    children: (row: Row): Row[],
    label: (row: Row): string,
    onSelect: (row: Row | none): none = (row: Row | none): none => {},
    hidden: bool | ((): bool) = false,
    accessibilityLabel: string = "",
    accessibilityHelp: string = "",
    accessibilityIdentifier: string = "",
  ): OutlineView<Row> {
    data := OutlineData<Row> { snapshot: OutlineSnapshot<Row> {}, rowKey, children, label }
    data.snapshot = data.build(rows)
    native := NativeView.outlineView()
    content := growingControl(native).hidden(hidden)
      .accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
    native.setOutlineData(
      (index): string => data.labelAt(index),
      (index): none => { onSelect(data.rowAt(index)); syncUI() },
    )
    native.reloadOutline(data.snapshot.keys, data.snapshot.parents)
    return OutlineView<Row> { data, native, content }
  }

  asView(): View => content
  rowCount(): int => data.snapshot.rows.length
  selected(): Row | none => data.rowAt(native.outlineSelectedIndex())

  // Validate the entire replacement before changing the live view.
  reload(rows: Row[]): none {
    next := data.build(rows)
    data.snapshot = next
    native.reloadOutline(next.keys, next.parents)
  }

  // Programmatic selection reveals ancestors and does not invoke onSelect.
  select(key: string | none): none {
    value := key as string else { native.selectOutline(""); return }
    data.requireKey(value)
    native.selectOutline(value)
  }

  expand(key: string, recursive: bool = false): none {
    data.requireKey(key)
    native.expandOutline(key, recursive)
  }

  collapse(key: string, recursive: bool = false): none {
    data.requireKey(key)
    native.collapseOutline(key, recursive)
  }
}
