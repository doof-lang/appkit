import { syncUI } from "./runtime"
import { AlertStyle } from "./types"

export class AlertAction {
  readonly title: string
  readonly onClick: ((): none) | none = none
  readonly destructive: bool = false
}

export class Alert {
  readonly title: string
  readonly message: string = ""
  readonly style: AlertStyle = .Informational
  readonly primary: AlertAction | none = AlertAction("OK")
  readonly alternatives: AlertAction[] = []
  readonly cancel: AlertAction | none = none
}

export class PreparedAlert {
  let primaryIndex = -1
  let cancelIndex = -1
  titles: string[] = []
  destructive: bool[] = []
  handlers: ((): none)[] = []

  append(action: AlertAction): int {
    if action.title == "" { panic("alert action titles cannot be empty") }
    index := titles.length
    titles.push(action.title)
    destructive.push(action.destructive)
    handler := action.onClick as ((): none) else {
      handlers.push((): none => {})
      return index
    }
    handlers.push(handler)
    return index
  }

  appendOptional(action: AlertAction | none): int {
    value := action as AlertAction else { return -1 }
    return append(value)
  }

  perform(index: int): none {
    if index >= 0 && index < handlers.length { handlers[index]() }
    syncUI()
  }
}

export function prepareAlert(alert: Alert): PreparedAlert {
  prepared := PreparedAlert {}
  prepared.primaryIndex = prepared.appendOptional(alert.primary)
  for action of alert.alternatives { prepared.append(action) }
  prepared.cancelIndex = prepared.appendOptional(alert.cancel)
  if prepared.titles.length == 0 { panic("an alert requires at least one action") }
  return prepared
}
