# std/appkit

`std/appkit` builds native, accessible macOS interfaces with a Doof-first API.
AppKit owns the behavior it is good at—windows, controls, focus, keyboard input,
menus, dialogs, scrolling, split dividers, and accessibility—while `std/layout`
owns ordinary view geometry. Objective-C and AppKit layout types stay private.

## Start here

This module targets macOS and links Cocoa and Foundation. Build on macOS with
the Doof compiler and Apple's command-line developer tools installed. Import
from `std/appkit`; standard modules need no entry in `dependencies`.

The native bridge requires Objective-C ARC, enabled by the module's macOS
`compilerFlags: ["-fobjc-arc"]`. Native handles retain their AppKit objects;
outline parent links and adapter back-references are weak. Windows disable
release-on-close so their native handles remain valid after closing.

- [State and layout](docs/state-and-layout.md): bindings, callbacks, sizing,
  scrolling, split panes, and event-loop integration.
- [API guide](docs/api.md): control selection, defaults, file-dialog results,
  lifecycle rules, and links to exact public signatures.
- [Cookbook](docs/cookbook/README.md): complete programs for editable forms,
  validated sheets, searchable tables, file panels, and timers.
- [Basic sample](samples/basic/README.md) and
  [table sample](samples/table/README.md), plus the
  [Files-tree sample](samples/outline/README.md): native macOS applications.

Save the following complete example as `main.do` and run `doof run main.do`.

```doof
import { Button, Text, TextField, Window, runApp } from "std/appkit"

function main(): none {
  let count = 0
  window := <Window title="Counter" width=420 height=260>
    <Text value={(): string => "Count: ${count}"}/>
    <TextField label="Name" onChange={(name): none => println(name)}/>
    <Button title="Increment" onClick={(): none => { count += 1 }}/>
  </Window>

  window.show()
  runApp()
}
```

Direct `Window` children implicitly form a column with 16-point outer padding
and 8-point gaps. `Row` and `Column` use 8-point gaps by default and accept
`gap` and `grow` overrides, so small interfaces do not need style objects while
equal-width form columns can use `<Column grow=1.0>`. Reactive text,
enabled state, checked state, and visibility synchronize after native actions
and queued `std/event` work. Hidden views collapse out of layout and the
accessibility tree.

`Slider` reserves a usable 120-point track by default. Set `grow` when a slider
should consume spare space in a `Row`, and override `minWidth` only when the
interface needs a different minimum track length.

## Native boundaries

- `Text`, `TextField`, `SecureTextField`, `SearchField`, `Button`, `Checkbox`,
  `TextArea`, `CodeEditor`, `Picker`, `RadioGroup`, `ComboBox`, `DatePicker`, `ColorWell`,
  `SegmentedControl`, `Slider`, `Stepper`, `Switch`, `ProgressBar`, `Spinner`,
  and `Separator` are retained native controls measured intrinsically and placed by
  `std/layout`.
