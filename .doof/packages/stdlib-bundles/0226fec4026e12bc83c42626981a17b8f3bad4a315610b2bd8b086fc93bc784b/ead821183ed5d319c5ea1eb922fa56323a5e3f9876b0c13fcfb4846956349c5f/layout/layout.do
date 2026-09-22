import { clamp, isfinite, max, min } from "std/math"

import {
  AlignItems,
  AlignSelf,
  FlexDirection,
  JustifyContent,
  LayoutCallback,
  LayoutClip,
  LayoutConstraints,
  LayoutEdges,
  LayoutInterval,
  LayoutMeasure,
  LayoutPlacement,
  LayoutPoint,
  LayoutPosition,
  LayoutRect,
  LayoutSize,
  LayoutStyle,
  Overflow,
} from "./types"

readonly EPSILON = 0.000001

struct JustifiedSpacing {
  readonly leading: double
  readonly between: double
}

struct PreferredSize {
  readonly size: LayoutSize
  readonly widthPreferred: bool
  readonly heightPreferred: bool
  readonly widthFromAspect: bool
  readonly heightFromAspect: bool
}

export class LayoutNode {
  let style: LayoutStyle = LayoutStyle {}
  children: LayoutNode[] = []
  let measure: LayoutMeasure | none = none
  let onPlace: LayoutCallback | none = none

  private let localFrame: LayoutRect = LayoutRect {}
  private let contentBoundsLocal: LayoutRect = LayoutRect {}
  private let subtreeBoundsLocal: LayoutRect = LayoutRect {}
  private let currentPlacement: LayoutPlacement = LayoutPlacement {
    layoutBounds: LayoutRect {},
    bounds: LayoutRect {},
    visibleBounds: none,
    contentRect: LayoutRect {},
    contentBounds: LayoutRect {},
    clip: LayoutClip {},
    scrollExtent: LayoutSize {},
    requestedScrollOffset: LayoutPoint {},
    scrollOffset: LayoutPoint {},
  }
  private let inheritedClip: LayoutClip = LayoutClip {}
  private let requestedScroll: LayoutPoint = LayoutPoint {}
  private let laidOut: bool = false

  layoutBounds(): LayoutRect => currentPlacement.layoutBounds
  bounds(): LayoutRect => currentPlacement.bounds
  visibleBounds(): LayoutRect | none => currentPlacement.visibleBounds
  contentRect(): LayoutRect => currentPlacement.contentRect
  contentBounds(): LayoutRect => currentPlacement.contentBounds
  clip(): LayoutClip => currentPlacement.clip
  scrollExtent(): LayoutSize => currentPlacement.scrollExtent
  requestedScrollOffset(): LayoutPoint => requestedScroll
  scrollOffset(): LayoutPoint => currentPlacement.scrollOffset
  isLaidOut(): bool => laidOut

  scrollTo(x: double, y: double): none {
    requireFinite(x, "scroll x")
    requireFinite(y, "scroll y")
    requestedScroll = LayoutPoint { x, y }
    if laidOut {
      placeNode(this, currentPlacement.bounds, inheritedClip)
      notifyPlaced(this)
    }
  }

  scrollBy(dx: double, dy: double): none {
    scrollTo(requestedScroll.x + dx, requestedScroll.y + dy)
  }
}

export function layout(root: LayoutNode, bounds: LayoutRect): none {
  validateRootBounds(bounds)
  validateTree(root, [], [])

  root.localFrame = bounds
  layoutChildren(root)
  placeNode(root, bounds, LayoutClip.unbounded())
  notifyPlaced(root)
}

// Returns the tree's preferred border-box size without assigning frames or
// invoking placement callbacks. Hosts such as native scroll views use this to
// size content before performing the final layout pass.
export function measureLayout(
  root: LayoutNode,
  constraints: LayoutConstraints = LayoutConstraints {},
): LayoutSize {
  validateConstraints(constraints)
  validateTree(root, [], [])
  preferred := preferredSize(root, constraints).size
  return LayoutSize {
    width: clampDimension(preferred.width, constraints.minWidth, constraints.maxWidth),
    height: clampDimension(preferred.height, constraints.minHeight, constraints.maxHeight),
  }
}

