import { NativeApplication } from "./native"
import { bindBool, initialBool, syncUI } from "./runtime"

// Stable wire values consumed by NativeApplication::setMenu in native_appkit.mm.
// These describe a node's shape; they are not positions in the menu tree.
readonly NODE_MENU = 0
readonly NODE_ITEM = 1
readonly NODE_SEPARATOR = 2

// Stable wire values consumed by the role handling in NativeApplication::setMenu.
// Roles connect special submenus to NSApplication so AppKit can populate Services
// and the window list, and can recognize the application and Help menus.
readonly MENU_NORMAL = 0
readonly MENU_APPLICATION = 1
readonly MENU_SERVICES = 2
readonly MENU_WINDOW = 3
readonly MENU_HELP = 4

// Stable semantic action IDs mapped to AppKit selectors by actionSelector in
// native_appkit.mm. Do not reorder or reuse a value without updating that switch
// and the native-menu tests. These are action IDs, not menu-item indices.
readonly ACTION_CUSTOM = 0
readonly ACTION_ABOUT = 1
readonly ACTION_HIDE = 2
readonly ACTION_HIDE_OTHERS = 3
readonly ACTION_SHOW_ALL = 4
readonly ACTION_QUIT = 5
readonly ACTION_UNDO = 6
readonly ACTION_REDO = 7
readonly ACTION_CUT = 8
readonly ACTION_COPY = 9
readonly ACTION_PASTE = 10
readonly ACTION_DELETE = 11
readonly ACTION_SELECT_ALL = 12
readonly ACTION_TOGGLE_TOOLBAR = 13
readonly ACTION_CUSTOMIZE_TOOLBAR = 14
readonly ACTION_TOGGLE_FULL_SCREEN = 15
readonly ACTION_MINIMIZE = 16
readonly ACTION_ZOOM = 17
readonly ACTION_BRING_ALL_TO_FRONT = 18

export enum MenuModifier { Command, Shift, Option, Control }

export class MenuShortcut {
  readonly key: string
  readonly modifiers: readonly MenuModifier[] = [.Command]
}

export class MenuItem {
  readonly title: string
  readonly onSelect: (): none
  readonly shortcut: MenuShortcut | none = none
  readonly enabled: bool | ((): bool) = true
  readonly checked: bool | ((): bool) = false
  private readonly action: int = ACTION_CUSTOM
}

export class MenuSeparator {}

export type MenuElement = Menu | MenuItem | MenuSeparator

export class Menu {
  readonly title: string
  children: MenuElement[] = []
  private readonly role: int = MENU_NORMAL
}

function specialMenu(title: string, role: int, children: MenuElement[]): Menu {
  return Menu { title, children, role }
}

function standardItem(title: string, action: int, shortcut: MenuShortcut | none = none): MenuItem {
  // Standard items deliberately carry no meaningful Doof callback. Their action
  // ID is resolved to a native responder-chain selector at the other end of the
  // bridge, which gives editing and window commands contextual AppKit behavior.
  return MenuItem {
    title,
    onSelect: (): none => {},
    shortcut,
    enabled: true,
    checked: false,
    action,
  }
}

function shortcut(key: string, modifiers: readonly MenuModifier[] = [.Command]): MenuShortcut {
  return MenuShortcut { key, modifiers }
}

export function ApplicationMenu(children: MenuElement[] = []): Menu {
  return specialMenu("", MENU_APPLICATION, children)
}

export function ServicesMenu(): Menu {
  return specialMenu("Services", MENU_SERVICES, [])
}

export function WindowMenu(children: MenuElement[] = []): Menu {
  return specialMenu("Window", MENU_WINDOW, children)
}

export function HelpMenu(children: MenuElement[] = []): Menu {
  return specialMenu("Help", MENU_HELP, children)
}

export function AboutMenuItem(): MenuItem => standardItem("", ACTION_ABOUT)

export function SettingsMenuItem(onSelect: (): none): MenuItem {
  return MenuItem("Settings…", onSelect, shortcut(","))
}

