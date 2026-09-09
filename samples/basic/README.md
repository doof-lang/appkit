# Basic AppKit sample

Run the native macOS app from this directory:

```sh
doof run .
```

It demonstrates the application-level lifecycle, implicit window layout,
reactive native controls, accessible text-field labeling, `TabView` pages containing `GroupBox`
sections for preferences and delivery details, `SplitView`,
`ScrollView`, an explicitly ordered menu bar built from standard presets and a
custom File menu, an alert, and the native open-file panel.

The native tabs retain their controls when you switch pages. Edit a field,
switch to the other tab, and return to verify its value is preserved. Resize
the window to try the tab content layout. Both tabs and group boxes use native
AppKit content insets.