function layoutChildren(node: LayoutNode): none {
  width := node.localFrame.width
  height := node.localFrame.height
  padding := node.style.padding
  contentWidth := max(0.0, width - padding.horizontal())
  contentHeight := max(0.0, height - padding.vertical())
  flexChildren: LayoutNode[] := []
  for child of node.children {
    if child.style.position == LayoutPosition.Flex { flexChildren.push(child) }
  }

  if flexChildren.length > 0 {
    layoutFlexChildren(node, flexChildren, contentWidth, contentHeight)
  }
  for child of node.children {
    if child.style.position == LayoutPosition.Absolute {
      layoutAbsoluteChild(child, padding, contentWidth, contentHeight)
    }
  }
  calculateContentBounds(node, contentWidth, contentHeight)
}

function layoutFlexChildren(
  node: LayoutNode,
  children: LayoutNode[],
  contentWidth: double,
  contentHeight: double,
): none {
  padding := node.style.padding
  count := children.length

  row := isRow(node.style.direction)
  reverse := isReverse(node.style.direction)
  mainAvailable := if row then contentWidth else contentHeight
  crossAvailable := if row then contentHeight else contentWidth

  mainSizes: double[] := []
  desiredCross: double[] := []
  crossPreferred: bool[] := []
  crossFromAspect: bool[] := []
  bases: double[] := []
  frozen: bool[] := []

  for child of children {
    preferred := preferredSize(child, LayoutConstraints {
      maxWidth: contentWidth,
      maxHeight: contentHeight,
    })
    desired := preferred.size
    let base = mainBase(child.style, desired, row)
    base = clampMain(child.style, base, row)
    mainSizes.push(base)
    bases.push(base)
    desiredCross.push(if row then desired.height else desired.width)
    crossPreferred.push(if row then preferred.heightPreferred else preferred.widthPreferred)
    crossFromAspect.push(if row then preferred.heightFromAspect else preferred.widthFromAspect)
    frozen.push(false)
  }

  distributeMainSpace(node, children, mainSizes, bases, frozen, mainAvailable, row)

  used := usedMain(node, children, mainSizes, row)
  leftover := max(0.0, mainAvailable - used)
  spacing := justifySpacing(node.style.justifyContent, leftover, count)
  leading := spacing.leading
  between := node.style.gap + spacing.between
  let cursor = if reverse then mainAvailable - leading else leading

  for index of 0..<count {
    child := children[index]
    before := mainMarginBefore(child.style, row, reverse)
    after := mainMarginAfter(child.style, row, reverse)
    mainSize := mainSizes[index]
    let mainPosition = 0.0

    if reverse {
      cursor -= before
      cursor -= mainSize
      mainPosition = cursor
      cursor -= after
      if index + 1 < count { cursor -= between }
    } else {
      cursor += before
      mainPosition = cursor
      cursor += mainSize + after
      if index + 1 < count { cursor += between }
    }

    alignment := childAlignment(node.style.alignItems, child.style.alignSelf)
    crossBefore := crossMarginBefore(child.style, row)
    crossAfter := crossMarginAfter(child.style, row)
    crossSpace := max(0.0, crossAvailable - crossBefore - crossAfter)
    explicitCross := if row then child.style.height else child.style.width
    let crossSize = desiredCross[index]
    ratio := child.style.aspectRatio
    let aspectResolvedCross = crossFromAspect[index]
    if ratio != none && (!crossPreferred[index] || aspectResolvedCross) {
      crossSize = if row then mainSize / ratio! else mainSize * ratio!
      aspectResolvedCross = true
    }
    if alignment == AlignItems.Stretch && explicitCross == none && !aspectResolvedCross {
      crossSize = crossSpace
    }
    crossSize = clampCross(child.style, crossSize, row)
    crossPosition := crossOffset(alignment, crossAvailable, crossSize, crossBefore, crossAfter)

    child.localFrame = if row then LayoutRect {
      x: padding.left + mainPosition,
      y: padding.top + crossPosition,
      width: mainSize,
      height: crossSize,
    } else LayoutRect {
      x: padding.left + crossPosition,
      y: padding.top + mainPosition,
      width: crossSize,
      height: mainSize,
    }
    layoutChildren(child)
  }
}