- `GroupBox` uses `NSBox` for a titled, accessible group around a layout column.
  Native content insets and title width participate in measurement; titles and
  visibility can be reactive. See the [API guide](docs/api.md#group-boxes).
- `TabView` uses `NSTabView` for labeled, retained pages with reactive selection.
  See the [tab API](docs/api.md#tab-views), [tab cookbook](docs/cookbook/tabs.md),
  and [tabbed settings sample](samples/tabs/README.md).
- `SplitView` uses `NSSplitView`; every direct child is a padded pane with its
  own layout subtree. Wrap several pane controls in `Column`.
- `ScrollView` uses `NSScrollView` and accepts exactly one layout-backed child.
- `Table<Row>` uses `NSTableView` for native virtualization, headers, selection,
  keyboard navigation, and accessibility. Its typed columns bridge row values
  lazily, and `reload(rows)` is the explicit update boundary.
- Menus, alerts, and file panels use their standard AppKit implementations.
- `ImageCanvas` uses an `NSScrollView` document view for pixel-accurate image
  clicks, drag and trackpad panning, magnification, and a native checkerboard
  transparency preview. Applications retain ownership of image editing and
  provide encoded image bytes at explicit update boundaries.

## Image canvases

`ImageCanvas` is a growing view intended for image inspectors and lightweight
editors. It reports clicks in top-left-origin image pixel coordinates and
distinguishes a click from a drag, so direct manipulation and panning can share
the same surface.

```doof
canvas := ImageCanvas((x: double, y: double): none => editPixel(int(x), int(y)))
canvas.setImage(encodedPng)
canvas.fit()
```

An optional second callback receives filesystem paths dropped onto the canvas.

For files opened through Finder or dropped on an application's Dock icon,
register `setOpenFilesHandler` before `runApp`. AppKit delivers all paths in
one callback and retains a launch-time request until the handler is installed:

```doof
setOpenFilesHandler((paths: string[]): none => openImages(paths))
```
The native view advertises copy semantics and highlights itself while a valid
file-URL drag is active.

Use `setBackground(.Checker | .White | .Black)` to inspect transparent edges
against different compositing backgrounds. This changes only the canvas; it
never alters the encoded image. Use `zoomIn`, `zoomOut`, `actualSize`, and
`fit` for programmatic controls.
Trackpad scrolling and magnification continue to use standard AppKit behavior.

This boundary also guides future components. Tables should use native AppKit
for virtualization, selection, editing, drag and drop, keyboard navigation, and
accessibility, while custom cell content can use `std/layout`. Richer dialogs
should remain native hosts for layout-backed content.

## Outline views

`OutlineView<Row>` displays a native, single-column hierarchy using stable keys,
typed children and label callbacks, and an optional `onSelect` callback.
It supports programmatic selection, expansion/collapse, and explicit reloads
that preserve surviving selection and expansion keys. See the
[outline API](docs/api.md#outline-views) and [Files-tree sample](samples/outline/README.md).

## Tables

Tables take an initial row array and strongly typed column value callbacks.
They do not observe the array or evaluate every cell during ordinary UI
synchronization. Call `reload(rows)` explicitly after changing the displayed
data. AppKit requests values lazily for visible cells.

```doof
import { CheckboxColumn, DateColumn, NumberColumn, Table, TextColumn } from "std/appkit"
import { Date } from "std/time"

class Person {
  id: string
  let name: string
  email: string
  let active: bool
  let score: double
  let joined: Date
}

function main(): none {
  let people = loadPeople()
  table := <Table<Person> rows={people} rowKey=>row.id>
    <TextColumn<Person> id="name" title="Name" value=>row.name
      onChange=>{ row.name = value } sortable=true width=180.0/>
    <TextColumn<Person> id="email" title="Email" value=>row.email
      sortable=true width=240.0/>
    <CheckboxColumn<Person> id="active" title="Active" value=>row.active
      onChange=>{ row.active = value } sortable=true width=80.0/>
    <NumberColumn<Person> id="score" title="Score" value=>row.score
      onChange=>{ row.score = value } sortable=true width=90.0/>
    <DateColumn<Person> id="joined" title="Joined" value=>row.joined
      onChange=>{ row.joined = value } sortable=true width=140.0/>
  </Table>

  people = applyFilter(people)
  table.reload(people)
}
```

Column ids must be non-empty and unique within a table. `rowKey` supplies
stable identity so native selection can be preserved when rows are reloaded or
reordered. A width of `0.0`, the default, lets AppKit choose the initial width.

`Table<Row>` is a `ViewElement`, so it can be placed directly inside `Window`,
`Row`, `Column`, `ScrollView`, and `SplitView` while retaining its table-specific
`reload` method.

Supplying `onChange` makes a text, checkbox, number, or date column editable. The callback
receives the source row and committed value; it does not implicitly reload the
table. This is especially useful with class rows, where the callback can mutate
the referenced model directly. Applications using value-type rows can instead
use `rowKey` to replace the corresponding value in their source array.

Set `sortable=true` to give a column a native sort indicator and header action.
Sorting changes only the table's displayed row mapping; it does not mutate the
array supplied by the application. Text values use case-insensitive localized
ordering, checkbox values place unchecked before checked, numbers use numeric
ordering, and dates use chronological ordering. Active sort descriptors are
reapplied after `reload(rows)`.

## Application lifecycle

Constructing a `Window` does not start an application or show UI. Call
`window.show()` for each initial window and then call `runApp()` once on the
main thread. The application loop returns when the last window closes or
`quitApp()` is called. This uses the real `NSApplication` event loop and wakes
only when native or `std/event` work is ready.

If an application does not configure menus, AppKit installs conventional
Application, Edit, View, and Window menus before the first window is shown.
`openFile` and `saveFile` present
native application services without requiring an action closure to capture its
containing window. Global `showAlert(alert)` presents an application-modal
alert; prefer `window.showAlert(alert)` to attach an alert to its relevant
window.

## Menus

Call `setAppMenus` once before `runApp` when the application needs a custom
menu bar. The supplied array is the complete ordered specification: AppKit does
not merge menus by title or insert omitted presets. A non-empty menu bar starts
with `ApplicationMenu`; passing an empty array explicitly installs no menu.

Standard presets provide macOS responder-chain behavior for text editing,
windows, toolbars, full screen, Services, hiding, About, and Quit. Mix the
presets with application-specific menus in the desired order:

```doof
import {
  Menu, MenuItem, MenuModifier, MenuSeparator, MenuShortcut,
  StandardApplicationMenu, StandardEditMenu, StandardViewMenu,
  StandardWindowMenu, setAppMenus,
} from "std/appkit"

let canExport = true
let compact = false

setAppMenus([
  StandardApplicationMenu(=> openSettings()),
  <Menu title="File">
    <MenuItem title="Open…" onSelect=>openDocument()
      shortcut={MenuShortcut { key: "o" }}/>
    <MenuSeparator/>
    <Menu title="Export">
      <MenuItem title="PDF" onSelect=>exportPdf()
        enabled=>canExport
        shortcut={MenuShortcut { key: "e", modifiers: [.Command, .Shift] }}/>
    </Menu>
  </Menu>,
  StandardEditMenu(),
  <Menu title="View">
    <MenuItem title="Compact Layout" onSelect=>{ compact = !compact }
      checked=>compact/>
  </Menu>,
  StandardWindowMenu(),
])
```

`MenuItem` requires a title and callback. `enabled` and `checked` accept either
fixed booleans or zero-argument getters and synchronize after native actions.
A checked item displays a checkmark; its callback remains responsible for
changing the backing state. `MenuShortcut` uses Command by default and accepts
any combination of `.Command`, `.Shift`, `.Option`, and `.Control`.

For complete control within the platform menus, build `ApplicationMenu`,
`ServicesMenu`, `WindowMenu`, and `HelpMenu` directly and use the exported
standard item constructors such as `AboutMenuItem`, `SettingsMenuItem`,
`CopyMenuItem`, `ToggleFullScreenMenuItem`, and `QuitMenuItem`. These
constructors provide native responder actions and conventional key equivalents.
`SettingsMenuItem` takes an application callback for opening your settings UI.

## Toolbars

Pass a `Toolbar` to a window to install a native `NSToolbar`. Toolbar items can
show an SF Symbol, a text label, or both. Their enabled state can be reactive,
and actions participate in the same UI synchronization cycle as other native
controls. Fixed and flexible spaces use AppKit's standard toolbar items.

```doof
import {
  Toolbar, ToolbarFlexibleSpace, ToolbarItem, Window,
} from "std/appkit"

let canAdd = true
toolbar := <Toolbar allowsCustomization=true>
  <ToolbarItem id="add" label="Add" symbol="plus" toolTip="Add an item"
    enabled=>canAdd onClick=>addItem()/>
  <ToolbarFlexibleSpace/>
  <ToolbarItem id="refresh" label="Refresh" symbol="arrow.clockwise"
    onClick=>refresh()/>
</Toolbar>

window := <Window title="Items" toolbar={toolbar}>
  // Content
</Window>
```

Custom item ids must be non-empty and unique within a toolbar. Labels are also
required so every item remains understandable when the toolbar uses label-only
display or an SF Symbol is unavailable. Use `ToolbarSpace` for a fixed space,
and set `displayMode` to `.IconOnly`, `.LabelOnly`, or `.IconAndLabel` when the
system default is not appropriate.

## Alerts

`Alert` uses native `NSAlert` presentation. A primary action responds to Return,
a cancel action responds to Escape, and alternative actions provide additional
choices. Set `primary` to `none` when an alert should have no default action.
Callbacks run after the alert has closed, so they can safely present another
alert.

```doof
import { Alert, AlertAction, AlertStyle } from "std/appkit"

window.showAlert(Alert {
  title: "Delete project?",
  message: "This action cannot be undone.",
  style: .Critical,
  primary: none,
  alternatives: [
    AlertAction {
      title: "Delete",
      onClick: deleteProject,
      destructive: true,
    },
  ],
  cancel: AlertAction("Cancel"),
})
```

An alert defaults to a single `OK` primary action. Action titles must be
non-empty, and each window can present only one alert at a time.

## Custom sheets

`Sheet` presents ordinary `ViewElement` content in a native window-attached
sheet. AppKit owns the action bar and modality while `std/layout` lays out the
body. As with alerts, the primary action responds to Return, the cancel action
responds to Escape, and `primary: none` removes the default action.

```doof
import { Sheet, SheetAction, Text, TextField, Window } from "std/appkit"

class Profile { let name: string }

function showProfileEditor(window: Window, profile: Profile): none {
  let draftName = profile.name
  let validationMessage = ""

  sheet := <Sheet
    title="Edit Profile"
    width=440
    height=240
    primary={SheetAction(
      "Save",
      (): none => { profile.name = draftName },
      (): bool => {
        if draftName.trim() != "" { return true }
        validationMessage = "A name is required."
        return false
      },
    )}
    cancel={SheetAction("Cancel")}>
    <TextField label="Name" value=>draftName onChange=>{ draftName = value }/>
    <Text value=>validationMessage hidden=>validationMessage == ""/>
  </Sheet>

  window.showSheet(sheet)
}
```

When an action has a `validate` callback, the callback runs before dismissal.
Returning `false` keeps the sheet open and synchronizes reactive UI, allowing
the validator to reveal an error. On success, the sheet closes before its
`onClick` callback runs. Keep edits in dialog-local draft state and commit them
from the primary action; cancelling should discard the draft without mutating
the application model. Each window can present only one alert or custom sheet
at a time.

## Accessibility

Standard controls retain their native roles, actions, focus, and keyboard
behavior. Layout-only containers are omitted from the accessibility tree.
`TextField`, `SecureTextField`, `SearchField`, `TextArea`, `CodeEditor`, `Picker`,
`RadioGroup`, `ComboBox`, `DatePicker`, `ColorWell`, `SegmentedControl`, and
`Stepper` require a visible `label` and connect it as the native title element;
placeholder text is never used as an accessible name. Components also accept
`accessibilityLabel`, `accessibilityHelp`, and
`accessibilityIdentifier` overrides where their visible content is not enough.

## Basic controls

Control values can be fixed or supplied by a zero-argument getter. Native
actions run the relevant callback and then synchronize reactive values.

```doof
import {
  Color, ColorWell, Column, ComboBox, DatePicker, Picker, ProgressBar,
  RadioGroup, SearchField, SecureTextField, SegmentedControl, Separator,
  Slider, Spinner, Stepper, Switch, TextArea,
} from "std/appkit"
import { Date } from "std/time"

let color = "Green"
let volume = 0.5
let progress = 0.25
let password = ""

controls := <Column>
  <SecureTextField label="Password" value={(): string => password}
    onChange={(value): none => { password = value }}/>
  <Picker label="Color" options={["Red", "Green", "Blue"]}
    selected={(): string => color} onChange={(value): none => { color = value }}/>
  <Slider value={(): double => volume} minimum=0.0 maximum=1.0
    onChange={(value): none => { volume = value }}/>
  <ProgressBar value={(): double => progress}/>
  <SearchField label="Filter" onChange={(value): none => println(value)}/>
  <SegmentedControl label="View" segments={["List", "Grid"]}
    onChange={(selectedIndex): none => println(selectedIndex)}/>
  <Stepper label="Quantity" minimum=1.0 maximum=10.0/>
  <Switch title="Notifications" checked=true/>
  <TextArea label="Notes" minHeight=100.0/>
  <RadioGroup label="Delivery" options={["Email", "Post"]} selected="Email"/>
  <ComboBox label="City" options={["Sydney", "Melbourne"]}/>
  <DatePicker label="Date" value={try! Date.create(2026, 9, 3)}/>
  <ColorWell label="Accent" value={Color { red: 0.2, green: 0.4, blue: 0.8 }}/>
  <Separator/>
  <Spinner accessibilityLabel="Loading results"/>
</Column>
```

## Testing

From the `doof-stdlib` workspace, use `DOOF_STDLIB_ROOT` to resolve imports to
this checkout rather than the compiler's bundled standard library:

```sh
export DOOF_STDLIB_ROOT="$PWD"
doof check appkit/samples/basic
doof check appkit/samples/table
doof check appkit/samples/outline
doof check appkit/samples/tabs
doof test appkit
doof run appkit/samples/basic
doof run appkit/samples/table
doof run appkit/samples/outline
doof run appkit/samples/tabs
```

The tests exercise native AppKit objects and require macOS. Checking a sample
validates Doof types without opening a window; running it starts an interactive
application. See the cookbook for focused manual checks of each recipe.

## Editable source views

`CodeEditor` is an editable, monospaced `NSTextView` with optional one-based
line numbers, native undo and find support, configurable wrapping, font size,
and tab width. Auto-indentation is enabled by default: a new line preserves the
current line's leading whitespace and gains one space-based `tabWidth` level
after an opening `{`, `[` or `(`. Typing `}` after only leading whitespace
removes one indentation level (up to `tabWidth` spaces, or one trailing tab). Set `autoIndent=false` to disable it. Smart
substitutions, spelling correction, and rich-text input are disabled. Text and
selection callbacks return UTF-8-oriented values so they compose directly with
compiler spans.

```doof
let source = "function main(): none {}"
editor := <CodeEditor value=>source onChange=>{ source = value }
  lineNumbers=true wrapLines=false tabWidth=2
  hoverText={(offset): string => if offset < 8 then "Function declaration" else ""}/>
editor.setHighlights([
  CodeEditorHighlight { start: 0, length: 8, style: .Keyword },
])
editor.setSelection(CodeEditorSelection { start: 9, length: 4 })
```

`CodeEditorHighlight` and `CodeEditorSelection` use document-relative UTF-8
byte ranges. The native boundary converts them to TextKit's UTF-16 ranges.
The `.Error` and `.Warning` highlight styles add adaptive dotted underlines
without replacing syntax foreground colors.
Highlights are explicit snapshots; reapply them after text changes. Selection
updates preserve AppKit's normal responder-chain behavior and optionally reveal
the new selection. `hoverText` receives the UTF-8 byte offset beneath the mouse
and returns plain text for a native multiline tooltip; return an empty string
when there is nothing to show.

## Read-only source views

`SourceView(onToggleBreakpoint)` displays virtualized, monospaced source lines
with a clickable line-number gutter. The callback receives a one-based line
number; the application owns breakpoint state. Call
`setLines(lines, markers, currentLine, reveal)` to update it. Markers are `0`
(absent), `1` (pending), or `2` (verified), with either no markers or one per
line. `currentLine=0` clears the execution highlight; `reveal=true` scrolls to a
valid current line. Dispose through `asView().dispose()` to release callbacks.

View layout callbacks hold weak references to their owning views. Disposing a
view is idempotent: it clears layout and measurement callbacks, disposes its
owned child views and native controls, and prevents subsequent layout refreshes
from reinstalling callbacks. Native split views also clear their pane-layout
callback during disposal.

### Split pane proportions and source presentation

`SplitView(weights: [1.0, 4.0, 1.0])` sets initial pane proportions. Omit weights
for equal panes; supplied weights must be positive and match the child count.
Users can drag dividers afterward. Pane contents relayout synchronously during
native divider tracking, and retain their proportions when the window resizes.

`Text` accepts `fontSize`, `semibold` and `secondary` for native label hierarchy.
`SourceView` uses monospaced text, content-sized horizontal scrolling, line numbers,
breakpoint markers and a current-line highlight. Its source remains read-only.

`SourceView.setHighlights` accepts `SourceHighlight` values with one-based line
numbers, UTF-8 byte starts/lengths, and a `SourceStyle` (keyword, string, number,
comment, type, function, error or warning). Call after `setLines`; highlights persist while line
text is unchanged. The bridge converts spans to UTF-16 and uses adaptive system
colors. Source rows and text do not select; separate accessible gutter buttons
own breakpoint actions and display add/remove tooltips.

Splitters track every mouse-drag event and synchronously lay out adjacent pane
contents before mouse-up. This replaces the earlier resize-notification-only
approach, which could still defer updates. Native tracking/layout is isolated in
`native_split_view.hpp`; `NativeView.setSplitPosition` uses the same immediate
layout path for programmatic divider movement.