export function HideMenuItem(): MenuItem => standardItem("", ACTION_HIDE, shortcut("h"))
export function HideOthersMenuItem(): MenuItem => standardItem("Hide Others", ACTION_HIDE_OTHERS, shortcut("h", [.Command, .Option]))
export function ShowAllMenuItem(): MenuItem => standardItem("Show All", ACTION_SHOW_ALL)
export function QuitMenuItem(): MenuItem => standardItem("", ACTION_QUIT, shortcut("q"))
export function UndoMenuItem(): MenuItem => standardItem("Undo", ACTION_UNDO, shortcut("z"))
export function RedoMenuItem(): MenuItem => standardItem("Redo", ACTION_REDO, shortcut("z", [.Command, .Shift]))
export function CutMenuItem(): MenuItem => standardItem("Cut", ACTION_CUT, shortcut("x"))
export function CopyMenuItem(): MenuItem => standardItem("Copy", ACTION_COPY, shortcut("c"))
export function PasteMenuItem(): MenuItem => standardItem("Paste", ACTION_PASTE, shortcut("v"))
export function DeleteMenuItem(): MenuItem => standardItem("Delete", ACTION_DELETE)
export function SelectAllMenuItem(): MenuItem => standardItem("Select All", ACTION_SELECT_ALL, shortcut("a"))
export function ToggleToolbarMenuItem(): MenuItem => standardItem("Show Toolbar", ACTION_TOGGLE_TOOLBAR, shortcut("t", [.Command, .Option]))
export function CustomizeToolbarMenuItem(): MenuItem => standardItem("Customize Toolbar…", ACTION_CUSTOMIZE_TOOLBAR)
export function ToggleFullScreenMenuItem(): MenuItem => standardItem("Enter Full Screen", ACTION_TOGGLE_FULL_SCREEN, shortcut("f", [.Command, .Control]))
export function MinimizeMenuItem(): MenuItem => standardItem("Minimize", ACTION_MINIMIZE, shortcut("m"))
export function ZoomMenuItem(): MenuItem => standardItem("Zoom", ACTION_ZOOM)
export function BringAllToFrontMenuItem(): MenuItem => standardItem("Bring All to Front", ACTION_BRING_ALL_TO_FRONT)

export function StandardApplicationMenu(onSettings: ((): none) | none = none): Menu {
  let children: MenuElement[] = [AboutMenuItem(), MenuSeparator()]
  settings := onSettings as ((): none) else {
    children.push(ServicesMenu())
    children.push(MenuSeparator())
    children.push(HideMenuItem())
    children.push(HideOthersMenuItem())
    children.push(ShowAllMenuItem())
    children.push(MenuSeparator())
    children.push(QuitMenuItem())
    return ApplicationMenu(children)
  }
  children.push(SettingsMenuItem(settings))
  children.push(MenuSeparator())
  children.push(ServicesMenu())
  children.push(MenuSeparator())
  children.push(HideMenuItem())
  children.push(HideOthersMenuItem())
  children.push(ShowAllMenuItem())
  children.push(MenuSeparator())
  children.push(QuitMenuItem())
  return ApplicationMenu(children)
}

export function StandardEditMenu(): Menu {
  return Menu("Edit", [
    UndoMenuItem(), RedoMenuItem(), MenuSeparator(),
    CutMenuItem(), CopyMenuItem(), PasteMenuItem(), DeleteMenuItem(), MenuSeparator(),
    SelectAllMenuItem(),
  ])
}

export function StandardViewMenu(): Menu {
  return Menu("View", [
    ToggleToolbarMenuItem(), CustomizeToolbarMenuItem(), MenuSeparator(), ToggleFullScreenMenuItem(),
  ])
}

export function StandardWindowMenu(): Menu {
  return WindowMenu([
    MinimizeMenuItem(), ZoomMenuItem(), MenuSeparator(), BringAllToFrontMenuItem(),
  ])
}

export function defaultAppMenus(): Menu[] {
  return [StandardApplicationMenu(), StandardEditMenu(), StandardViewMenu(), StandardWindowMenu()]
}

export class PreparedMenus {
  nodeKinds: int[] = []
  parentIndices: int[] = []
  menuRoles: int[] = []
  actions: int[] = []
  titles: string[] = []
  keys: string[] = []
  modifierMasks: int[] = []
  enabled: bool[] = []
  checked: bool[] = []
  handlerIndices: int[] = []
  handlers: ((value: string, checked: bool): none)[] = []
  private reactiveItems: MenuItem[] = []
  private reactiveIndices: int[] = []
}

class MenuValidation {
  let applications = 0
  let services = 0
  let windows = 0
  let helps = 0
}

function modifierMask(value: MenuShortcut): int {
  if value.key.length == 0 { panic("menu shortcut keys must not be empty") }
  // Wire bits mirrored by the NSEventModifierFlags conversion in
  // NativeApplication::setMenu in native_appkit.mm.
  let result = 0
  if value.modifiers.contains(MenuModifier.Command) { result += 1 }
  if value.modifiers.contains(MenuModifier.Shift) { result += 2 }
  if value.modifiers.contains(MenuModifier.Option) { result += 4 }
  if value.modifiers.contains(MenuModifier.Control) { result += 8 }
  return result
}

