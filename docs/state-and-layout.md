# State and layout

[Module guide](../README.md) · [API guide](api.md) · [Cookbook](cookbook/README.md)

## Own state in Doof

Build the view tree once. Keep application state in local `let` bindings or
mutable model fields, pass getters to the controls that display it, and update
that state in action callbacks. AppKit retains the native controls; there is no
component render function that rebuilds the tree after every action.

```doof
let name = "Ada"
field := <TextField label="Name" value=>name onChange=>{ name = value }/>
greeting := <Text value=>"Hello, ${name}"/>
```

This is a fragment; import `Text` and `TextField` and place both views in a
window. `value=>name` is a zero-argument getter. The callback's implicit `value`
parameter is the new string. The longer equivalent is
`onChange={(value: string): none => { name = value }}`.

Passing `value={name}` supplies the string at construction time. It does not
subscribe to later assignments to `name`. A getter supplies the read direction;
`onChange` supplies the write direction. Neither creates the other automatically.
For inputs whose state matters later, provide both.

Getters run during construction and later synchronization. Keep them cheap and
free of side effects: return existing state or a small derived value, and do
file access, parsing, and other work in an appropriate action or worker.

After a native action, the runtime evaluates bindings, applies changed values,
and recomputes layout. It also synchronizes after queued `std/event` work.
Arbitrary background assignments are not a UI notification mechanism. Deliver
worker results through a main-loop channel and update UI state in its handler.
`runApp()` integrates that queue; do not start a second `runMainEventLoop()`.
The [timer recipe](cookbook/files-and-events.md#update-ui-from-a-timer) shows this
integration without a background worker.

`hidden` accepts a boolean or getter. Hidden ordinary views collapse out of
layout and accessibility. `enabled` keeps a control visible but disables its
interaction. Use constructor parameters on labeled controls so the setting is
applied to the intended native field rather than its wrapping container.

## Choose a layout container

Dimensions and gaps are in layout points. ImageCanvas click coordinates are
instead image pixels.

| Container | Behavior | Defaults |
| --- | --- | --- |
| `Window` / `Sheet` body | Implicit column | 16-point padding, 8-point gap |
| `Row` | Horizontal children, vertically centered | `gap=8.0`, `grow=0.0` |
| `Column` | Vertical children, stretched across width | `gap=8.0`, `grow=0.0` |
| `GroupBox` | Native titled border around a vertical column; native content insets | `gap=8.0`, `grow=0.0` |
| `TabView` | Native tabs with retained page columns and native content insets | `selectedIndex=0`, `grow=1.0` |
| `SplitView` | Native resizable panes | `.Horizontal`, 16-point padding per pane |
| `ScrollView` | Native scrolling around one layout child | Growing view, minimum height 80 |

`Row` and `Column` accept non-negative `gap` and `grow`. A positive `grow`
allocates a share of spare space along the parent's main axis. For equal-width
groups, put two `<Column grow=1.0>` children in a `Row`. To let a nested table
fill vertical space, give its containing column `grow=1.0` too.

Ordinary controls use native intrinsic measurements. `Slider` starts with a
120-point minimum track and accepts `minWidth` and `grow`. Tables and split or
scroll views grow with an 80-point minimum height; image canvases use 240.
Do not assume every component accepts generic `width`, `height`, or `style`
attributes; check its constructor in the [API guide](api.md).

For advanced geometry, a `View` exposes `layoutNode().style` from
[`std/layout`](../../layout/README.md). Prefer the container parameters for
ordinary forms. Style changes take effect at the next layout pass.

## Scrolling and split panes

`ScrollView` requires exactly one child. Wrap a long form in a `Column`, then
put that column inside the scroll view. The document is measured at the
viewport width and grows vertically to fit its contents. A scroll view is not
an arbitrary two-axis canvas.

`SplitView axis=.Horizontal` places panes side by side; `.Vertical` stacks them.
Each direct child becomes a separate native pane with its own padded layout
root. Wrap multiple controls for one pane in a `Column`. AppKit owns divider
dragging and the pane frames; Doof lays out each pane's content.

Tables and image canvases already have native scrolling. They can be ordinary
window or split-pane children without another `ScrollView` around them.

## Compose reusable views

Most control and container functions return `View`. A helper can return `View`
and accept state getters or callbacks as parameters. `ViewElement` is the
structural interface with `asView(): View`; `Table<Row>` and `ImageCanvas` can
therefore participate in the same child lists while retaining their specialized
methods. Keep a reference to the table to call `reload`, or the canvas to call
`setImage` and `fit`.

`View` also supports `append`, `insertBefore`, `replace`, `detach`, and
`dispose` for explicit tree changes. These methods work with `View`, so convert
specialized elements with `asView()`. Leaf controls cannot have children, and
a scroll view cannot gain a second child. For showing an optional section,
prefer a reactive `hidden` value over repeated construction.

## Explicit data boundaries

Table columns read row values when AppKit needs them. A table does not observe
array mutations: call `reload(rows)` after adding, removing, filtering, or
changing rows that need to be redisplayed or resorted. Use stable, unique row
keys independent of current sort order. Sorting changes the native display
mapping, not your source array. The public API currently provides `reload`,
`rowCount`, and `asView`; it does not expose a selection-change callback.

`ImageCanvas.setImage(encodedImage)` similarly replaces the displayed encoded
image explicitly. Editing the source bytes alone does not refresh the canvas.
The canvas handles viewing and input; your application owns decoding, editing,
encoding, and persistence.
