import { NativeWindow } from "./native"
import { bindBool, initialBool, syncUI } from "./runtime"
import { ToolbarDisplayMode } from "./types"

export class ToolbarItem {
  readonly id: string
  readonly label: string
  readonly symbol: string = ""
  readonly toolTip: string = ""
  readonly enabled: bool | ((): bool) = true
  readonly onClick: (): none = (): none => {}
  readonly kind: int = 0
}

export function ToolbarSpace(): ToolbarItem {
  return ToolbarItem { id: "space", label: "", kind: 1 }
}

export function ToolbarFlexibleSpace(): ToolbarItem {
  return ToolbarItem { id: "flexible-space", label: "", kind: 2 }
}

export class Toolbar {
  readonly children: ToolbarItem[] = []
  readonly displayMode: ToolbarDisplayMode = .Default
  readonly allowsCustomization: bool = false

  install(window: NativeWindow): none {
    let ids: string[] = []
    let labels: string[] = []
    let symbols: string[] = []
    let toolTips: string[] = []
    let kinds: int[] = []
    let enabled: bool[] = []
    let handlers: ((value: string, checked: bool): none)[] = []
    let customIds: string[] = []

    for item of children {
      if item.kind == 0 {
        if item.id.trim() == "" { panic("ToolbarItem id must not be empty") }
        if item.label.trim() == "" { panic("ToolbarItem label must not be empty") }
        if customIds.contains(item.id) { panic("ToolbarItem ids must be unique within a Toolbar") }
        customIds.push(item.id)
      }
      ids.push(item.id)
      labels.push(item.label)
      symbols.push(item.symbol)
      toolTips.push(item.toolTip)
      kinds.push(item.kind)
      enabled.push(initialBool(item.enabled))
      handlers.push((value: string, checked: bool): none => { item.onClick(); syncUI() })
    }

    window.setToolbar(ids, labels, symbols, toolTips, kinds, enabled, handlers, displayMode.value, allowsCustomization)
    let index = 0
    for item of children {
      if item.kind == 0 {
        currentIndex := index
        bindBool(item.enabled, (next): none => window.setToolbarItemEnabled(currentIndex, next))
      }
      index += 1
    }
  }
}