function layoutAbsoluteChild(
  child: LayoutNode,
  padding: LayoutEdges,
  contentWidth: double,
  contentHeight: double,
): none {
  style := child.style
  horizontalStretch := style.left != none && style.right != none && style.width == none
  verticalStretch := style.top != none && style.bottom != none && style.height == none
  let stretchedWidth = contentWidth
  let stretchedHeight = contentHeight
  if horizontalStretch {
    stretchedWidth = clampDimension(
      max(0.0, contentWidth - style.left! - style.right! - style.margin.horizontal()),
      style.minWidth,
      style.maxWidth,
    )
  }
  if verticalStretch {
    stretchedHeight = clampDimension(
      max(0.0, contentHeight - style.top! - style.bottom! - style.margin.vertical()),
      style.minHeight,
      style.maxHeight,
    )
  }
  preferred := preferredSize(child, LayoutConstraints {
    maxWidth: stretchedWidth,
    maxHeight: stretchedHeight,
  })
  let width = preferred.size.width
  let height = preferred.size.height
  let widthResolved = preferred.widthPreferred
  let heightResolved = preferred.heightPreferred

  if horizontalStretch {
    width = stretchedWidth
    widthResolved = true
  }
  if verticalStretch {
    height = stretchedHeight
    heightResolved = true
  }

  if style.aspectRatio != none {
    ratio := style.aspectRatio!
    if widthResolved && !heightResolved {
      height = clampDimension(width / ratio, style.minHeight, style.maxHeight)
      heightResolved = true
    } else if heightResolved && !widthResolved {
      width = clampDimension(height * ratio, style.minWidth, style.maxWidth)
      widthResolved = true
    }
  }

  let x = style.margin.left
  if style.left != none {
    x = style.left! + style.margin.left
  } else if style.right != none {
    x = contentWidth - style.right! - style.margin.right - width
  }
  let y = style.margin.top
  if style.top != none {
    y = style.top! + style.margin.top
  } else if style.bottom != none {
    y = contentHeight - style.bottom! - style.margin.bottom - height
  }

  child.localFrame = LayoutRect {
    x: padding.left + x,
    y: padding.top + y,
    width,
    height,
  }
  layoutChildren(child)
}

function distributeMainSpace(
  node: LayoutNode,
  children: LayoutNode[],
  sizes: double[],
  bases: double[],
  frozen: bool[],
  available: double,
  row: bool,
): none {
  for _ of 0..<children.length {
    free := available - usedMain(node, children, sizes, row)
    if free > EPSILON {
      let total = 0.0
      for index of 0..<children.length {
        if !frozen[index] { total += children[index].style.grow }
      }
      if total <= EPSILON { return }

      let hitLimit = false
      for index of 0..<children.length {
        if frozen[index] { continue }
        factor := children[index].style.grow
        proposed := sizes[index] + free * factor / total
        resolved := clampMain(children[index].style, proposed, row)
        sizes[index] = resolved
        if resolved + EPSILON < proposed {
          frozen[index] = true
          hitLimit = true
        }
      }
      if !hitLimit { return }
      continue
    }

    if free < -EPSILON {
      let total = 0.0
      for index of 0..<children.length {
        if !frozen[index] {
          total += children[index].style.shrink * bases[index]
        }
      }
      if total <= EPSILON { return }

      let hitLimit = false
      for index of 0..<children.length {
        if frozen[index] { continue }
        weight := children[index].style.shrink * bases[index]
        proposed := sizes[index] + free * weight / total
        resolved := clampMain(children[index].style, proposed, row)
        sizes[index] = resolved
        if resolved > proposed + EPSILON {
          frozen[index] = true
          hitLimit = true
        }
      }
      if !hitLimit { return }
      continue
    }

    return
  }
}

