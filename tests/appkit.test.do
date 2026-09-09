import { Assert } from "std/assert"
import { parseJsonValue } from "std/json"
import { LayoutRect, layout } from "std/layout"
import { Date } from "std/time"

import { AlertStyle, Axis, Color, FileDialogOptions } from "../types"
import { Alert, AlertAction } from "../alert"
import { setAppMenus } from "../app"
import { Picker, ProgressBar, SecureTextField, Slider, Text } from "../controls"
import { SearchField, SegmentedControl, Separator, Spinner, Stepper, Switch } from "../additional_controls"
import { bindString, syncUI } from "../runtime"
import { NativeApplication, NativeWindow } from "../native"
import { ColorWell, ComboBox, DatePicker, RadioGroup, TextArea } from "../form_controls"
import { CheckboxColumn, DateColumn, NumberColumn, Table, TextColumn } from "../table"
import { Sheet, SheetAction, prepareSheet } from "../sheet"
import {
  ApplicationMenu,
  CopyMenuItem,
  HelpMenu,
  Menu,
  MenuItem,
  MenuModifier,
  MenuSeparator,
  MenuShortcut,
  ServicesMenu,
  StandardApplicationMenu,
  StandardEditMenu,
  StandardWindowMenu,
  WindowMenu,
  defaultAppMenus,
  installAppMenus,
  prepareAppMenus,
} from "../menu"
import { Toolbar, ToolbarFlexibleSpace, ToolbarItem, ToolbarSpace } from "../toolbar"
import { ImageCanvas, ImageCanvasBackground } from "../image_canvas"
import { Column, Row, SplitView } from "../view"

class TableTestRow {
  id: string
  name: string
  active: bool
  let score: double = 0.0
  let joined: Date = try! Date.parse("2026-01-01")
}

export function testImageCanvasParticipatesInLayout(): none {
  canvas := ImageCanvas()
  view := canvas.asView()
  Assert.equal(view.layoutNode().style.minHeight, 240.0)
  canvas.setBackground(ImageCanvasBackground.White)
  canvas.setBackground(ImageCanvasBackground.Black)
  canvas.setBackground(ImageCanvasBackground.Checker)
  canvas.zoomIn()
  canvas.zoomOut()
  canvas.actualSize()
  canvas.fit()
}

export function testSliderCanRequestAUsableGrowingTrack(): none {
  slider := <Slider minWidth=160.0 grow=1.0/>
  Assert.equal(slider.layoutNode().style.minWidth, 160.0)
  Assert.equal(slider.layoutNode().style.flexBasis, 160.0)
  Assert.equal(slider.layoutNode().style.grow, 1.0)
}

export function testAlertDefaultsToInformationalAcknowledgement(): none {
  alert := Alert("Finished")
  primary := alert.primary as AlertAction else { panic("expected a default alert action") }
  Assert.equal(alert.message, "")
  Assert.equal(alert.style, AlertStyle.Informational)
  Assert.equal(primary.title, "OK")
  Assert.equal(alert.alternatives.length, 0)
  Assert.equal(alert.cancel, none)
}

export function testAlertActionsSupportCallbacksAndDestructiveStyling(): none {
  let clicked = false
  action := AlertAction {
    title: "Delete",
    onClick: (): none => { clicked = true },
    destructive: true,
  }
  handler := action.onClick as ((): none) else { panic("expected an alert action callback") }
  handler()
  Assert.isTrue(clicked)
  Assert.isTrue(action.destructive)
}

export function testAlertCanOmitItsPrimaryAction(): none {
  alert := Alert {
    title: "Delete everything?",
    primary: none,
    alternatives: [AlertAction { title: "Delete", destructive: true }],
    cancel: AlertAction("Cancel"),
  }
  Assert.equal(alert.primary, none)
  Assert.equal(alert.alternatives.length, 1)
  Assert.isTrue(alert.alternatives[0].destructive)
  cancel := alert.cancel as AlertAction else { panic("expected a cancel action") }
  Assert.equal(cancel.title, "Cancel")
}

export function testSheetDefaultsToDoneAndUsesLayoutContent(): none {
  sheet := <Sheet title="Profile" width=420 height=240>
    <Text value="Edit your profile"/>
  </Sheet>
  primary := sheet.primary as SheetAction else { panic("expected a default sheet action") }
  Assert.equal(primary.title, "Done")
  Assert.equal(sheet.width, 420)
  Assert.equal(sheet.height, 240)
  sheet.relayout(420.0, 180.0)
  Assert.equal(sheet.contentView().layoutNode().children.length, 1)
}

