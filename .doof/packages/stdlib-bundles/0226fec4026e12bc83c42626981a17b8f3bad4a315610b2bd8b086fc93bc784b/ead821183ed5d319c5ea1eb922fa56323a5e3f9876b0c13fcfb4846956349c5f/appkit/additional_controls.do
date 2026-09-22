import { NativeView } from "./native"
import { Text } from "./controls"
import { bindBool, bindDouble, bindInt, bindString, initialDouble, initialInt, initialString, syncUI } from "./runtime"
import { Column, Row, View, measuredControl } from "./view"

export function SearchField(
  label: string | ((): string),
  value: string | ((): string) = "",
  placeholder: string = "Search",
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  labelView := Text(label)
  native := NativeView.searchField(initialString(value), placeholder)
  field := measuredControl(native)
  bindString(value, (next): none => native.setText(next))
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  field.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, field]).hidden(hidden)
}

export function Stepper(
  label: string | ((): string),
  value: double | ((): double) = 0.0,
  minimum: double = 0.0,
  maximum: double = 100.0,
  increment: double = 1.0,
  onChange: (value: double): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if minimum >= maximum { panic("Stepper minimum must be less than maximum") }
  if increment <= 0.0 { panic("Stepper increment must be positive") }
  labelView := Text(label)
  native := NativeView.stepper(initialDouble(value), minimum, maximum, increment)
  stepper := measuredControl(native)
  bindDouble(value, (next): none => native.setValue(next))
  native.setValueAction((next: double): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  stepper.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, stepper]).hidden(hidden)
}

export function SegmentedControl(
  label: string | ((): string),
  segments: string[],
  selectedIndex: int | ((): int) = 0,
  onChange: (selectedIndex: int): none = (selectedIndex): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if segments.length == 0 { panic("SegmentedControl requires at least one segment") }
  initial := initialInt(selectedIndex)
  if initial < 0 || initial >= segments.length { panic("SegmentedControl selectedIndex is out of range") }
  labelView := Text(label)
  native := NativeView.segmentedControl(segments, initial)
  control := measuredControl(native)
  bindInt(selectedIndex, (next): none => {
    if next < 0 || next >= segments.length { panic("SegmentedControl selectedIndex is out of range") }
    native.setSelectedIndex(next)
  })
  native.setIndexAction((next: int): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  control.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, control]).hidden(hidden)
}

export function Separator(hidden: bool | ((): bool) = false): View {
  return measuredControl(NativeView.separator()).hidden(hidden)
}

export function Spinner(
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "Loading",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  return measuredControl(NativeView.spinner())
    .hidden(hidden)
    .accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
}

export function Switch(
  title: string | ((): string),
  checked: bool | ((): bool) = false,
  onChange: (checked: bool): none = (checked): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  labelView := Text(title)
  native := NativeView.switchControl(false)
  control := measuredControl(native)
  bindBool(checked, (next): none => native.setChecked(next))
  native.setAction((value: string, next: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  control.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Row([labelView, control]).hidden(hidden)
}