function preferredSize(node: LayoutNode, constraints: LayoutConstraints): PreferredSize {
  padding := node.style.padding
  maxContentWidth := subtractOptional(constraints.maxWidth, padding.horizontal())
  maxContentHeight := subtractOptional(constraints.maxHeight, padding.vertical())
  let content = LayoutSize {}
  let widthPreferred = false
  let heightPreferred = false

  if node.measure != none {
    content = node.measure!(LayoutConstraints {
      maxWidth: maxContentWidth,
      maxHeight: maxContentHeight,
    })
    validateMeasuredSize(content)
    widthPreferred = true
    heightPreferred = true
  } else {
    row := isRow(node.style.direction)
    let main = 0.0
    let cross = 0.0
    let flexCount = 0
    for child of node.children {
      if child.style.position == LayoutPosition.Absolute { continue }
      desired := preferredSize(child, LayoutConstraints {
        maxWidth: maxContentWidth,
        maxHeight: maxContentHeight,
      }).size
      childMain := if row then desired.width else desired.height
      childCross := if row then desired.height else desired.width
      main += childMain + mainMargins(child.style, row)
      cross = max(cross, childCross + crossMargins(child.style, row))
      if flexCount > 0 { main += node.style.gap }
      flexCount += 1
    }
    if flexCount > 0 {
      content = if row then LayoutSize { width: main, height: cross }
        else LayoutSize { width: cross, height: main }
      widthPreferred = true
      heightPreferred = true
    }
  }

  let width = content.width + padding.horizontal()
  let height = content.height + padding.vertical()
  explicitWidth := node.style.width != none
  explicitHeight := node.style.height != none
  if explicitWidth {
    width = node.style.width!
    widthPreferred = true
  }
  if explicitHeight {
    height = node.style.height!
    heightPreferred = true
  }
  let widthFromAspect = false
  let heightFromAspect = false
  if node.style.aspectRatio != none {
    ratio := node.style.aspectRatio!
    if explicitWidth && !explicitHeight {
      height = width / ratio
      heightPreferred = true
      heightFromAspect = true
    } else if explicitHeight && !explicitWidth {
      width = height * ratio
      widthPreferred = true
      widthFromAspect = true
    } else if !explicitWidth && !explicitHeight {
      if widthPreferred && !heightPreferred {
        height = width / ratio
        heightPreferred = true
        heightFromAspect = true
      } else if heightPreferred && !widthPreferred {
        width = height * ratio
        widthPreferred = true
        widthFromAspect = true
      }
    }
  }
  width = clampDimension(width, node.style.minWidth, node.style.maxWidth)
  height = clampDimension(height, node.style.minHeight, node.style.maxHeight)
  return PreferredSize {
    size: LayoutSize { width, height },
    widthPreferred,
    heightPreferred,
    widthFromAspect,
    heightFromAspect,
  }
}

function calculateContentBounds(node: LayoutNode, viewportWidth: double, viewportHeight: double): none {
  padding := node.style.padding
  let content = LayoutRect { width: viewportWidth, height: viewportHeight }

  for child of node.children {
    shifted := LayoutRect {
      x: child.localFrame.x - padding.left + child.subtreeBoundsLocal.x,
      y: child.localFrame.y - padding.top + child.subtreeBoundsLocal.y,
      width: child.subtreeBoundsLocal.width,
      height: child.subtreeBoundsLocal.height,
    }
    content = unionRects(content, shifted)
  }

  node.contentBoundsLocal = content
  node.subtreeBoundsLocal = unionRects(
    LayoutRect { width: node.localFrame.width, height: node.localFrame.height },
    LayoutRect {
      x: padding.left + content.x,
      y: padding.top + content.y,
      width: content.width,
      height: content.height,
    },
  )
}

