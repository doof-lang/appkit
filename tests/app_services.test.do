import { Assert } from "std/assert"
import { formatJsonValue, parseJsonObject, parseJsonValue } from "std/json"

import { Window, setActivationPolicy } from "../app"
import { Button, SecureTextField, TextField } from "../controls"
import { Tile } from "../tile"
import { ButtonRole, Tint } from "../types"
import { NativeApplication, NativeView } from "../native"
import { CloseWindowMenuItem, Menu, StandardApplicationMenu, installAppMenus } from "../menu"

function snapshot(native: NativeView): SerialObject => parseJsonObject(native.controlSnapshot())!

export function testButtonRolesUseStandardKeys(): none {
  Assert.equal(snapshot(Button{ title: "Save", role: .Default }.native).get("keyEquivalent")!, "\r")
  escape := formatJsonValue(snapshot(Button{ title: "Cancel", role: ButtonRole.Cancel }.native).get("keyEquivalent")!)
  Assert.equal(escape.toLowerCase(), "\"\\u001b\"", "Cancel does not respond to Escape")
  Assert.equal(snapshot(Button("Other").native).get("keyEquivalent")!, "")
}

export function testButtonSymbolsAreOptional(): none {
  Assert.equal(snapshot(Button{ title: "Edit", symbol: "square.and.pencil" }.native).get("hasImage")!, true)
  Assert.equal(snapshot(Button("Plain").native).get("hasImage")!, false)
}

export function testTilesKeepButtonBehavior(): none {
  tile := <Tile title="Production server" symbol="network" tint=.Blue toolTip="Connect over SSH"
    accessibilityIdentifier="tile"/>
  values := snapshot(tile.native)
  Assert.equal(values.get("tile")!, true)
  Assert.equal(values.get("hasImage")!, true)
  Assert.equal(values.get("toolTip")!, "Connect over SSH")
  for tint of [Tint.Accent, Tint.Purple, Tint.Gray] { Tile("Any", "terminal", tint) }
}

export function testWindowOptionsReachAppKit(): none {
  let closes = 0
  window := <Window title="Options" width=320 height=200 minWidth=300.0 minHeight=180.0
    autosaveName="doof-appkit-tests.options" onClose={(): none => { closes += 1 }}>
    <TextField label="Name" accessibilityIdentifier="name"/>
    <SecureTextField label="Password" accessibilityIdentifier="password" autofocus=true/>
  </Window>
  window.show()
  values := parseJsonObject(window.nativeSnapshot())!
  Assert.equal(values.get("autosaveName")!, "doof-appkit-tests.options")
  Assert.equal(formatJsonValue(values.get("minWidth")!), "300")
  Assert.equal(formatJsonValue(values.get("minHeight")!), "180")
  Assert.equal(values.get("focusIdentifier")!, "password", "Autofocus field was not first responder")
  window.close()
  Assert.equal(closes, 1, "onClose did not run")
  // A replacement window can take over the name of a closed one.
  replacement := Window{ title: "Replacement", width: 320, height: 200, autosaveName: "doof-appkit-tests.options" }
  replacement.show()
  Assert.equal(parseJsonObject(replacement.nativeSnapshot())!.get("autosaveName")!, "doof-appkit-tests.options")
  replacement.close()
}

export function testActivationPolicyCanChange(): none {
  setActivationPolicy(.Accessory)
  setActivationPolicy(.Regular)
}

export function testCloseWindowMenuItemUsesTheResponderChain(): none {
  app := NativeApplication.shared()
  installAppMenus(app, [StandardApplicationMenu(), Menu("File", [CloseWindowMenuItem()])])
  root := (parseJsonValue(app.menuSnapshot()) as SerialObject)!
  menus := (root.get("menus")! as readonly SerialValue[])!
  close := ((((menus[1] as SerialObject)!).get("children")! as readonly SerialValue[])![0] as SerialObject)!
  Assert.equal(close.get("action")!, "performClose:")
  Assert.equal(close.get("key")!, "w")
}
