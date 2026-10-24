import { Assert } from "std/assert"
import { parseJsonValue } from "std/json"

import { NativeApplication } from "../native"
import {
  ApplicationMenu,
  DynamicMenu,
  Menu,
  MenuElement,
  MenuItem,
  MenuSeparator,
  MenuShortcut,
  WindowMenu,
  installAppMenus,
  prepareAppMenus,
  prepareDynamicMenu,
} from "../menu"

class Recents {
  let names: string[] = []
  let opened = ""
}

function recentItems(recents: Recents): MenuElement[] {
  items: MenuElement[] := []
  let digit = 1
  for name of recents.names {
    items.push(MenuItem {
      title: name,
      onSelect: (): none => { recents.opened = name },
      shortcut: MenuShortcut { key: "${digit}" },
    })
    digit += 1
  }
  if items.length == 0 { items.push(MenuItem { title: "No Recent Items", onSelect: (): none => {}, enabled: false }) }
  return items
}

function childTitles(menu: SerialObject): string[] {
  titles: string[] := []
  for child of (menu.get("children")! as readonly SerialValue[])! {
    titles.push(((child as SerialObject)!.get("title")! as string)!)
  }
  return titles
}

function assertTitles(menu: SerialObject, expected: string[]): none {
  actual := childTitles(menu)
  Assert.equal(actual.length, expected.length)
  for index of 0..<expected.length { Assert.equal(actual[index], expected[index]) }
}

function topMenu(app: NativeApplication, index: int): SerialObject {
  root := (parseJsonValue(app.menuSnapshot()) as SerialObject)!
  return ((root.get("menus")! as readonly SerialValue[])![index] as SerialObject)!
}

function child(menu: SerialObject, index: int): SerialObject {
  return ((menu.get("children")! as readonly SerialValue[])![index] as SerialObject)!
}

export function testDynamicMenusPrepareABuilderInsteadOfChildren(): none {
  prepared := prepareAppMenus([
    ApplicationMenu(),
    Menu("File", [DynamicMenu("Open Recent", (): MenuElement[] => [])]),
  ])
  Assert.equal(prepared.builders.length, 1)
  Assert.equal(prepared.builderIndices[0], -1)
  Assert.equal(prepared.builderIndices[2], 0)
  Assert.equal(prepared.nodeKinds.length, 3)
}

export function testDynamicContentsAreParentedToTheDynamicMenu(): none {
  prepared := prepareDynamicMenu([
    MenuItem("One", (): none => {}),
    MenuSeparator(),
    Menu("More", [MenuItem("Two", (): none => {})]),
  ])
  Assert.equal(prepared.parentIndices[0], -1)
  Assert.equal(prepared.parentIndices[1], -1)
  Assert.equal(prepared.parentIndices[2], -1)
  Assert.equal(prepared.parentIndices[3], 2)
}

export function testDynamicMenusRejectSpecialRolesAndChildren(): none {
  nestedRole := catchPanic(=> prepareDynamicMenu([WindowMenu()]))
  case nestedRole {
    _: Success -> Assert.fail("expected a window menu inside dynamic contents to panic")
    failure: Failure -> Assert.stringContains(failure.error, "ordinary menus")
  }
  both := catchPanic(=> prepareAppMenus([
    ApplicationMenu(),
    Menu { title: "File", children: [MenuSeparator()], build: (): MenuElement[] => [] },
  ]))
  case both {
    _: Success -> Assert.fail("expected a dynamic menu with children to panic")
    failure: Failure -> Assert.stringContains(failure.error, "children")
  }
}

export function testDynamicMenusRebuildFromCurrentStateWhenOpened(): none {
  app := NativeApplication.shared()
  recents := Recents {}
  let builds = 0
  installAppMenus(app, [
    ApplicationMenu(),
    DynamicMenu("File", (): MenuElement[] => {
      builds += 1
      items: MenuElement[] := [MenuItem("New", (): none => {}), MenuSeparator()]
      items.push(DynamicMenu("Open Recent", (): MenuElement[] => recentItems(recents)))
      return items
    }),
  ])
  Assert.equal(builds, 0, "dynamic menus build lazily")

  file := topMenu(app, 1)
  assertTitles(file, ["New", "", "Open Recent"])
  empty := child(child(file, 2), 0)
  Assert.equal(empty.get("title")!, "No Recent Items")
  Assert.equal(empty.get("enabled")!, false)

  recents.names = ["alpha", "beta"]
  recent := child(topMenu(app, 1), 2)
  assertTitles(recent, ["alpha", "beta"])
  Assert.equal(child(recent, 1).get("key")!, "2")

  Assert.isTrue(app.performMenuPath(["File", "Open Recent", "beta"]))
  Assert.equal(recents.opened, "beta")
  Assert.isFalse(app.performMenuPath(["File", "Open Recent", "gamma"]))

  recents.names = ["gamma"]
  Assert.isTrue(app.performMenuPath(["File", "Open Recent", "gamma"]))
  Assert.equal(recents.opened, "gamma")
  Assert.isTrue(builds >= 3, "File rebuilt on each open")
}

export function testDynamicMenuShortcutsFollowCurrentContents(): none {
  app := NativeApplication.shared()
  recents := Recents { names: ["alpha"] }
  installAppMenus(app, [
    ApplicationMenu(),
    DynamicMenu("Connections", (): MenuElement[] => recentItems(recents)),
  ])
  Assert.isTrue(app.performMenuKeyEquivalent("1", 1))
  Assert.equal(recents.opened, "alpha")
  Assert.isFalse(app.performMenuKeyEquivalent("2", 1), "no second connection yet")

  recents.names = ["alpha", "beta"]
  Assert.isTrue(app.performMenuKeyEquivalent("2", 1))
  Assert.equal(recents.opened, "beta")
}

export function testStaticMenuShortcutsDispatchThroughTheMainMenu(): none {
  app := NativeApplication.shared()
  let runs = 0
  installAppMenus(app, [
    ApplicationMenu(),
    Menu("Tools", [MenuItem("Run", (): none => { runs += 1 }, MenuShortcut { key: "k" })]),
  ])
  Assert.isTrue(app.performMenuKeyEquivalent("k", 1))
  Assert.equal(runs, 1)
}

function noItems(): MenuElement[] => []

export function testDynamicMenusComposeInMarkup(): none {
  file := <Menu title="File">
    <MenuItem title="Open…" onSelect=>{}/>
    {DynamicMenu("Open Recent", noItems)}
    <Menu title="Connections" build=>noItems()/>
  </Menu>
  Assert.equal(file.children.length, 3)
  Assert.isTrue(((file.children[2] as Menu)!).build != none)
}
