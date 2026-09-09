import { LayoutRect, layout } from "std/layout"

import { registerLayoutInvalidator, syncUI } from "./runtime"
import { View, ViewElement, windowContent } from "./view"

export class SheetAction {
  readonly title: string
  readonly onClick: ((): none) | none = none
  readonly validate: ((): bool) | none = none
  readonly destructive: bool = false
}

export class Sheet {
  readonly title: string
  readonly width: int
  readonly height: int
  readonly primary: SheetAction | none
  readonly alternatives: SheetAction[]
  readonly cancel: SheetAction | none
  private content: View
  private let lastWidth = 0.0
  private let lastHeight = 0.0

  static constructor(
    title: string = "",
    width: int = 480,
    height: int = 320,
    primary: SheetAction | none = SheetAction("Done"),
    alternatives: readonly SheetAction[] = [],
    cancel: SheetAction | none = none,
    children: ViewElement[] = [],
  ): Sheet {
    if width <= 0 || height <= 0 { panic("sheet dimensions must be positive") }
    sheet := Sheet {
      title,
      width,
      height,
      primary,
      alternatives,
      cancel,
      content: windowContent(children),
    }
    registerLayoutInvalidator((): none => {
      if sheet.lastWidth > 0.0 && sheet.lastHeight > 0.0 {
        sheet.relayout(sheet.lastWidth, sheet.lastHeight)
      }
    })
    return sheet
  }

  contentView(): View => content

  relayout(width: double, height: double): none {
    lastWidth = width
    lastHeight = height
    content.prepareLayout()
    layout(content.layoutNode(), LayoutRect { width, height })
  }
}

export class PreparedSheet {
  let primaryIndex = -1
  let cancelIndex = -1
  titles: string[] = []
  destructive: bool[] = []
  handlers: ((): none)[] = []
  validators: ((): bool)[] = []

  append(action: SheetAction): int {
    if action.title == "" { panic("sheet action titles cannot be empty") }
    index := titles.length
    titles.push(action.title)
    destructive.push(action.destructive)

    handler := action.onClick as ((): none) else {
      handlers.push((): none => {})
      appendValidator(action)
      return index
    }
    handlers.push(handler)
    appendValidator(action)
    return index
  }

  appendOptional(action: SheetAction | none): int {
    value := action as SheetAction else { return -1 }
    return append(value)
  }

  validate(index: int): bool {
    if index < 0 || index >= validators.length { return false }
    valid := validators[index]()
    syncUI()
    return valid
  }

  perform(index: int): none {
    if index >= 0 && index < handlers.length { handlers[index]() }
    syncUI()
  }

  private appendValidator(action: SheetAction): none {
    validator := action.validate as ((): bool) else {
      validators.push((): bool => true)
      return
    }
    validators.push(validator)
  }
}

export function prepareSheet(sheet: Sheet): PreparedSheet {
  prepared := PreparedSheet {}
  prepared.primaryIndex = prepared.appendOptional(sheet.primary)
  for action of sheet.alternatives { prepared.append(action) }
  prepared.cancelIndex = prepared.appendOptional(sheet.cancel)
  if prepared.titles.length == 0 { panic("a sheet requires at least one action") }
  return prepared
}
