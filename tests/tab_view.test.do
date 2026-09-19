import { Assert } from "std/assert"
import { parseJsonValue } from "std/json"
import { LayoutRect, layout, measureLayout } from "std/layout"
import { GroupBox, Row, ScrollView, Tab, TabView, Text, TextField, View } from "../index"
import { syncUI } from "../runtime"

function place(view: View, width: double = 500.0, height: double = 300.0): none {
  view.prepareLayout()
  layout(view.layoutNode(), LayoutRect { width, height })
}
function snapshot(view: View): SerialObject {
  return try! parseJsonValue(view.nativeView().tabSnapshot()) as SerialObject
}
function number(value: SerialObject, key: string): double { return try! value.get(key)! as double }
function selected(view: View): int { return int(number(snapshot(view), "selectedIndex")) }
function assertPage(view: View, index: int): none {
  items := try! snapshot(view).get("items")! as SerialValue[]
  for i of 0..<items.length {
    item := try! items[i] as SerialObject
    Assert.equal(item.get("attached")!, i == index)
    Assert.equal(item.get("flipped")!, true)
    if i == index {
      Assert.approxEqual(number(item, "childX"), 0.0)
      Assert.approxEqual(number(item, "childY"), 0.0)
      Assert.approxEqual(number(item, "childWidth"), number(item, "width"))
      Assert.approxEqual(number(item, "childHeight"), number(item, "height"))
      Assert.isTrue(number(item, "width") > 0.0)
      Assert.isTrue(number(item, "height") > 0.0)
    }
  }
}

export function testTabViewInitialSelectionAndNativeContentGeometry(): none {
  tabs := <TabView selectedIndex=1 accessibilityLabel="Preferences">
    <Tab title="General"><Text value="General content"/></Tab>
    <Tab title="Account"><TextField label="Name"/></Tab>
  </TabView>
  place(tabs)
  Assert.equal(selected(tabs), 1)
  assertPage(tabs, 1)
  Assert.equal(snapshot(tabs).get("label")!, "Preferences")
  Assert.equal(snapshot(tabs).get("role")!, "AXTabGroup")
  place(tabs, 700.0, 450.0)
  assertPage(tabs, 1)
}

export function testTabViewReactiveAndNativeSelectionPreserveContents(): none {
  let index = 0
  let changes = 0
  first := Tab("First", [TextField("Name")])
  second := Tab("Second", [Text("Other")])
  tabs := TabView{children: [first, second], selectedIndex: =>index,
    onChange: (next): none => { index = next; changes += 1 }}
  place(tabs)
  index = 1
  syncUI()
  Assert.equal(selected(tabs), 1)
  Assert.equal(changes, 0)
  assertPage(tabs, 1)
  first.content.append(Text("Added while inactive"))
  tabs.nativeView().performTabSelection(0)
  Assert.equal(index, 0)
  Assert.equal(changes, 1)
  Assert.equal(first.content.layoutNode().children.length, 2)
  assertPage(tabs, 0)
  tabs.nativeView().performTabSelection(0)
  Assert.equal(changes, 1)
  tabs.nativeView().performTabSelection(1)
  tabs.nativeView().performTabSelection(0)
  Assert.equal(first.content.layoutNode().children.length, 2)
}

export function testTabViewMeasuresAllPagesAndReactiveTitles(): none {
  let title = "A"
  short := Tab{title: =>title, children: [Text("Small")]}
  tall := Tab("B", [Text("One"), Text("Two"), Text("Three")], 30.0)
  tabs := TabView([short, tall])
  tabs.prepareLayout()
  before := measureLayout(tabs.layoutNode())
  place(tabs, before.width, before.height)
  tabs.nativeView().performTabSelection(1)
  after := measureLayout(tabs.layoutNode())
  Assert.approxEqual(before.width, after.width)
  Assert.approxEqual(before.height, after.height)
  Assert.isTrue(before.height > measureLayout(tall.content.layoutNode()).height)
  title = "A very long tab label that contributes to the tab strip minimum width"
  syncUI()
  Assert.isTrue(measureLayout(tabs.layoutNode()).width > before.width)
  items := try! snapshot(tabs).get("items")! as SerialValue[]
  item := try! items[0] as SerialObject
  Assert.equal(item.get("title")!, title)
}

export function testTabViewNestingVisibilityAndDisposal(): none {
  let hidden = false
  let changes = 0
  nested := <TabView><Tab title="Nested"><Text value="Inside"/></Tab></TabView>
  tabs := TabView{children: [Tab("Main", [GroupBox("Group", [nested])]),
    Tab("Scroll", [ScrollView([Text("Document")])])], hidden: =>hidden,
    onChange: (index): none => { changes += 1 }}
  root := Row([tabs, Text("Sibling")])
  place(root, 800.0, 500.0)
  assertPage(tabs, 0)
  assertPage(nested, 0)
  hidden = true
  syncUI()
  place(root)
  Assert.equal(root.layoutNode().children.length, 1)
  hidden = false
  syncUI()
  place(root, 800.0, 500.0)
  Assert.equal(root.layoutNode().children.length, 2)
  tabs.nativeView().performTabSelection(1)
  assertPage(tabs, 1)
  tabs.dispose()
  tabs.nativeView().performTabSelection(0)
  Assert.equal(changes, 1)
  place(root)
  Assert.equal(root.layoutNode().children.length, 1)
}

export function testTabViewRejectsInvalidConstruction(): none {
  case catchPanic(=> TabView([])) {
    _: Success -> Assert.fail("expected empty tabs to panic")
    failure: Failure -> Assert.stringContains(failure.error, "at least one")
  }
  for index of [-1, 1] {
    case catchPanic(=> TabView{children: [Tab("Only")], selectedIndex: index}) {
      _: Success -> Assert.fail("expected invalid index to panic")
      failure: Failure -> Assert.stringContains(failure.error, "out of range")
    }
  }
  case catchPanic(=> TabView{children: [Tab("Only")], grow: -1.0}) {
    _: Success -> Assert.fail("expected invalid growth to panic")
    failure: Failure -> Assert.stringContains(failure.error, "grow")
  }
  tab := Tab("Repeated")
  case catchPanic(=> TabView([tab, tab])) {
    _: Success -> Assert.fail("expected duplicate content to panic")
    failure: Failure -> Assert.stringContains(failure.error, "reuse")
  }
}
