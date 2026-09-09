# AppKit cookbook

[Module guide](../../README.md) · [API guide](../api.md) · [State and layout](../state-and-layout.md)

Each Doof block in these recipe pages is a complete, independent program.
Copy one block into `main.do` and run it on macOS:

```sh
doof check main.do
doof run main.do
```

When developing this standard-library checkout, first set
`DOOF_STDLIB_ROOT` to its absolute path. Regular applications can use the
compiler's bundled standard library if it includes these AppKit APIs.

| I want to… | Recipe |
| --- | --- |
| Bind fields to state and hide optional settings | [A reactive form](forms.md#a-reactive-form) |
| Validate edits while preserving Cancel behavior | [Edit a draft in a sheet](forms.md#edit-a-draft-in-a-sheet) |
| Keep tab state and navigate from buttons | [Bind selection and navigate from a button](tabs.md#bind-selection-and-navigate-from-a-button) |
| Add controls to an existing tab page | [Add controls to a retained page](tabs.md#add-controls-to-a-retained-page) |
| Filter editable rows and keep stable identity | [A searchable table](tables.md) |
| Handle file-panel cancellation and Finder open requests | [Choose input and output paths](files-and-events.md#choose-input-and-output-paths) |
| Refresh a display without polling the native UI | [Update UI from a timer](files-and-events.md#update-ui-from-a-timer) |

For a larger app combining split panes, scrolling, custom menus, and alerts,
run the [basic sample](../../samples/basic/README.md). For all four editable
column types and native sorting, run the [table sample](../../samples/table/README.md).
For reactive tab titles, retained settings, and selection binding, run the
[tabbed settings sample](../../samples/tabs/README.md).

These recipes keep data in memory and file-panel examples only select paths.
Add persistence or domain work at the indicated action boundaries. Keep slow
work out of native callbacks so the application remains responsive.
