# Tabs with retained state

[Cookbook index](README.md) · [Tab API](../api.md#tab-views) · [Settings sample](../../samples/tabs/README.md)

## Bind selection and navigate from a button

Create pages once. Bind `selectedIndex` to application state and update that
state in `onChange` when the user selects a native tab. Buttons can select a
page by changing the same state; programmatic changes do not call `onChange`.

```doof
import { Button, Tab, TabView, Text, TextField, Window, runApp } from "std/appkit"

function main(): none {
  let selectedTab = 0
  let name = "Ada"
  let edits = 0

  tabs := <TabView selectedIndex=>selectedTab
    onChange=>{ selectedTab = selectedIndex }
    accessibilityLabel="Profile pages">
    <Tab title="Edit">
      <TextField label="Name" value=>name
        onChange=>{ name = value; edits += 1 }/>
      <Button title="Preview" onClick=>{ selectedTab = 1 }/>
    </Tab>
    <Tab title=>"Preview (${edits})">
      <Text value=>"Hello, ${name}!"/>
      <Button title="Back to edit" onClick=>{ selectedTab = 0 }/>
    </Tab>
  </TabView>
  window := <Window title="Profile preview" width=480 height=280>
    {tabs}
    <Text value=>"Page ${selectedTab + 1} of 2"/>
  </Window>
  window.show()
  runApp()
  tabs.dispose()
}
```

Edit the name, preview it, and return. The original text field and draft remain
in place. Click the native tabs too: the page counter follows either navigation
path. The preview title is reactive even while its page is not selected.
Indices are zero-based and must stay in range; tab items are fixed after
construction. Each page is measured, so preferred size includes the largest
page and native tab chrome.

## Add controls to a retained page

Retain a `TabItem` to update its `content` view. This changes the contents of an
existing page; the tab collection stays fixed. Each tab needs its own content.

```doof
import { Button, Tab, TabView, Text, Window, runApp } from "std/appkit"

function main(): none {
  let selectedTab = 0
  let count = 0
  activity := Tab("Activity", [Text("Session activity")])
  controls := Tab("Controls", [
    Button{title: "Add activity", enabled: (): bool => count < 5, onClick: (): none => {
      count += 1
      activity.content.append(Text("Activity ${count}"))
      selectedTab = 1
    }},
    Text("Add up to five entries, then switch pages to see them retained."),
  ])
  tabs := TabView{children: [controls, activity], selectedIndex: =>selectedTab,
    onChange: (index): none => { selectedTab = index },
    accessibilityLabel: "Activity pages"}
  window := Window{title: "Retained activity", width: 520, height: 320, children: [tabs]}
  window.show()
  runApp()
  tabs.dispose()
}
```

Add an entry, return to Controls, and add another. Earlier entries stay in
Activity. Append to `activity.content`, not directly to the `TabView`, whose
native children are managed internally. For longer content, place a growing
`ScrollView` in the page and append entries to its document `Column`.

For grouped settings, validation, and a visible comparison of native versus
programmatic selection, run the [focused sample](../../samples/tabs/README.md).
