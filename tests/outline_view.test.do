import { Assert } from "std/assert"
import { parseJsonValue } from "std/json"
import { LayoutRect, layout } from "std/layout"
import { OutlineView, Row, Tab, TabView, Text } from "../index"
import { syncUI } from "../runtime"

class Node {
  id: string
  let name: string
  nodes: Node[] = []
}
function tree(): Node[] {
  return [Node { id: "root", name: "Project", nodes: [
    Node { id: "folder", name: "Sources", nodes: [Node { id: "file", name: "main.do" }] },
    Node { id: "readme", name: "README.md" },
  ] }, Node { id: "other", name: "Other" }]
}
function outline(rows: Node[]): OutlineView<Node> {
  return OutlineView<Node>{rows, rowKey: =>row.id, children: =>row.nodes, label: =>row.name}
}
function snapshot(view: OutlineView<Node>): SerialObject {
  return try! parseJsonValue(view.asView().nativeView().outlineSnapshot()) as SerialObject
}
function visibleKeys(view: OutlineView<Node>): readonly string[] {
  rows := try! snapshot(view).get("rows")! as readonly SerialValue[]
  let keys: string[] = []
  for value of rows {
    row := try! value as SerialObject
    keys.push(try! row.get("key")! as string)
  }
  return keys.drainToReadonly()
}

export function testOutlineViewHierarchyExpansionAndSelection(): none {
  view := outline(tree())
  Assert.equal(view.rowCount(), 5)
  Assert.arrayEqual(visibleKeys(view), ["root", "other"])
  Assert.equal(snapshot(view).get("role")!, "AXOutline")
  view.expand("root")
  Assert.arrayEqual(visibleKeys(view), ["root", "folder", "readme", "other"])
  view.expand("folder")
  Assert.arrayEqual(visibleKeys(view), ["root", "folder", "file", "readme", "other"])
  view.collapse("root", true)
  Assert.arrayEqual(visibleKeys(view), ["root", "other"])
  view.select("file")
  Assert.equal(view.selected()!.id, "file")
  Assert.arrayEqual(visibleKeys(view), ["root", "folder", "file", "readme", "other"])
  view.select(none)
  Assert.equal(view.selected(), none)
  view.collapse("root", true)
  view.expand("root", true)
  Assert.equal(visibleKeys(view).length, 5)
}

export function testOutlineViewNativeSelectionCallbacksAndDisposal(): none {
  let selected = ""
  let changes = 0
  view := OutlineView<Node>{rows: tree(), rowKey: =>row.id, children: =>row.nodes, label: =>row.name,
    accessibilityLabel: "Project files", onSelect: (row): none => {
      changes += 1
      node := row as Node else { selected = ""; return }
      selected = node.id
    }}
  Assert.equal(snapshot(view).get("label")!, "Project files")
  view.select("other")
  Assert.equal(changes, 0)
  view.asView().nativeView().performOutlineSelection(0)
  Assert.equal(selected, "root")
  Assert.equal(changes, 1)
  view.asView().nativeView().performOutlineSelection(-1)
  Assert.equal(selected, "")
  Assert.equal(changes, 2)
  view.asView().dispose()
  view.asView().nativeView().performOutlineSelection(0)
  Assert.equal(changes, 2)
  Assert.equal(view.selected(), none)
}

export function testOutlineViewReloadPreservesKeysAcrossReplacementAndReparenting(): none {
  view := outline(tree())
  view.expand("root", true)
  view.select("file")
  next := tree()
  next[0].nodes[0].nodes[0].name = "renamed.do"
  view.reload([next[1], next[0]])
  Assert.arrayEqual(visibleKeys(view), ["other", "root", "folder", "file", "readme"])
  Assert.equal(view.selected(), next[0].nodes[0].nodes[0])
  Assert.equal(view.selected()!.name, "renamed.do")
  moved := Node { id: "new-parent", name: "Moved", nodes: [next[0].nodes[0].nodes[0]] }
  view.reload([moved])
  Assert.arrayEqual(visibleKeys(view), ["new-parent", "file"])
  Assert.equal(view.selected()!.id, "file")
  view.reload([])
  Assert.equal(view.rowCount(), 0)
  Assert.equal(visibleKeys(view).length, 0)
  Assert.equal(view.selected(), none)
  view.reload(tree())
  Assert.arrayEqual(visibleKeys(view), ["root", "other"])
}

export function testOutlineViewInvalidTreesDoNotReplaceLiveData(): none {
  view := outline(tree())
  duplicate := Node { id: "duplicate", name: "Duplicate" }
  case catchPanic(=> view.reload([duplicate, duplicate])) {
    _: Success -> Assert.fail("expected duplicate key error")
    failure: Failure -> Assert.stringContains(failure.error, "unique")
  }
  cycle := Node { id: "cycle", name: "Cycle" }
  cycle.nodes.push(cycle)
  case catchPanic(=> view.reload([cycle])) {
    _: Success -> Assert.fail("expected cycle error")
    failure: Failure -> Assert.stringContains(failure.error, "cycle")
  }
  try! cycle.nodes.pop()
  case catchPanic(=> view.reload([Node { id: "", name: "Empty key" }])) {
    _: Success -> Assert.fail("expected empty key error")
    failure: Failure -> Assert.stringContains(failure.error, "empty")
  }
  case catchPanic(=> view.select("missing")) {
    _: Success -> Assert.fail("expected unknown key error")
    failure: Failure -> Assert.stringContains(failure.error, "not found")
  }
  Assert.equal(view.rowCount(), 5)
  Assert.arrayEqual(visibleKeys(view), ["root", "other"])
}

export function testOutlineViewLayoutVisibilityAndExplicitReload(): none {
  let hidden = false
  let labelCalls = 0
  data := tree()
  view := OutlineView<Node>{rows: data, rowKey: =>row.id, children: =>row.nodes,
    label: (row): string => { labelCalls += 1; return row.name }, hidden: =>hidden}
  calls := labelCalls
  syncUI()
  Assert.equal(labelCalls, calls)
  root := Row([view, Text("Sibling")])
  root.prepareLayout()
  layout(root.layoutNode(), LayoutRect { width: 700.0, height: 300.0 })
  Assert.isTrue(view.asView().layoutNode().layoutBounds().width > 0.0)
  hidden = true
  syncUI()
  root.prepareLayout()
  Assert.equal(root.layoutNode().children.length, 1)
  hidden = false
  syncUI()
  root.prepareLayout()
  Assert.equal(root.layoutNode().children.length, 2)
  tabs := TabView([Tab("Files", [outline([])])])
  tabs.prepareLayout()
  layout(tabs.layoutNode(), LayoutRect { width: 500.0, height: 200.0 })
}