export function testSheetValidationCanKeepTheSheetOpen(): none {
  let valid = false
  let clicked = false
  sheet := Sheet {
    primary: SheetAction(
      "Save",
      (): none => { clicked = true },
      (): bool => valid,
    ),
  }
  prepared := prepareSheet(sheet)
  Assert.isFalse(prepared.validate(prepared.primaryIndex))
  Assert.isFalse(clicked)
  valid = true
  Assert.isTrue(prepared.validate(prepared.primaryIndex))
  prepared.perform(prepared.primaryIndex)
  Assert.isTrue(clicked)
}

export function testFileDialogDefaultsAreSafe(): none {
  options := FileDialogOptions {}
  Assert.equal(options.directories, false)
  Assert.equal(options.multiple, false)
  Assert.equal(options.suggestedName, "")
}

export function testStandardMenusHaveStableStructureAndOrder(): none {
  prepared := prepareAppMenus(defaultAppMenus())
  Assert.equal(prepared.nodeKinds.length, 30)
  Assert.equal(prepared.parentIndices[0], -1)
  for index of 1..<10 { Assert.equal(prepared.parentIndices[index], 0) }
  Assert.equal(prepared.titles[0], "")
  Assert.equal(prepared.titles[3], "Services")
  Assert.equal(prepared.titles[10], "Edit")
  Assert.equal(prepared.titles[20], "View")
  Assert.equal(prepared.titles[25], "Window")
  Assert.equal(prepared.keys[9], "q")
  Assert.equal(prepared.modifierMasks[9], 1)
}

export function testStandardApplicationMenuPlacesSettingsConventionally(): none {
  let opened = false
  prepared := prepareAppMenus([StandardApplicationMenu((): none => { opened = true })])
  Assert.equal(prepared.titles[3], "Settings…")
  Assert.equal(prepared.keys[3], ",")
  Assert.equal(prepared.modifierMasks[3], 1)
  Assert.equal(prepared.titles[5], "Services")
  Assert.equal(prepared.handlers.length, 1)
  prepared.handlers[0]("", false)
  Assert.isTrue(opened)
}

export function testMenusPreserveNestedElementsAndModifierCombinations(): none {
  item := MenuItem(
    "Export Copy",
    (): none => {},
    MenuShortcut { key: "e", modifiers: [.Command, .Shift, .Option] },
  )
  prepared := prepareAppMenus([
    ApplicationMenu([]),
    Menu("File", [Menu("Export", [item, MenuSeparator()])]),
  ])
  Assert.equal(prepared.nodeKinds.length, 5)
  Assert.equal(prepared.nodeKinds[0], 0)
  Assert.equal(prepared.nodeKinds[1], 0)
  Assert.equal(prepared.nodeKinds[2], 0)
  Assert.equal(prepared.nodeKinds[3], 1)
  Assert.equal(prepared.nodeKinds[4], 2)
  Assert.equal(prepared.parentIndices[0], -1)
  Assert.equal(prepared.parentIndices[1], -1)
  Assert.equal(prepared.parentIndices[2], 1)
  Assert.equal(prepared.parentIndices[3], 2)
  Assert.equal(prepared.parentIndices[4], 2)
  Assert.equal(prepared.modifierMasks[3], 7)
}

export function testCustomMenuItemsCaptureInitialReactiveState(): none {
  let available = false
  let selected = true
  prepared := prepareAppMenus([
    ApplicationMenu([]),
    Menu("Mode", [
      MenuItem {
        title: "Compact",
        onSelect: (): none => {},
        enabled: (): bool => available,
        checked: (): bool => selected,
      },
    ]),
  ])
  Assert.isFalse(prepared.enabled[2])
  Assert.isTrue(prepared.checked[2])
}

export function testStandardShortcutsUseTypedModifiers(): none {
  prepared := prepareAppMenus([ApplicationMenu([]), Menu("Edit", [CopyMenuItem()])])
  Assert.equal(prepared.keys[2], "c")
  Assert.equal(prepared.modifierMasks[2], 1)
  shortcut := MenuShortcut { key: "k", modifiers: [MenuModifier.Control] }
  custom := prepareAppMenus([ApplicationMenu([]), Menu("Tools", [MenuItem("Run", (): none => {}, shortcut)])])
  Assert.equal(custom.modifierMasks[2], 8)
}