function appendNode(
  prepared: PreparedMenus,
  kind: int,
  parentIndex: int,
  menuRole: int,
  action: int,
  title: string,
  key: string = "",
  modifiers: int = 0,
  enabled: bool = true,
  checked: bool = false,
  handlerIndex: int = -1,
): int {
  index := prepared.nodeKinds.length
  prepared.nodeKinds.push(kind)
  prepared.parentIndices.push(parentIndex)
  prepared.menuRoles.push(menuRole)
  prepared.actions.push(action)
  prepared.titles.push(title)
  prepared.keys.push(key)
  prepared.modifierMasks.push(modifiers)
  prepared.enabled.push(enabled)
  prepared.checked.push(checked)
  prepared.handlerIndices.push(handlerIndex)
  return index
}

function appendItem(prepared: PreparedMenus, item: MenuItem, parentIndex: int): none {
  if item.action == ACTION_CUSTOM && item.title.trim() == "" { panic("menu item titles must not be empty") }
  let key = ""
  let modifiers = 0
  if item.shortcut != none {
    key = item.shortcut!.key
    modifiers = modifierMask(item.shortcut!)
  }
  let handlerIndex = -1
  if item.action == ACTION_CUSTOM {
    handlerIndex = prepared.handlers.length
    prepared.handlers.push((value: string, checked: bool): none => { item.onSelect(); syncUI() })
  }
  nodeIndex := appendNode(
    prepared, NODE_ITEM, parentIndex, MENU_NORMAL, item.action, item.title,
    key, modifiers, initialBool(item.enabled), initialBool(item.checked), handlerIndex,
  )
  if item.action == ACTION_CUSTOM {
    prepared.reactiveItems.push(item)
    prepared.reactiveIndices.push(nodeIndex)
  }
}

function appendMenu(
  prepared: PreparedMenus,
  menu: Menu,
  parentIndex: int,
  depth: int,
  parentRole: int,
  validation: MenuValidation,
): none {
  if menu.role == MENU_NORMAL && menu.title.trim() == "" { panic("menu titles must not be empty") }
  if menu.role == MENU_APPLICATION {
    if depth != 0 { panic("ApplicationMenu must be a top-level menu") }
    validation.applications += 1
    if validation.applications > 1 { panic("an application menu may only appear once") }
  } else if menu.role == MENU_SERVICES {
    if depth != 1 || parentRole != MENU_APPLICATION { panic("ServicesMenu must be a direct child of ApplicationMenu") }
    validation.services += 1
    if validation.services > 1 { panic("a services menu may only appear once") }
  } else if menu.role == MENU_WINDOW {
    if depth != 0 { panic("WindowMenu must be a top-level menu") }
    validation.windows += 1
    if validation.windows > 1 { panic("a window menu may only appear once") }
  } else if menu.role == MENU_HELP {
    if depth != 0 { panic("HelpMenu must be a top-level menu") }
    validation.helps += 1
    if validation.helps > 1 { panic("a help menu may only appear once") }
  }

  index := appendNode(prepared, NODE_MENU, parentIndex, menu.role, ACTION_CUSTOM, menu.title)
  for child of menu.children {
    childMenu := child as Menu else {
      childItem := child as MenuItem else {
        _ := child as MenuSeparator else { panic("invalid menu element") }
        appendNode(prepared, NODE_SEPARATOR, index, MENU_NORMAL, ACTION_CUSTOM, "")
        continue
      }
      appendItem(prepared, childItem, index)
      continue
    }
    appendMenu(prepared, childMenu, index, depth + 1, menu.role, validation)
  }
}

export function prepareAppMenus(menus: Menu[]): PreparedMenus {
  prepared := PreparedMenus {}
  if menus.length == 0 { return prepared }
  if menus[0].role != MENU_APPLICATION { panic("the first menu must be an ApplicationMenu") }
  validation := MenuValidation {}
  for menu of menus { appendMenu(prepared, menu, -1, 0, MENU_NORMAL, validation) }
  if validation.applications != 1 { panic("a nonempty menu bar requires one ApplicationMenu") }
  return prepared
}

export function installAppMenus(app: NativeApplication, menus: Menu[]): none {
  prepared := prepareAppMenus(menus)
  app.setMenu(
    prepared.nodeKinds,
    prepared.parentIndices,
    prepared.menuRoles,
    prepared.actions,
    prepared.titles,
    prepared.keys,
    prepared.modifierMasks,
    prepared.enabled,
    prepared.checked,
    prepared.handlerIndices,
    prepared.handlers,
  )
  let reactiveIndex = 0
  for item of prepared.reactiveItems {
    nodeIndex := prepared.reactiveIndices[reactiveIndex]
    bindBool(item.enabled, (value): none => app.setMenuItemEnabled(nodeIndex, value))
    bindBool(item.checked, (value): none => app.setMenuItemChecked(nodeIndex, value))
    reactiveIndex += 1
  }
}
