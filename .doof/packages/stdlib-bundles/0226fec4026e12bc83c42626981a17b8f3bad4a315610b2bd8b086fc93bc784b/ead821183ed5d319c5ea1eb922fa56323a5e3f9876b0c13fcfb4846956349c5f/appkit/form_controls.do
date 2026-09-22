import { Date } from "std/time"

import { NativeView } from "./native"
import { Text } from "./controls"
import { bindColor, bindString, initialColor, initialString, syncUI } from "./runtime"
import { Color } from "./types"
import { Column, View, measuredControl } from "./view"

export function TextArea(
  label: string | ((): string),
  value: string | ((): string) = "",
  minHeight: double = 120.0,
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if minHeight <= 0.0 { panic("TextArea minHeight must be positive") }
  labelView := Text(label)
  native := NativeView.textArea(initialString(value))
  area := measuredControl(native)
  area.node.style.minHeight = minHeight
  bindString(value, (next): none => native.setText(next))
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  area.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, area]).hidden(hidden)
}

export function RadioGroup(
  label: string | ((): string),
  options: string[],
  selected: string | ((): string),
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if options.length == 0 { panic("RadioGroup requires at least one option") }
  initial := initialString(selected)
  requireOption(options, initial)
  labelView := Text(label)
  native := NativeView.radioGroup(options, initial)
  control := measuredControl(native)
  bindString(selected, (next): none => { requireOption(options, next); native.setSelectedValue(next) })
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  control.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, control]).hidden(hidden)
}

export function ComboBox(
  label: string | ((): string),
  options: string[] = [],
  value: string | ((): string) = "",
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  labelView := Text(label)
  native := NativeView.comboBox(options, initialString(value))
  control := measuredControl(native)
  bindString(value, (next): none => native.setText(next))
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  control.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, control]).hidden(hidden)
}

export function DatePicker(
  label: string | ((): string),
  value: Date | ((): Date),
  onChange: (value: Date): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  labelView := Text(label)
  native := NativeView.datePicker(initialDate(value).toISOString())
  control := measuredControl(native)
  bindDate(value, (next): none => native.setDate(next.toISOString()))
  native.setAction((next: string, checked: bool): none => {
    onChange(try! Date.parse(next))
    syncUI()
  })
  native.setTitleElement(labelView.native)
  control.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, control]).hidden(hidden)
}

export function ColorWell(
  label: string | ((): string),
  value: Color | ((): Color) = Color { red: 0.0, green: 0.0, blue: 0.0 },
  onChange: (value: Color): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  initial := initialColor(value)
  requireColor(initial)
  labelView := Text(label)
  native := NativeView.colorWell(initial.red, initial.green, initial.blue, initial.alpha)
  control := measuredControl(native)
  bindColor(value, (next): none => {
    requireColor(next)
    native.setColor(next.red, next.green, next.blue, next.alpha)
  })
  native.setColorAction((red: double, green: double, blue: double, alpha: double): none => {
    onChange(Color { red, green, blue, alpha })
    syncUI()
  })
  native.setTitleElement(labelView.native)
  control.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, control]).hidden(hidden)
}

function initialDate(value: Date | ((): Date)): Date {
  dateValue := value as Date else {
    getter := value as ((): Date) else { panic("Reactive date value is invalid") }
    return getter()
  }
  return dateValue
}

function bindDate(value: Date | ((): Date), apply: (value: Date): none): none {
  dateValue := value as Date else {
    getter := value as ((): Date) else { panic("Reactive date value is invalid") }
    bindString((): string => getter().toISOString(), (next): none => apply(try! Date.parse(next)))
    return
  }
  apply(dateValue)
}

function requireOption(options: string[], selected: string): none {
  for option of options { if option == selected { return } }
  panic("RadioGroup selected value must match an option")
}

function requireColor(value: Color): none {
  if value.red < 0.0 || value.red > 1.0 || value.green < 0.0 || value.green > 1.0 ||
     value.blue < 0.0 || value.blue > 1.0 || value.alpha < 0.0 || value.alpha > 1.0 {
    panic("Color components must be between 0 and 1")
  }
}