export function testMenuValidationRejectsInvalidTrees(): none {
  missingApplication := catchPanic(=> prepareAppMenus([Menu("File")]))
  case missingApplication {
    _: Success -> Assert.fail("expected a missing application menu to panic")
    failure: Failure -> Assert.stringContains(failure.error, "first menu")
  }

  duplicateApplication := catchPanic(=> prepareAppMenus([ApplicationMenu(), ApplicationMenu()]))
  case duplicateApplication {
    _: Success -> Assert.fail("expected duplicate application menus to panic")
    failure: Failure -> Assert.stringContains(failure.error, "only appear once")
  }

  misplacedServices := catchPanic(=> prepareAppMenus([ApplicationMenu(), ServicesMenu()]))
  case misplacedServices {
    _: Success -> Assert.fail("expected a misplaced services menu to panic")
    failure: Failure -> Assert.stringContains(failure.error, "direct child")
  }

  nestedWindow := catchPanic(=> prepareAppMenus([ApplicationMenu([WindowMenu()])]))
  case nestedWindow {
    _: Success -> Assert.fail("expected a nested window menu to panic")
    failure: Failure -> Assert.stringContains(failure.error, "top-level")
  }

  nestedHelp := catchPanic(=> prepareAppMenus([ApplicationMenu([HelpMenu()])]))
  case nestedHelp {
    _: Success -> Assert.fail("expected a nested help menu to panic")
    failure: Failure -> Assert.stringContains(failure.error, "top-level")
  }

  duplicateServices := catchPanic(=> prepareAppMenus([
    ApplicationMenu([ServicesMenu(), ServicesMenu()]),
  ]))
  case duplicateServices {
    _: Success -> Assert.fail("expected duplicate services menus to panic")
    failure: Failure -> Assert.stringContains(failure.error, "only appear once")
  }

  duplicateWindows := catchPanic(=> prepareAppMenus([
    ApplicationMenu(), WindowMenu(), WindowMenu(),
  ]))
  case duplicateWindows {
    _: Success -> Assert.fail("expected duplicate window menus to panic")
    failure: Failure -> Assert.stringContains(failure.error, "only appear once")
  }

  duplicateHelps := catchPanic(=> prepareAppMenus([
    ApplicationMenu(), HelpMenu(), HelpMenu(),
  ]))
  case duplicateHelps {
    _: Success -> Assert.fail("expected duplicate help menus to panic")
    failure: Failure -> Assert.stringContains(failure.error, "only appear once")
  }
}

export function testMenuValidationRejectsEmptyTitlesAndShortcuts(): none {
  emptyMenu := catchPanic(=> prepareAppMenus([ApplicationMenu(), Menu("")]))
  case emptyMenu {
    _: Success -> Assert.fail("expected an empty menu title to panic")
    failure: Failure -> Assert.stringContains(failure.error, "menu titles")
  }

  emptyItem := catchPanic(=> prepareAppMenus([
    ApplicationMenu(), Menu("File", [MenuItem("", (): none => {})]),
  ]))
  case emptyItem {
    _: Success -> Assert.fail("expected an empty item title to panic")
    failure: Failure -> Assert.stringContains(failure.error, "item titles")
  }

  emptyShortcut := catchPanic(=> prepareAppMenus([
    ApplicationMenu(),
    Menu("File", [MenuItem("Open", (): none => {}, MenuShortcut { key: "" })]),
  ]))
  case emptyShortcut {
    _: Success -> Assert.fail("expected an empty shortcut key to panic")
    failure: Failure -> Assert.stringContains(failure.error, "shortcut keys")
  }
}

export function testSetAppMenusMayOnlyBeCalledOnce(): none {
  setAppMenus([])
  repeated := catchPanic(=> setAppMenus([]))
  case repeated {
    _: Success -> Assert.fail("expected repeated menu configuration to panic")
    failure: Failure -> Assert.stringContains(failure.error, "only be called once")
  }
}

