import { Assert } from "std/assert"
import { OutlineView } from "../index"

class Lifetime {
  let released = 0
}
class TrackedRow {
  lifetime: Lifetime
  destructor { lifetime.released += 1 }
}

function releaseOutline(lifetime: Lifetime): none {
  view := OutlineView<TrackedRow>{rows: [TrackedRow { lifetime }],
    rowKey: =>"row", children: =>[], label: =>"Row"}
  view.asView().dispose()
}

export function testOutlineDisposalReleasesRowsAfterOwnerLeavesScope(): none {
  lifetime := Lifetime {}
  releaseOutline(lifetime)
  Assert.equal(lifetime.released, 1)
}

export function testOutlineReloadReleasesOldRows(): none {
  lifetime := Lifetime {}
  view := OutlineView<TrackedRow>{rows: [TrackedRow { lifetime }],
    rowKey: =>"row", children: =>[], label: =>"Row"}
  view.select("row")
  view.reload([])
  Assert.equal(lifetime.released, 1)
  Assert.equal(view.selected(), none)
  view.asView().dispose()
}

export function testOutlineCanDisposeInsideSelectionCallback(): none {
  lifetime := Lifetime {}
  let current: OutlineView<TrackedRow> | none = none
  let changes = 0
  view := OutlineView<TrackedRow>{rows: [TrackedRow { lifetime }],
    rowKey: =>"row", children: =>[], label: =>"Row", onSelect: (row): none => {
      current!.asView().dispose()
      // Continue using callback captures after disposal clears native callbacks.
      changes += 1
      Assert.equal(row!.lifetime, lifetime)
    }}
  current = view
  view.asView().nativeView().performOutlineSelection(0)
  Assert.equal(changes, 1)
  Assert.equal(view.selected(), none)
  current = none
}