function placeNode(node: LayoutNode, bounds: LayoutRect, inherited: LayoutClip): none {
  node.inheritedClip = inherited
  padding := node.style.padding
  contentRect := LayoutRect {
    x: bounds.x + padding.left,
    y: bounds.y + padding.top,
    width: max(0.0, bounds.width - padding.horizontal()),
    height: max(0.0, bounds.height - padding.vertical()),
  }

  let clipX = inherited.x
  let clipY = inherited.y
  if node.style.overflowX != Overflow.Visible {
    clipX = intersectInterval(clipX, LayoutInterval { min: contentRect.x, max: contentRect.right() })
  }
  if node.style.overflowY != Overflow.Visible {
    clipY = intersectInterval(clipY, LayoutInterval { min: contentRect.y, max: contentRect.bottom() })
  }
  effectiveClip := LayoutClip { x: clipX, y: clipY }

  extentWidth := max(contentRect.width, max(0.0, node.contentBoundsLocal.right()))
  extentHeight := max(contentRect.height, max(0.0, node.contentBoundsLocal.bottom()))
  maxScrollX := max(0.0, extentWidth - contentRect.width)
  maxScrollY := max(0.0, extentHeight - contentRect.height)
  resolvedX := if node.style.overflowX == Overflow.Scroll
    then clamp(node.requestedScroll.x, 0.0, maxScrollX)
    else 0.0
  resolvedY := if node.style.overflowY == Overflow.Scroll
    then clamp(node.requestedScroll.y, 0.0, maxScrollY)
    else 0.0

  contentBounds := LayoutRect {
    x: contentRect.x + node.contentBoundsLocal.x - resolvedX,
    y: contentRect.y + node.contentBoundsLocal.y - resolvedY,
    width: node.contentBoundsLocal.width,
    height: node.contentBoundsLocal.height,
  }
  node.currentPlacement = LayoutPlacement {
    layoutBounds: node.localFrame,
    bounds,
    visibleBounds: visibleRect(bounds, effectiveClip),
    contentRect,
    contentBounds,
    clip: effectiveClip,
    scrollExtent: LayoutSize { width: extentWidth, height: extentHeight },
    requestedScrollOffset: node.requestedScroll,
    scrollOffset: LayoutPoint { x: resolvedX, y: resolvedY },
  }
  node.laidOut = true

  for child of node.children {
    childBounds := LayoutRect {
      x: bounds.x + child.localFrame.x - resolvedX,
      y: bounds.y + child.localFrame.y - resolvedY,
      width: child.localFrame.width,
      height: child.localFrame.height,
    }
    placeNode(child, childBounds, effectiveClip)
  }
}

function notifyPlaced(node: LayoutNode): none {
  if node.onPlace != none { node.onPlace!(node.currentPlacement) }
  for child of node.children { notifyPlaced(child) }
}

function validateTree(node: LayoutNode, visiting: LayoutNode[], seen: LayoutNode[]): none {
  if visiting.contains(node) { panic("layout tree must not contain cycles") }
  if seen.contains(node) { panic("a layout node must not have more than one parent") }
  visiting.push(node)
  seen.push(node)
  validateStyle(node.style)
  for child of node.children { validateTree(child, visiting, seen) }
  try! visiting.pop()
}

function validateStyle(style: LayoutStyle): none {
  requireOptionalNonNegative(style.width, "width")
  requireOptionalNonNegative(style.height, "height")
  requireOptionalPositive(style.aspectRatio, "aspect ratio")
  requireOptionalFinite(style.left, "left inset")
  requireOptionalFinite(style.right, "right inset")
  requireOptionalFinite(style.top, "top inset")
  requireOptionalFinite(style.bottom, "bottom inset")
  requireNonNegative(style.minWidth, "min width")
  requireNonNegative(style.minHeight, "min height")
  requireOptionalNonNegative(style.maxWidth, "max width")
  requireOptionalNonNegative(style.maxHeight, "max height")
  if style.position == LayoutPosition.Flex {
    requireOptionalNonNegative(style.flexBasis, "flex basis")
    requireNonNegative(style.grow, "grow")
    requireNonNegative(style.shrink, "shrink")
  }
  requireNonNegative(style.gap, "gap")
  validatePadding(style.padding)
  validateMargins(style.margin)
  if style.maxWidth != none && style.maxWidth! < style.minWidth {
    panic("layout max width must not be less than min width")
  }
  if style.maxHeight != none && style.maxHeight! < style.minHeight {
    panic("layout max height must not be less than min height")
  }
  if style.position == LayoutPosition.Absolute {
    if style.width != none && style.left != none && style.right != none {
      panic("absolute layout width cannot be combined with both left and right insets")
    }
    if style.height != none && style.top != none && style.bottom != none {
      panic("absolute layout height cannot be combined with both top and bottom insets")
    }
  }
}