export function testNativeMenusPreserveRolesActionsStateAndCallbacks(): none {
  let selected = false
  let available = false
  let pinnedState = true
  customItem := MenuItem {
    title: "Pinned",
    onSelect: (): none => { selected = true },
    enabled: (): bool => available,
    checked: (): bool => pinnedState,
    shortcut: MenuShortcut { key: "p", modifiers: [.Command, .Control] },
  }
  app := NativeApplication.shared()
  installAppMenus(app, [
    StandardApplicationMenu(),
    StandardEditMenu(),
    Menu("File", [customItem]),
    StandardWindowMenu(),
    HelpMenu([MenuItem("Guide", (): none => {})]),
  ])

  root := try! parseJsonValue(app.menuSnapshot()) as JsonObject
  menus := try! root.get("menus")! as JsonValue[]
  Assert.equal(menus.length, 5)

  applicationMenu := try! menus[0] as JsonObject
  Assert.equal(applicationMenu.get("role")!, "application")
  Assert.isTrue((try! applicationMenu.get("title")! as string).length > 0)
  applicationItems := try! applicationMenu.get("children")! as JsonValue[]
  about := try! applicationItems[0] as JsonObject
  Assert.stringContains(try! about.get("title")! as string, "About ")
  Assert.equal(about.get("action")!, "orderFrontStandardAboutPanel:")
  services := try! applicationItems[2] as JsonObject
  Assert.equal(services.get("role")!, "services")
  hideOthers := try! applicationItems[5] as JsonObject
  Assert.equal(hideOthers.get("title")!, "Hide Others")

  editMenu := try! menus[1] as JsonObject
  editItems := try! editMenu.get("children")! as JsonValue[]
  copy := try! editItems[4] as JsonObject
  Assert.equal(copy.get("action")!, "copy:")
  Assert.equal(copy.get("key")!, "c")

  fileMenu := try! menus[2] as JsonObject
  fileItems := try! fileMenu.get("children")! as JsonValue[]
  pinned := try! fileItems[0] as JsonObject
  Assert.equal(pinned.get("modifiers")!, 9)
  Assert.equal(pinned.get("enabled")!, false)
  Assert.equal(pinned.get("checked")!, true)

  windowMenu := try! menus[3] as JsonObject
  helpMenu := try! menus[4] as JsonObject
  Assert.equal(windowMenu.get("role")!, "window")
  Assert.equal(helpMenu.get("role")!, "help")

  available = true
  pinnedState = false
  syncUI()
  updatedRoot := try! parseJsonValue(app.menuSnapshot()) as JsonObject
  updatedMenus := try! updatedRoot.get("menus")! as JsonValue[]
  updatedFile := try! updatedMenus[2] as JsonObject
  updatedItems := try! updatedFile.get("children")! as JsonValue[]
  updatedPinned := try! updatedItems[0] as JsonObject
  Assert.equal(updatedPinned.get("enabled")!, true)
  Assert.equal(updatedPinned.get("checked")!, false)

  app.performMenuItem(21)
  Assert.isTrue(selected)
}

export function testNativeWindowMenuListsShownWindows(): none {
  app := NativeApplication.shared()
  installAppMenus(app, defaultAppMenus())
  window := NativeWindow.create("Menu Test Window", 240, 160, true)
  window.show()

  root := try! parseJsonValue(app.menuSnapshot()) as JsonObject
  menus := try! root.get("menus")! as JsonValue[]
  windowMenu := try! menus[3] as JsonObject
  items := try! windowMenu.get("children")! as JsonValue[]
  let found = false
  for value of items {
    item := value as JsonObject else { continue }
    title := item.get("title")! as string else { continue }
    if title == "Menu Test Window" { found = true }
  }
  window.close()
  Assert.isTrue(found)
}

export function testPublicEnumsHaveStableValues(): none {
  Assert.equal(Axis.Horizontal.value, 0)
  Assert.equal(AlertStyle.Warning.value, 1)
}

export function testToolbarItemsSupportActionsSymbolsAndSpacing(): none {
  let clicked = false
  add := ToolbarItem {
    id: "add",
    label: "Add",
    symbol: "plus",
    toolTip: "Add an item",
    onClick: (): none => { clicked = true },
  }
  toolbar := Toolbar { children: [add, ToolbarFlexibleSpace(), ToolbarSpace()] }
  Assert.equal(toolbar.children.length, 3)
  Assert.equal(toolbar.children[0].symbol, "plus")
  Assert.equal(toolbar.children[1].kind, 2)
  Assert.equal(toolbar.children[2].kind, 1)
  toolbar.children[0].onClick()
  Assert.isTrue(clicked)
}

export function testColumnUsesDefaultGapAndCollapsesHiddenChildren(): none {
  first := Text("First")
  second := Text("Second").hidden(true)
  third := Text("Third")
  column := Column([first, second, third])
  column.prepareLayout()
  Assert.equal(column.layoutNode().children.length, 2)
  layout(column.layoutNode(), LayoutRect { width: 200.0, height: 100.0 })
  Assert.approxEqual(third.layoutNode().layoutBounds().y, first.layoutNode().layoutBounds().height + 8.0)
}

