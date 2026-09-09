export enum Axis { Horizontal, Vertical }
export enum AlertStyle { Informational, Warning, Critical }
export enum ToolbarDisplayMode { Default, IconOnly, LabelOnly, IconAndLabel }

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
