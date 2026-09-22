export struct LayoutPoint {
  readonly x: double = 0.0
  readonly y: double = 0.0

  static zero(): LayoutPoint => LayoutPoint {}
}

export struct LayoutSize {
  readonly width: double = 0.0
  readonly height: double = 0.0

  static zero(): LayoutSize => LayoutSize {}
}

export struct LayoutRect {
  readonly x: double = 0.0
  readonly y: double = 0.0
  readonly width: double = 0.0
  readonly height: double = 0.0

  static zero(): LayoutRect => LayoutRect {}

  right(): double => x + width
  bottom(): double => y + height
}

export struct LayoutEdges {
  readonly top: double = 0.0
  readonly right: double = 0.0
  readonly bottom: double = 0.0
  readonly left: double = 0.0

  static all(value: double): LayoutEdges {
    return LayoutEdges { top: value, right: value, bottom: value, left: value }
  }

  static symmetric(horizontal: double = 0.0, vertical: double = 0.0): LayoutEdges {
    return LayoutEdges { top: vertical, right: horizontal, bottom: vertical, left: horizontal }
  }

  horizontal(): double => left + right
  vertical(): double => top + bottom
}

export struct LayoutConstraints {
  readonly minWidth: double = 0.0
  readonly maxWidth: double | none = none
  readonly minHeight: double = 0.0
  readonly maxHeight: double | none = none
}

export struct LayoutInterval {
  readonly min: double
  readonly max: double
}

export struct LayoutClip {
  readonly x: LayoutInterval | none = none
  readonly y: LayoutInterval | none = none

  static unbounded(): LayoutClip => LayoutClip {}
}

export enum FlexDirection {
  Row,
  RowReverse,
  Column,
  ColumnReverse,
}

export enum JustifyContent {
  Start,
  Center,
  End,
  SpaceBetween,
  SpaceAround,
  SpaceEvenly,
}

export enum AlignItems {
  Stretch,
  Start,
  Center,
  End,
}

export enum AlignSelf {
  Auto,
  Stretch,
  Start,
  Center,
  End,
}

export enum Overflow {
  Visible,
  Clip,
  Scroll,
}

export enum LayoutPosition {
  Flex,
  Absolute,
}

export class LayoutStyle {
  let position: LayoutPosition = .Flex
  let width: double | none = none
  let height: double | none = none
  let aspectRatio: double | none = none
  let left: double | none = none
  let right: double | none = none
  let top: double | none = none
  let bottom: double | none = none
  let minWidth: double = 0.0
  let maxWidth: double | none = none
  let minHeight: double = 0.0
  let maxHeight: double | none = none
  let margin: LayoutEdges = LayoutEdges {}
  let padding: LayoutEdges = LayoutEdges {}
  let gap: double = 0.0
  let flexBasis: double | none = none
  let grow: double = 0.0
  let shrink: double = 1.0
  let direction: FlexDirection = .Row
  let justifyContent: JustifyContent = .Start
  let alignItems: AlignItems = .Stretch
  let alignSelf: AlignSelf = .Auto
  let overflowX: Overflow = .Visible
  let overflowY: Overflow = .Visible
}

export class LayoutPlacement {
  readonly layoutBounds: LayoutRect
  readonly bounds: LayoutRect
  readonly visibleBounds: LayoutRect | none
  readonly contentRect: LayoutRect
  readonly contentBounds: LayoutRect
  readonly clip: LayoutClip
  readonly scrollExtent: LayoutSize
  readonly requestedScrollOffset: LayoutPoint
  readonly scrollOffset: LayoutPoint
}

export type LayoutMeasure = (constraints: LayoutConstraints): LayoutSize
export type LayoutCallback = (placement: LayoutPlacement): none
