export enum Axis { Horizontal, Vertical }
export enum AlertStyle { Informational, Warning, Critical }
export enum ToolbarDisplayMode { Default, IconOnly, LabelOnly, IconAndLabel }
// Default responds to Return and draws as the window's default button; Cancel responds to Escape.
export enum ButtonRole { Normal, Default, Cancel }
// System colors that adapt to appearance. Accent follows the user's accent color.
export enum Tint { Accent, Blue, Purple, Orange, Teal, Green, Red, Pink, Yellow, Gray }
// Accessory apps have no Dock icon or menu bar, for helpers and agents.
export enum ActivationPolicy { Regular, Accessory }

export struct Color {
  readonly red: double
  readonly green: double
  readonly blue: double
  readonly alpha: double = 1.0

  static readonly black = Color { red: 0.0, green: 0.0, blue: 0.0 }
  static readonly white = Color { red: 1.0, green: 1.0, blue: 1.0 }
}

export class FileDialogOptions {
  readonly title: string = ""
  readonly suggestedName: string = ""
  readonly directories: bool = false
  readonly multiple: bool = false
}