function validateRootBounds(bounds: LayoutRect): none {
  requireFinite(bounds.x, "root x")
  requireFinite(bounds.y, "root y")
  requireNonNegative(bounds.width, "root width")
  requireNonNegative(bounds.height, "root height")
}

function validateConstraints(constraints: LayoutConstraints): none {
  requireNonNegative(constraints.minWidth, "minimum width constraint")
  requireNonNegative(constraints.minHeight, "minimum height constraint")
  requireOptionalNonNegative(constraints.maxWidth, "maximum width constraint")
  requireOptionalNonNegative(constraints.maxHeight, "maximum height constraint")
  if constraints.maxWidth != none && constraints.maxWidth! < constraints.minWidth {
    panic("layout maximum width constraint must not be less than its minimum")
  }
  if constraints.maxHeight != none && constraints.maxHeight! < constraints.minHeight {
    panic("layout maximum height constraint must not be less than its minimum")
  }
}

function validateMeasuredSize(size: LayoutSize): none {
  requireNonNegative(size.width, "measured width")
  requireNonNegative(size.height, "measured height")
}

function validatePadding(edges: LayoutEdges): none {
  requireNonNegative(edges.top, "padding top")
  requireNonNegative(edges.right, "padding right")
  requireNonNegative(edges.bottom, "padding bottom")
  requireNonNegative(edges.left, "padding left")
}

function validateMargins(edges: LayoutEdges): none {
  requireFinite(edges.top, "margin top")
  requireFinite(edges.right, "margin right")
  requireFinite(edges.bottom, "margin bottom")
  requireFinite(edges.left, "margin left")
}

function requireOptionalNonNegative(value: double | none, name: string): none {
  if value != none { requireNonNegative(value!, name) }
}

function requireOptionalFinite(value: double | none, name: string): none {
  if value != none { requireFinite(value!, name) }
}

function requireOptionalPositive(value: double | none, name: string): none {
  if value == none { return }
  requireFinite(value!, name)
  if value! <= 0.0 { panic(`layout ${name} must be greater than zero`) }
}

function requireNonNegative(value: double, name: string): none {
  requireFinite(value, name)
  if value < 0.0 { panic(`layout ${name} must not be negative`) }
}

function requireFinite(value: double, name: string): none {
  if !isfinite(value) { panic(`layout ${name} must be finite`) }
}

function mainBase(style: LayoutStyle, desired: LayoutSize, row: bool): double {
  if style.flexBasis != none { return style.flexBasis! }
  return if row then desired.width else desired.height
}

function clampMain(style: LayoutStyle, value: double, row: bool): double {
  return if row
    then clampDimension(value, style.minWidth, style.maxWidth)
    else clampDimension(value, style.minHeight, style.maxHeight)
}

function clampCross(style: LayoutStyle, value: double, row: bool): double {
  return if row
    then clampDimension(value, style.minHeight, style.maxHeight)
    else clampDimension(value, style.minWidth, style.maxWidth)
}

function clampDimension(value: double, minimum: double, maximum: double | none): double {
  let result = max(minimum, value)
  if maximum != none { result = min(result, maximum!) }
  return result
}

function subtractOptional(value: double | none, amount: double): double | none {
  if value == none { return none }
  return max(0.0, value! - amount)
}

function isRow(direction: FlexDirection): bool {
  return direction == FlexDirection.Row || direction == FlexDirection.RowReverse
}