export function testRowAndColumnDirectionsAreSemanticDefaults(): none {
  row := Row([])
  column := Column([])
  Assert.equal(row.layoutNode().style.direction.value, 0)
  Assert.equal(column.layoutNode().style.direction.value, 2)
}

export function testGrowingColumnsSplitRowWidthWithCustomGap(): none {
  left := Column([Text("Left")], false, 8.0, 1.0)
  right := Column([Text("A much wider right column")], false, 8.0, 1.0)
  row := Row([left, right], false, 24.0)
  row.prepareLayout()
  layout(row.layoutNode(), LayoutRect { width: 424.0, height: 80.0 })
  Assert.approxEqual(left.layoutNode().layoutBounds().width, 200.0)
  Assert.approxEqual(right.layoutNode().layoutBounds().width, 200.0)
  Assert.approxEqual(right.layoutNode().layoutBounds().x, 224.0)
}

export function testSplitPaneContentUsesWrapperLocalCoordinates(): none {
  first := Column([Text("First")])
  second := Column([Text("Second")])
  split := SplitView([first, second])

  split.prepareLayout()
  layout(split.layoutNode(), LayoutRect { width: 400.0, height: 200.0 })

  Assert.approxEqual(first.layoutNode().bounds().x, 16.0)
  Assert.approxEqual(second.layoutNode().bounds().x, 16.0)
  Assert.approxEqual(first.layoutNode().bounds().y, 16.0)
  Assert.approxEqual(second.layoutNode().bounds().y, 16.0)
}

export function testBasicControlsParticipateInLayout(): none {
  controls := Column([
    SecureTextField("Password"),
    Picker("Color", ["Red", "Green", "Blue"], "Green"),
    Slider(0.5),
    ProgressBar(0.5),
  ])
  controls.prepareLayout()
  Assert.equal(controls.layoutNode().children.length, 4)
  layout(controls.layoutNode(), LayoutRect { width: 240.0, height: 180.0 })
  Assert.isTrue(controls.layoutNode().children[3].layoutBounds().y > 0.0)
}

export function testReactiveStringBindingsSynchronizeChanges(): none {
  let source = "First"
  let rendered = ""
  bindString((): string => source, (value): none => { rendered = value })
  Assert.equal(rendered, "First")
  source = "Second"
  syncUI()
  Assert.equal(rendered, "Second")
}

export function testAdditionalControlsParticipateInLayout(): none {
  controls := Column([
    SearchField("Filter"),
    Stepper("Quantity", 2.0, 0.0, 10.0),
    SegmentedControl("View", ["List", "Grid"], 0),
    Separator(),
    Spinner(),
    Switch("Notifications"),
  ])
  controls.prepareLayout()
  Assert.equal(controls.layoutNode().children.length, 6)
  layout(controls.layoutNode(), LayoutRect { width: 240.0, height: 220.0 })
  Assert.isTrue(controls.layoutNode().children[5].layoutBounds().y > 0.0)
}

export function testFormControlsParticipateInLayout(): none {
  date := try! Date.create(2026, 9, 3)
  controls := Column([
    TextArea("Notes", "Hello", 60.0),
    RadioGroup("Delivery", ["Email", "Post"], "Email"),
    ComboBox("City", ["Sydney", "Melbourne"], "Sydney"),
    DatePicker("Date", date),
    ColorWell("Accent", Color { red: 0.2, green: 0.4, blue: 0.8 }),
  ])
  controls.prepareLayout()
  Assert.equal(controls.layoutNode().children.length, 5)
  layout(controls.layoutNode(), LayoutRect { width: 300.0, height: 320.0 })
  Assert.isTrue(controls.layoutNode().children[4].layoutBounds().y > 0.0)
}

export function testColorDefaultsToOpaque(): none {
  Assert.equal(Color.black.alpha, 1.0)
}

export function testTableIsAViewElementAndReloadsExplicitRows(): none {
  first := TableTestRow { id: "1", name: "Ada", active: true }
  second := TableTestRow { id: "2", name: "Grace", active: false }
  table := <Table<TableTestRow> rows={[first]} rowKey=>row.id>
    <TextColumn<TableTestRow> id="name" title="Name" value=>row.name/>
    <CheckboxColumn<TableTestRow> id="active" title="Active" value=>row.active width=80.0/>
  </Table>

  container := Column([table])
  container.prepareLayout()
  Assert.equal(container.layoutNode().children.length, 1)
  Assert.equal(table.rowCount(), 1)

  table.reload([first, second])
  Assert.equal(table.rowCount(), 2)
}

