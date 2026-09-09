import { Color } from "./types"

class ReactiveRuntime {
  private let bindings: ((): none)[] = []
  private let invalidators: ((): none)[] = []
  private let syncing = false

  bindString(getter: (): string, apply: (value: string): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next != previous { previous = next; apply(next) }
    })
  }

  bindBool(getter: (): bool, apply: (value: bool): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next != previous { previous = next; apply(next) }
    })
  }

  bindDouble(getter: (): double, apply: (value: double): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next != previous { previous = next; apply(next) }
    })
  }

  bindInt(getter: (): int, apply: (value: int): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next != previous { previous = next; apply(next) }
    })
  }

  bindColor(getter: (): Color, apply: (value: Color): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next.red != previous.red || next.green != previous.green ||
         next.blue != previous.blue || next.alpha != previous.alpha {
        previous = next
        apply(next)
      }
    })
  }

  addInvalidator(invalidator: (): none): none { invalidators.push(invalidator) }

  sync(): none {
    if syncing { return }
    syncing = true
    for binding of bindings { binding() }
    for invalidator of invalidators { invalidator() }
    syncing = false
  }
}

readonly runtime = ReactiveRuntime {}

export function registerLayoutInvalidator(invalidator: (): none): none { runtime.addInvalidator(invalidator) }
export function syncUI(): none { runtime.sync() }

export function initialString(value: string | ((): string)): string {
  stringValue := value as string else {
    getter := value as ((): string) else { panic("Reactive string value is invalid") }
    return getter()
  }
  return stringValue
}

export function initialDouble(value: double | ((): double)): double {
  doubleValue := value as double else {
    getter := value as ((): double) else { panic("Reactive numeric value is invalid") }
    return getter()
  }
  return doubleValue
}

export function initialInt(value: int | ((): int)): int {
  intValue := value as int else {
    getter := value as ((): int) else { panic("Reactive integer value is invalid") }
    return getter()
  }
  return intValue
}

export function initialBool(value: bool | ((): bool)): bool {
  boolValue := value as bool else {
    getter := value as ((): bool) else { panic("Reactive boolean value is invalid") }
    return getter()
  }
  return boolValue
}

export function initialColor(value: Color | ((): Color)): Color {
  colorValue := value as Color else {
    getter := value as ((): Color) else { panic("Reactive color value is invalid") }
    return getter()
  }
  return colorValue
}

export function bindString(value: string | ((): string), apply: (value: string): none): none {
  stringValue := value as string else {
    getter := value as ((): string) else { panic("Reactive string value is invalid") }
    runtime.bindString(getter, apply)
    return
  }
  apply(stringValue)
}

export function bindBool(value: bool | ((): bool), apply: (value: bool): none): none {
  boolValue := value as bool else {
    getter := value as ((): bool) else { panic("Reactive boolean value is invalid") }
    runtime.bindBool(getter, apply)
    return
  }
  apply(boolValue)
}

export function bindDouble(value: double | ((): double), apply: (value: double): none): none {
  doubleValue := value as double else {
    getter := value as ((): double) else { panic("Reactive numeric value is invalid") }
    runtime.bindDouble(getter, apply)
    return
  }
  apply(doubleValue)
}

export function bindInt(value: int | ((): int), apply: (value: int): none): none {
  intValue := value as int else {
    getter := value as ((): int) else { panic("Reactive integer value is invalid") }
    runtime.bindInt(getter, apply)
    return
  }
  apply(intValue)
}

export function bindColor(value: Color | ((): Color), apply: (value: Color): none): none {
  colorValue := value as Color else {
    getter := value as ((): Color) else { panic("Reactive color value is invalid") }
    runtime.bindColor(getter, apply)
    return
  }
  apply(colorValue)
}
