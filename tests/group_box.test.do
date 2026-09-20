import { Assert } from "std/assert"
import { parseJsonValue } from "std/json"
import { LayoutRect, layout, measureLayout } from "std/layout"
import { GroupBox, Row, ScrollView, Text, TextField, View } from "../index"
import { syncUI } from "../runtime"

function place(view: View, width: double = 400.0, height: double = 240.0): none {
  view.prepareLayout()
  layout(view.layoutNode(), LayoutRect { width, height })
}

function snapshot(view: View): SerialObject {
  return try! parseJsonValue(view.nativeView().groupBoxSnapshot()) as SerialObject
}

function number(object: SerialObject, key: string): double {
  return try! object.get(key)! as double
}

function assertNativeChildrenFit(view: View, count: int): none {
  data := snapshot(view)
  children := try! data.get("children")! as readonly SerialValue[]
  Assert.equal(children.length, count)
  Assert.equal(data.get("flipped")!, true)
  for value of children {
    child := try! value as SerialObject
    Assert.isTrue(number(child, "x") >= -0.01)
    Assert.isTrue(number(child, "y") >= -0.01)
    Assert.isTrue(number(child, "x") + number(child, "width") <= number(data, "contentWidth") + 0.01)
    Assert.isTrue(number(child, "y") + number(child, "height") <= number(data, "contentHeight") + 0.01)
  }
}

export function testGroupBoxMeasuresNativeChromeAndPlacesChildren(): none {
  first := Text("First")
  second := TextField("Name")
  box := GroupBox{title: "Account", children: [first, second], gap: 12.0}
  box.prepareLayout()
  measured := measureLayout(box.layoutNode())
  padding := box.layoutNode().style.padding
  Assert.isTrue(padding.top > 0.0)
  Assert.isTrue(padding.left > 0.0)
  Assert.isTrue(measured.height > measureLayout(first.layoutNode()).height + measureLayout(second.layoutNode()).height)
  place(box, 420.0, measured.height)
  Assert.approxEqual(first.layoutNode().layoutBounds().y, padding.top)
  Assert.approxEqual(second.layoutNode().layoutBounds().y,
    first.layoutNode().layoutBounds().bottom() + 12.0)
  assertNativeChildrenFit(box, 2)
  data := snapshot(box)
  children := try! data.get("children")! as readonly SerialValue[]
  child := try! children[0] as SerialObject
  Assert.approxEqual(number(child, "x"), 0.0)
  Assert.approxEqual(number(child, "y"), 0.0)
  Assert.equal(data.get("role")!, "AXGroup")
}

export function testGroupBoxReactiveTitleVisibilityAndAccessibility(): none {
  let title = "Short"
  let hidden = false
  box := <GroupBox title=>title hidden=>hidden accessibilityLabel="Account preferences">
    <Text value="Content"/>
  </GroupBox>
  originalWidth := box.layoutNode().style.minWidth
  title = "A much longer group title that must contribute to minimum width"
  syncUI()
  Assert.isTrue(box.layoutNode().style.minWidth > originalWidth)
  Assert.equal(snapshot(box).get("title")!, title)
  Assert.equal(snapshot(box).get("label")!, "Account preferences")
  root := Row([box, Text("Sibling")])
  hidden = true
  syncUI()
  place(root, 900.0)
  Assert.equal(root.layoutNode().children.length, 1)
  Assert.equal(snapshot(box).get("hidden")!, true)
}

export function testGroupBoxNestingGrowthAndResizing(): none {
  inner := <GroupBox title="Nested"><Text value="Inside"/></GroupBox>
  left := GroupBox{title: "Left", children: [inner], grow: 1.0}
  right := GroupBox{title: "Right", children: [Text("Other")], grow: 1.0}
  root := Row([left, right])
  for width of [600.0, 900.0] {
    place(root, width)
    // Each box retains its title minimum, then receives an equal share.
    Assert.approxEqual(
      left.layoutNode().layoutBounds().width - left.layoutNode().style.minWidth,
      right.layoutNode().layoutBounds().width - right.layoutNode().style.minWidth)
    Assert.approxEqual(left.layoutNode().layoutBounds().width +
      right.layoutNode().layoutBounds().width + root.layoutNode().style.gap, width)
    assertNativeChildrenFit(left, 1)
    assertNativeChildrenFit(right, 1)
    assertNativeChildrenFit(inner, 1)
  }
}

export function testGroupBoxSupportsChildMutationAndEmptyContent(): none {
  first := Text("First")
  second := Text("Second")
  replacement := Text("Replacement")
  box := GroupBox("Items")
  place(box)
  assertNativeChildrenFit(box, 0)
  box.append(second).insertBefore(first, second).replace(replacement, second)
  place(box)
  assertNativeChildrenFit(box, 2)
  Assert.equal(box.layoutNode().children[0], first.layoutNode())
  Assert.equal(box.layoutNode().children[1], replacement.layoutNode())
  first.detach()
  place(box)
  assertNativeChildrenFit(box, 1)
  replacement.dispose()
  place(box)
  assertNativeChildrenFit(box, 0)
}

export function testGroupBoxRejectsNegativeLayoutOptions(): none {
  case catchPanic(=> GroupBox{title: "Invalid", gap: -1.0}) {
    _: Success -> Assert.fail("expected invalid gap to panic")
    failure: Failure -> Assert.stringContains(failure.error, "gap")
  }
  case catchPanic(=> GroupBox{title: "Invalid", grow: -1.0}) {
    _: Success -> Assert.fail("expected invalid growth to panic")
    failure: Failure -> Assert.stringContains(failure.error, "grow")
  }
}

export function testGroupBoxUntitledAndReactiveTitlePreserveNativeInsets(): none {
  let title = ""
  child := Text("Content")
  box := GroupBox{title: =>title, children: [child]}
  for next of ["", "Preferences", "A much longer title for the preferences group", ""] {
    title = next
    syncUI()
    box.prepareLayout()
    padding := box.layoutNode().style.padding
    Assert.isTrue(padding.top >= 0.0)
    Assert.isTrue(padding.right >= 0.0)
    Assert.isTrue(padding.bottom >= 0.0)
    Assert.isTrue(padding.left >= 0.0)
    measured := measureLayout(box.layoutNode())
    place(box, measured.width, measured.height)
    assertNativeChildrenFit(box, 1)
    Assert.equal(snapshot(box).get("title")!, title)
    Assert.approxEqual(number(snapshot(box), "contentWidth"),
      measured.width - padding.left - padding.right)
    Assert.approxEqual(number(snapshot(box), "contentHeight"),
      measured.height - padding.top - padding.bottom)
  }
  empty := GroupBox("")
  empty.prepareLayout()
  measured := measureLayout(empty.layoutNode())
  place(empty, measured.width, measured.height)
  assertNativeChildrenFit(empty, 0)
}

export function testGroupBoxScrollDocumentAndRestoredVisibility(): none {
  let hidden = false
  first := Text("First")
  second := Text("Second").hidden(=>hidden)
  box := GroupBox{title: "Scrollable", children: [first, second], gap: 120.0}
  scroll := ScrollView([box])
  place(scroll, 320.0, 80.0)
  Assert.isTrue(box.layoutNode().layoutBounds().height > 80.0)
  assertNativeChildrenFit(box, 2)
  hidden = true
  syncUI()
  place(scroll, 320.0, 80.0)
  Assert.equal(box.layoutNode().children.length, 1)
  hidden = false
  syncUI()
  place(scroll, 480.0, 80.0)
  Assert.equal(box.layoutNode().children.length, 2)
  assertNativeChildrenFit(box, 2)
}