export function testTableColumnsAcceptTypedMutationCallbacksAndSorting(): none {
  row := TableTestRow { id: "1", name: "Ada", active: true }
  table := <Table<TableTestRow> rows={[row]} rowKey=>row.id>
    <TextColumn<TableTestRow> id="name" title="Name" value=>row.name
      onChange=>{} sortable=true/>
    <CheckboxColumn<TableTestRow> id="active" title="Active" value=>row.active
      onChange=>{} sortable=true/>
    <NumberColumn<TableTestRow> id="score" title="Score" value=>row.score
      onChange=>{ row.score = value } sortable=true/>
    <DateColumn<TableTestRow> id="joined" title="Joined" value=>row.joined
      onChange=>{ row.joined = value } sortable=true/>
  </Table>
  Assert.equal(table.rowCount(), 1)
}

export function testThreeSplitPanesStartVisibleAndSurviveResize(): none {
  first := Column([Text("Threads")], false, 8.0, 1.0)
  second := Column([Text("Source")], false, 8.0, 1.0)
  third := Column([Text("Variables")], false, 8.0, 1.0)
  split := SplitView([first, second, third])
  split.prepareLayout()
  layout(split.layoutNode(), LayoutRect { width: 1200.0, height: 500.0 })
  for pane of [first, second, third] {
    Assert.equal(pane.layoutNode().layoutBounds().width > 250.0, true)
  }
  layout(split.layoutNode(), LayoutRect { width: 900.0, height: 400.0 })
  for pane of [first, second, third] {
    Assert.equal(pane.layoutNode().layoutBounds().width > 150.0, true)
  }
  split.dispose()
}

export function testThreeSplitPanesRemainVisibleInShownWindow(): none {
  first := Column([Text("Threads")], false, 8.0, 1.0)
  second := Column([Text("Source")], false, 8.0, 1.0)
  third := Column([Text("Variables")], false, 8.0, 1.0)
  split := SplitView([first, second, third])
  native := NativeWindow.create("Split regression", 1200, 650, true)
  native.setRoot(split.nativeView())
  native.setLayoutHandler((width, height): none => {
    split.prepareLayout()
    layout(split.layoutNode(), LayoutRect { width, height })
  })
  native.show()
  app := NativeApplication.shared()
  let turns = 0
  app.run((): int => {
    syncUI()
    turns += 1
    if turns >= 8 { app.quit() } else { app.requestWake() }
    return 0
  })
  Assert.equal(turns >= 8, true)
  for pane of [first, second, third] {
    Assert.equal(pane.layoutNode().layoutBounds().width > 150.0, true)
  }
  native.close()
  split.dispose()
}

export function testSplitViewUsesRequestedInitialProportions(): none {
  first := Column([Text("Stack")], false, 8.0, 1.0)
  source := Column([Text("Source")], false, 8.0, 1.0)
  last := Column([Text("Variables")], false, 8.0, 1.0)
  split := SplitView([first, source, last], .Horizontal, false, [1.0, 4.0, 1.0])
  split.prepareLayout()
  layout(split.layoutNode(), LayoutRect { width: 1200.0, height: 500.0 })
  Assert.equal(source.layoutNode().layoutBounds().width > 700.0, true)
  Assert.equal(first.layoutNode().layoutBounds().width > 150.0, true)
  Assert.equal(last.layoutNode().layoutBounds().width > 150.0, true)
  split.dispose()
}

export function testSplitDividerMovesRelayoutContentsSynchronously(): none {
  for axis of [Axis.Horizontal, Axis.Vertical] {
    first := Column([Text("First")], false, 8.0, 1.0)
    second := Column([Text("Second")], false, 8.0, 1.0)
    split := SplitView([first, second], axis)
    split.prepareLayout()
    layout(split.layoutNode(), LayoutRect { width: 900.0, height: 600.0 })
    split.nativeView().setSplitPosition(0, 220.0)
    before := first.layoutNode().layoutBounds()
    split.nativeView().setSplitPosition(0, 320.0)
    after := first.layoutNode().layoutBounds()
    if axis == .Horizontal { Assert.equal(after.width - before.width, 100.0) }
    else { Assert.equal(after.height - before.height, 100.0) }
    split.nativeView().setSplitPosition(0, -1000.0)
    minimum := first.layoutNode().layoutBounds()
    if axis == .Horizontal { Assert.equal(minimum.width > 0.0, true) }
    else { Assert.equal(minimum.height > 0.0, true) }
    split.dispose()
  }
}
