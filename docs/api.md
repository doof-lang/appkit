# API guide

[Module guide](../README.md) · [State and layout](state-and-layout.md) · [Cookbook](cookbook/README.md)

Import public symbols from `std/appkit`. The [export list](../index.do) is the
package boundary. Linked source files below contain the exact signatures;
native bridge types and runtime helpers are implementation details.

## Windows and application services

| API | Contract |
| --- | --- |
| `Window(...)` | `title="Doof App"`, `width=800`, `height=600`, `resizable=true`, `children=[]`, `toolbar=none`; dimensions must be positive |
| `window.show()` / `close()` / `isShown()` | Show, close, or inspect a window |
| `runApp()` | Call once on the main thread, with at least one shown window; returns after the last window closes or `quitApp()` |
| `quitApp()` | Requests termination of the application loop |
| `setAppMenus(menus)` | Configure once before `runApp`; replaces the complete menu specification |
| `setOpenFilesHandler(handler)` | Register once before `runApp`; callback receives `string[]` paths from Finder/Dock open requests |
| `window.showAlert(alert)` / `showSheet(sheet)` | Requires a shown window; only one attached modal at a time |
| `showAlert(alert)` | Application-modal alert; callback runs after dismissal |
| `openFile(options)` | Returns `string[]`; cancellation returns an empty array |
| `saveFile(options)` | Returns `string \| none`; cancellation returns `none` |

[Signatures and lifecycle checks](../app.do).

Window title, dimensions, and resizability are construction settings. There
are currently no public setters for window position, minimum/maximum size,
restoration, or fullscreen. Fullscreen is available through the standard menu
command. `OutlineView` displays hierarchical rows with selection and disclosure
controls; `Table` displays flat rows and exposes no public selection API.

`FileDialogOptions` defaults to `{ title: "", suggestedName: "",
directories: false, multiple: false }`. `openFile` uses `title`, `directories`,
and `multiple`; `directories=true` selects directories instead of files.
`saveFile` uses `title` and `suggestedName`. These panels choose paths; they do
not read or write file contents. The current options do not include file-type
filters or an initial directory. Handle cancellation before accessing a result.
See the [file panel recipe](cookbook/files-and-events.md).

## Controls at a glance

In this table, “reactive” means a value or a zero-argument getter of that type.
Unless noted, input controls have `enabled=true`, `hidden=false`, and a no-op
action callback. `hidden` and `enabled` are reactive booleans.

| Control | Required arguments | State and action |
| --- | --- | --- |
| `Text` | reactive `value: string` | Read-only display |
| `Button` | reactive `title: string` | `onClick(): none` |
| `Checkbox`, `Switch` | reactive `title: string` | reactive `checked=false`; `onChange(bool)` |
| `TextField`, `SecureTextField`, `SearchField` | reactive `label: string` | reactive `value=""`; `onChange(string)`; fixed placeholder |
| `TextArea` | reactive `label: string` | reactive `value=""`; `onChange(string)`; `minHeight=120.0` |
| `CodeEditor` | None | reactive `value=""`; `onChange(string)`; UTF-8 highlights and selection; line numbers, wrapping, font, tab and auto-indent configuration |
| `Picker` | reactive `label`, `options: string[]` | reactive `selected=""`; `onChange(string)` |
| `RadioGroup` | reactive `label`, `options`, reactive `selected: string` | `onChange(string)` |
| `ComboBox` | reactive `label` | `options=[]`, reactive `value=""`; `onChange(string)`; allows typed text |
| `SegmentedControl` | reactive `label`, `segments: string[]` | reactive `selectedIndex=0`; `onChange(int)` |
| `Slider` | None | reactive `value=0.0`; range `0.0…1.0`; `onChange(double)` |
| `Stepper` | reactive `label` | reactive `value=0.0`; range `0.0…100.0`; `increment=1.0`; `onChange(double)` |
| `ProgressBar` | None | reactive `value=0.0`; range `0.0…1.0`; no action or enabled parameter |
| `Spinner` | None | Indeterminate activity; reactive `hidden`; no value or enabled parameter |
| `DatePicker` | reactive `label`, reactive `value: Date` | `onChange(Date)`; import `Date` from `std/time` |
| `ColorWell` | reactive `label` | reactive `value: Color` (opaque black); `onChange(Color)` |
| `Separator` | None | Only reactive `hidden` |

[Basic signatures](../controls.do) · [Form signatures](../form_controls.do) ·
[Additional signatures](../additional_controls.do).

`Text` has no `enabled` parameter. All controls except `Separator` accept
`accessibilityLabel`, `accessibilityHelp`, and `accessibilityIdentifier`.
Visible labels are required for labeled fields; placeholders are hints, not
accessible names. Give unlabeled sliders and progress bars an accessibility
label. Spinner defaults to the accessibility label `Loading`.

