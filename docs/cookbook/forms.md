# Forms and validated editing

[Cookbook index](README.md)

## A reactive form

Bind both directions: getters display the model and callbacks update it.
The optional section collapses when hidden, and the action remains disabled
until the name contains non-whitespace text. Equal `grow` values give the two
field columns equal shares of horizontal space.

```doof
import {
  Button, Checkbox, Column, Row, Slider, Text, TextField, Window, runApp,
} from "std/appkit"

function main(): none {
  let name = ""
  let team = ""
  let advanced = false
  let volume = 0.5
  let status = "No profile applied."

  window := <Window title="Profile" width=520 height=360>
    <Row gap=16.0>
      <Column grow=1.0>
        <TextField label="Name" value=>name onChange=>{ name = value }/>
      </Column>
      <Column grow=1.0>
        <TextField label="Team" value=>team onChange=>{ team = value }/>
      </Column>
    </Row>
    <Checkbox title="Advanced settings" checked=>advanced
      onChange=>{ advanced = checked }/>
    <Column hidden=>!advanced>
      <Text value="Preview volume"/>
      <Row>
        <Slider value=>volume grow=1.0 accessibilityLabel="Preview volume"
          onChange=>{ volume = value }/>
        <Text value=>"${int(volume * 100.0)}%"/>
      </Row>
    </Column>
    <Button title="Apply" enabled=>name.trim() != "" onClick=>{
      status = "Applied profile for ${name.trim()} (${team})."
    }/>
    <Text value=>status/>
  </Window>
  window.show()
  runApp()
}
```

Try entering only spaces, then a name. Toggle advanced settings and resize the
window: the slider receives spare row width and the hidden section leaves no
reserved gap for its contents. The backing values survive hiding the section.

## Edit a draft in a sheet

Create fresh draft state for each presentation. The primary action commits
only after validation succeeds; Cancel has no model-changing callback.
Construct the editor button after the window so it can capture that window
without referring to an unfinished initializer.

```doof
import {
  Button, Sheet, SheetAction, Text, TextField, Window, runApp,
} from "std/appkit"

class Profile {
  let name: string
}

function editProfile(window: Window, profile: Profile): none {
  let draft = profile.name
  let error = ""
  sheet := <Sheet title="Edit profile" width=440 height=240
    primary={SheetAction {
      title: "Save",
      onClick: (): none => { profile.name = draft.trim() },
      validate: (): bool => {
        if draft.trim() != "" { return true }
        error = "Enter a name before saving."
        return false
      },
    }}
    cancel={SheetAction("Cancel")}>
    <TextField label="Name" value=>draft onChange=>{
      draft = value
      error = ""
    }/>
    <Text value=>error hidden=>error == ""/>
  </Sheet>
  window.showSheet(sheet)
}

function main(): none {
  profile := Profile { name: "Ada" }
  window := <Window title="Account" width=440 height=220>
    <Text value=>"Name: ${profile.name}"/>
  </Window>
  window.content.append(
    <Button title="Edit…" onClick=>editProfile(window, profile)/>,
  )
  window.show()
  runApp()
}
```

Try blanking the name and pressing Return: validation reveals an error and
keeps the sheet open. Enter a new name and press Escape: the original remains.
Reopen and save: the parent window refreshes after the sheet closes. The
parent must be shown before `showSheet`, and it can present only one alert or
sheet at a time.