function isReverse(direction: FlexDirection): bool {
  return direction == FlexDirection.RowReverse || direction == FlexDirection.ColumnReverse
}

function mainMargins(style: LayoutStyle, row: bool): double {
  return if row then style.margin.horizontal() else style.margin.vertical()
}

function crossMargins(style: LayoutStyle, row: bool): double {
  return if row then style.margin.vertical() else style.margin.horizontal()
}

function mainMarginBefore(style: LayoutStyle, row: bool, reverse: bool): double {
  if row { return if reverse then style.margin.right else style.margin.left }
  return if reverse then style.margin.bottom else style.margin.top
}

function mainMarginAfter(style: LayoutStyle, row: bool, reverse: bool): double {
  if row { return if reverse then style.margin.left else style.margin.right }
  return if reverse then style.margin.top else style.margin.bottom
}

function crossMarginBefore(style: LayoutStyle, row: bool): double {
  return if row then style.margin.top else style.margin.left
}

function crossMarginAfter(style: LayoutStyle, row: bool): double {
  return if row then style.margin.bottom else style.margin.right
}

function usedMain(node: LayoutNode, children: LayoutNode[], sizes: double[], row: bool): double {
  let used = 0.0
  for index of 0..<children.length {
    used += sizes[index] + mainMargins(children[index].style, row)
    if index > 0 { used += node.style.gap }
  }
  return used
}

function justifySpacing(justify: JustifyContent, leftover: double, count: int): JustifiedSpacing {
  if count == 0 { return JustifiedSpacing { leading: 0.0, between: 0.0 } }
  return case justify {
    .Start -> JustifiedSpacing { leading: 0.0, between: 0.0 },
    .Center -> JustifiedSpacing { leading: leftover * 0.5, between: 0.0 },
    .End -> JustifiedSpacing { leading: leftover, between: 0.0 },
    .SpaceBetween -> if count > 1
      then JustifiedSpacing { leading: 0.0, between: leftover / double(count - 1) }
      else JustifiedSpacing { leading: 0.0, between: 0.0 },
    .SpaceAround -> JustifiedSpacing {
      leading: leftover / double(count) * 0.5,
      between: leftover / double(count),
    },
    .SpaceEvenly -> JustifiedSpacing {
      leading: leftover / double(count + 1),
      between: leftover / double(count + 1),
    },
  }
}

function childAlignment(container: AlignItems, child: AlignSelf): AlignItems {
  return case child {
    .Auto -> container,
    .Stretch -> AlignItems.Stretch,
    .Start -> AlignItems.Start,
    .Center -> AlignItems.Center,
    .End -> AlignItems.End,
  }
}

function crossOffset(
  alignment: AlignItems,
  available: double,
  size: double,
  before: double,
  after: double,
): double {
  space := available - before - after
  return case alignment {
    .Stretch | .Start -> before,
    .Center -> before + (space - size) * 0.5,
    .End -> available - after - size,
  }
}

function intersectInterval(existing: LayoutInterval | none, added: LayoutInterval): LayoutInterval {
  if existing == none { return added }
  return LayoutInterval {
    min: max(existing!.min, added.min),
    max: min(existing!.max, added.max),
  }
}

function visibleRect(rect: LayoutRect, clip: LayoutClip): LayoutRect | none {
  let left = rect.x
  let right = rect.right()
  let top = rect.y
  let bottom = rect.bottom()
  if clip.x != none {
    left = max(left, clip.x!.min)
    right = min(right, clip.x!.max)
  }
  if clip.y != none {
    top = max(top, clip.y!.min)
    bottom = min(bottom, clip.y!.max)
  }
  if right <= left || bottom <= top { return none }
  return LayoutRect { x: left, y: top, width: right - left, height: bottom - top }
}

function unionRects(a: LayoutRect, b: LayoutRect): LayoutRect {
  left := min(a.x, b.x)
  top := min(a.y, b.y)
  right := max(a.right(), b.right())
  bottom := max(a.bottom(), b.bottom())
  return LayoutRect { x: left, y: top, width: right - left, height: bottom - top }
}