`Picker` and `RadioGroup` need non-empty options; choose an explicit initial
selection. `RadioGroup` enforces membership. `SegmentedControl` requires
non-empty segments and an index in range, including later reactive values.
Options, segments, ranges, and placeholders are fixed constructor inputs.

`CodeEditor` is a growing, unlabeled `NSTextView` intended for source editing.
Use `CodeEditorHighlight` with `SourceStyle` values to apply document-relative
UTF-8 spans. `selection()` and `setSelection()` also use UTF-8 byte ranges;
`onSelectionChange` reports native selection changes. Highlights are cleared
by programmatic text replacement and should be reapplied by the owner. With
`autoIndent=true` (the default), a newline copies leading whitespace and adds a
space-based `tabWidth` level after `{`, `[` or `(`. The `.Error` and `.Warning`
styles draw adaptive dotted underlines while preserving syntax colors.
`hoverText` receives a UTF-8 byte offset and returns text for a native tooltip;
return an empty string to suppress it.

Numeric ranges require `minimum < maximum`. Stepper increments must be
positive; TextArea's minimum height must be positive. Slider's `minWidth`
and `grow` must be non-negative. `Color` has `red`, `green`, `blue`, and
`alpha=1.0`; `ColorWell` requires all four channels in `0.0…1.0`.
`Color.black` and `Color.white` are conveniences.

## Outline views

`OutlineView<Row>(rows, rowKey, children, label, ...)` is a native single-column
tree. `children(row): Row[]` describes a finite hierarchy and `label(row): string`
supplies its text. Keys must be non-empty and unique across the entire tree;
duplicate keys and cycles panic before replacing live data.

| Method | Behavior |
| --- | --- |
| `rowCount()` | Total snapshot size, including collapsed descendants |
| `selected(): Row \| none` | Currently selected typed row |
| `select(key: string \| none)` | Reveal ancestors and select a key, or clear selection with `none`; no `onSelect` callback |
| `expand(key, recursive=false)` | Reveal ancestors and expand the item, optionally including descendants |
| `collapse(key, recursive=false)` | Collapse the item, optionally including descendants |
| `reload(rows)` | Replace the snapshot, preserving expansion and selection by surviving keys; clear selection if its key disappeared; no `onSelect` callback |

Unknown keys passed to `select`, `expand`, or `collapse` panic. User selection
calls `onSelect(row: Row | none)` and synchronizes reactive UI bindings.
Construction accepts reactive `hidden=false` and the usual accessibility label,
help, and identifier. Data is updated explicitly with `reload`, rather than on
each UI synchronization. Keep `rowKey`, `children`, and `label` callbacks free
of UI mutations. Use `asView().dispose()` when permanently removing the tree.

[Signatures](../outline_view.do) · [Files-tree sample](../samples/outline/README.md).

## Tables and canvases

`Table<Row>(rows, rowKey, children, ...)` requires at least one column and
accepts reactive `hidden` plus accessibility overrides. `rowKey(row): string`
should return a stable unique identity. `rowCount()` reports the current data
array length; `reload(rows)` updates it explicitly.

| Column | `value(row)` / `onChange(row, value)` value type |
| --- | --- |
| `TextColumn<Row>` | `string` |
| `CheckboxColumn<Row>` | `bool` |
| `NumberColumn<Row>` | `double` |
| `DateColumn<Row>` | `std/time.Date` |

Every column requires `id`, `title`, and `value`. IDs must be non-empty and
unique within the table. `width=0.0` lets AppKit choose the initial width;
negative widths are rejected. `sortable=false` and `onChange=none` default to
unsortable, read-only columns. Supplying `onChange` enables native editing but
leaves model updates to that callback. Active sort descriptors are reapplied
on reload. [Table signatures](../table.do) and [recipe](cookbook/tables.md).

`ImageCanvas(onClick, onDrop)` has optional no-op callbacks. Clicks report
`(x: double, y: double)` in top-left-origin image pixel coordinates. Drops
report filesystem paths. `setImage(readonly byte[])` takes encoded image data;
`setBackground(.Checker | .White | .Black)` changes the preview background.
`zoomIn()`, `zoomOut()`, `actualSize()`, and `fit()` control viewing.
Use `asView()` for common visibility/accessibility methods.
[Canvas signatures](../image_canvas.do).

## Menus, toolbars, and dialogs

