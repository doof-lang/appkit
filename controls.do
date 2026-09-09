import { NativeView } from "./native"
import { bindBool, bindDouble, bindString, initialDouble, initialString, syncUI } from "./runtime"
import { Column, View, measuredControl } from "./view"

export function Text(
  value: string | ((): string),
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
  fontSize: double = 13.0,
  semibold: bool = false,
  secondary: bool = false,
): View {
  native := NativeView.text(initialString(value))
  if fontSize <= 0.0 { panic("Text fontSize must be positive") }
  native.setTextStyle(fontSize, semibold, secondary)
  view := measuredControl(native)
  bindString(value, (next): none => native.setText(next))
  view.hidden(hidden).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return view
}

export function Button(
  title: string | ((): string),
  onClick: (): none = (): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  native := NativeView.button(initialString(title))
  view := measuredControl(native)
  bindString(title, (next): none => native.setText(next))
  native.setAction((value: string, checked: bool): none => { onClick(); syncUI() })
  view.enabled(enabled).hidden(hidden).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return view
}

export function Checkbox(
  title: string | ((): string),
  checked: bool | ((): bool) = false,
  onChange: (checked: bool): none = (checked): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  native := NativeView.checkbox(initialString(title), false)
  view := measuredControl(native)
  bindString(title, (next): none => native.setText(next))
  bindBool(checked, (next): none => native.setChecked(next))
  native.setAction((value: string, next: bool): none => { onChange(next); syncUI() })
  view.enabled(enabled).hidden(hidden).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return view
}

export function TextField(
  label: string | ((): string),
  value: string | ((): string) = "",
  placeholder: string = "",
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  labelView := Text(label)
  native := NativeView.textField(initialString(value), placeholder)
  field := measuredControl(native)
  bindString(value, (next): none => native.setText(next))
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  field.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, field]).hidden(hidden)
}

export function SecureTextField(
  label: string | ((): string),
  value: string | ((): string) = "",
  placeholder: string = "",
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  labelView := Text(label)
  native := NativeView.secureTextField(initialString(value), placeholder)
  field := measuredControl(native)
  bindString(value, (next): none => native.setText(next))
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  field.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, field]).hidden(hidden)
}

export function Picker(
  label: string | ((): string),
  options: string[],
  selected: string | ((): string) = "",
  onChange: (value: string): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if options.length == 0 { panic("Picker requires at least one option") }
  labelView := Text(label)
  native := NativeView.picker(options, initialString(selected))
  picker := measuredControl(native)
  bindString(selected, (next): none => native.setSelectedValue(next))
  native.setAction((next: string, checked: bool): none => { onChange(next); syncUI() })
  native.setTitleElement(labelView.native)
  picker.enabled(enabled).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return Column([labelView, picker]).hidden(hidden)
}

export function Slider(
  value: double | ((): double) = 0.0,
  minimum: double = 0.0,
  maximum: double = 1.0,
  onChange: (value: double): none = (value): none => {},
  enabled: bool | ((): bool) = true,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
  minWidth: double = 120.0,
  grow: double = 0.0,
): View {
  if minimum >= maximum { panic("Slider minimum must be less than maximum") }
  if minWidth < 0.0 { panic("Slider minWidth cannot be negative") }
  if grow < 0.0 { panic("Slider grow cannot be negative") }
  native := NativeView.slider(initialDouble(value), minimum, maximum)
  view := measuredControl(native)
  view.layoutNode().style.minWidth = minWidth
  view.layoutNode().style.grow = grow
  if grow > 0.0 { view.layoutNode().style.flexBasis = minWidth }
  bindDouble(value, (next): none => native.setValue(next))
  native.setValueAction((next: double): none => { onChange(next); syncUI() })
  view.enabled(enabled).hidden(hidden).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return view
}

export function ProgressBar(
  value: double | ((): double) = 0.0,
  minimum: double = 0.0,
  maximum: double = 1.0,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if minimum >= maximum { panic("ProgressBar minimum must be less than maximum") }
  native := NativeView.progressBar(initialDouble(value), minimum, maximum)
  view := measuredControl(native)
  bindDouble(value, (next): none => native.setValue(next))
  view.hidden(hidden).accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
  return view
}