The module guide has focused examples for [menus](../README.md#menus),
[toolbars](../README.md#toolbars), [alerts](../README.md#alerts), and
[custom sheets](../README.md#custom-sheets).

`MenuItem` takes `title` and `onSelect`; `enabled` and `checked` are reactive.
`MenuShortcut` defaults to Command and accepts Command, Shift, Option, and
Control modifiers. Use standard menu presets for native responder behavior.
An explicit menu bar must start with `ApplicationMenu`, unless it is empty.
[All menu constructors](../menu.do).

`Toolbar` takes `children`, `displayMode=.Default`, and
`allowsCustomization=false`. `ToolbarItem` requires a non-blank unique `id`
and non-blank `label`; `symbol`, `toolTip`, reactive `enabled`, and `onClick`
are optional. `ToolbarSpace` and `ToolbarFlexibleSpace` provide spacing.
[Toolbar signatures](../toolbar.do).

`Alert` requires a title and defaults to an informational alert with an `OK`
primary action. `Sheet` defaults to 480×320 and a `Done` primary action.
Both support alternatives, an optional cancel action, and `primary=none` to
remove the default action. At least one action and non-empty action titles
are required. Return invokes primary; Escape invokes cancel when supplied.
Action callbacks run after dismissal. A sheet action's optional `validate`
callback runs first; returning false keeps the sheet open and refreshes its UI.
[Alert types](../alert.do) · [Sheet types](../sheet.do) ·
[Validated editor recipe](cookbook/forms.md#edit-a-draft-in-a-sheet).

## Group boxes

[`GroupBox`](../group_box.do) groups a column of children inside a native
`NSBox`, with the standard macOS title, border, and accessibility group.

```doof
import { GroupBox, TextField } from "std/appkit"

account := <GroupBox title="Account" gap=12.0 grow=1.0>
  <TextField label="Name"/>
  <TextField label="Email"/>
</GroupBox>
```

`title` is required and accepts a string or reactive getter; an empty string is
supported. `children=[]`, `gap=8.0`, `grow=0.0`, and reactive `hidden=false` are
the defaults. `padding=0.0` adds extra space on each side inside the native content insets.
`gap`, `grow`, and `padding` must be non-negative. Optional
`accessibilityLabel`, `accessibilityHelp`, and `accessibilityIdentifier` strings
provide native accessibility overrides.

AppKit supplies content insets and the title's minimum width. Children stretch
across the content width. Reactive title changes update measurement at the next
UI synchronization. Positive `grow` shares spare space after minimum sizes;
different title minimums can produce different total widths at equal growth.

A GroupBox is an ordinary `View`: it supports nesting, `append`, `insertBefore`,
`replace`, `detach`, and `dispose`, and can be the single child of `ScrollView`.
Hidden children collapse out of its column. Native margins already participate
in layout; callers do not need to add padding for the title or border.

## Tab views

[Complete cookbook examples](cookbook/tabs.md) · [Tabbed settings sample](../samples/tabs/README.md)

[`TabView`](../tab_view.do) hosts a fixed, nonempty array of `Tab` items using
native `NSTabView` tabs. Each `Tab` takes a required reactive `title`, optional
`children=[]`, and non-negative `gap=8.0`; its children form a column.

```doof
import { Tab, TabView, TextField, Switch } from "std/appkit"

let selectedTab = 0
settings := <TabView selectedIndex=>selectedTab onChange=>{ selectedTab = selectedIndex }>
  <Tab title="Account"><TextField label="Name"/></Tab>
  <Tab title="Notifications"><Switch title="Enable notifications"/></Tab>
</TabView>
```

`selectedIndex=0` accepts an integer or reactive getter. Indices are zero-based;
out-of-range values panic, including reactive updates. Native selection invokes
`onChange(selectedIndex)` and synchronizes UI state. Applying `selectedIndex`
programmatically does not invoke `onChange`. With a getter, update its backing
state in `onChange` to keep application state in sync with native selection.

`grow=1.0` shares available space; it must be non-negative. `hidden=false` is
reactive. Optional `accessibilityLabel`, `accessibilityHelp`, and
`accessibilityIdentifier` strings provide native overrides. AppKit owns tab
appearance, keyboard interaction, accessibility, and content insets.

All pages are created once and retained across selection changes. Only the
selected page is attached to the native visible hierarchy. Preferred size uses
the largest page plus native chrome so switching does not resize the container.
Each page can contain ordinary views, nested tabs, group boxes, or scrolling.

Tabs are fixed and not closable; insertion, removal, and reordering are not
exposed. Do not reuse a tab or its content in multiple hosts. To mutate controls
within a page, retain its `TabItem` and use its `content` View. `TabView` returns
a View supporting visibility, detachment, and disposal; arbitrary direct child
append/insert operations are not supported. Disposal clears native tab callbacks
and disposes retained native page content.
