import {
  AlignItems,
  FlexDirection,
  LayoutConstraints,
  LayoutEdges,
  LayoutNode,
  LayoutRect,
  LayoutSize,
  LayoutStyle,
  layout,
  measureLayout,
} from "std/layout"

import { NativeView } from "./native"
import { bindBool, syncUI } from "./runtime"
import { Axis } from "./types"

readonly KIND_CONTAINER = 0
readonly KIND_LEAF = 1
readonly KIND_SCROLL = 2
readonly KIND_SPLIT = 3
readonly GAP = 8.0
readonly INSET = 16.0

export interface ViewElement {
  asView(): View
}

// Native and layout callbacks observe their owner without retaining it.
class ViewReference { view: weak View }

export class View {
  native: NativeView
  node: LayoutNode
  private readonly kind: int
  private let children: View[] = []
  // Content hosted by a native control (for example tab pages) has separate
  // layout, but shares this view's disposal lifetime.
  private let ownedContent: View[] = []
  private let paneRoots: LayoutNode[] = []
  private let attached = true
  private let hiddenState = false
  private let disposed = false

  append(child: View): View {
    if kind == KIND_LEAF { panic("leaf controls cannot contain children") }
    if kind == KIND_SCROLL && children.length > 0 { panic("ScrollView accepts exactly one child") }
    child.attached = true
    children.push(child)
    native.append(child.native)
    syncUI()
    return this
  }

  insertBefore(child: View, reference: View): View {
    if kind == KIND_LEAF || kind == KIND_SCROLL { panic("this view does not support insertBefore") }
    let next: View[] = []
    let inserted = false
    for current of children {
      if current == reference { next.push(child); inserted = true }
      next.push(current)
    }
    if !inserted { next.push(child) }
    children = next
    child.attached = true
    native.insertBefore(child.native, reference.native)
    syncUI()
    return this
  }

  replace(child: View, target: View): View {
    let next: View[] = []
    let replaced = false
    for current of children {
      if current == target { next.push(child); replaced = true } else { next.push(current) }
    }
    if !replaced { panic("replacement target is not a child of this view") }
    children = next
    target.attached = false
    child.attached = true
    native.replace(child.native, target.native)
    syncUI()
    return this
  }

  detach(): View { attached = false; native.detach(); syncUI(); return this }
  dispose(): none { disposeTree(); syncUI() }

  private disposeTree(): none {
    if disposed { return }
    disposed = true
    attached = false
    node.onPlace = none
    node.measure = none
    for child of children { child.disposeTree() }
    for child of ownedContent { child.disposeTree() }
    children = []
    ownedContent = []
    paneRoots = []
    while node.children.length > 0 { try! node.children.pop() }
    native.dispose()
  }

  hidden(value: bool | ((): bool)): View {
    bindBool(value, (next): none => { hiddenState = next; native.setHidden(next) })
    return this
  }

  enabled(value: bool | ((): bool)): View {
    bindBool(value, (next): none => native.setEnabled(next))
    return this
  }

  accessibility(label: string = "", help: string = "", identifier: string = ""): View {
    native.setAccessibility(label, help, identifier)
    return this
  }

  nativeView(): NativeView => native
  layoutNode(): LayoutNode => node
  isIncluded(): bool => attached && !hiddenState
  asView(): View => this

  prepareLayout(): none {
    if disposed { return }
    while node.children.length > 0 { try! node.children.pop() }
    if kind == KIND_SPLIT { configureSplit(); return }
    if kind == KIND_SCROLL { return }
    for child of children {
      child.prepareLayout()
      if child.isIncluded() { node.children.push(child.node) }
    }
  }

  private place(x: double, y: double, width: double, height: double): none {
    native.setFrame(x, y, width, height)
    if kind == KIND_SCROLL && children.length == 1 {
      child := children[0]
      child.prepareLayout()
      measured := measureLayout(child.node, LayoutConstraints { minWidth: width, maxWidth: width })
      documentHeight := if measured.height > height then measured.height else height
      native.setDocumentSize(width, documentHeight)
      layout(child.node, LayoutRect { width, height: documentHeight })
    }
  }

  configureSplit(): none {
    if disposed { return }
    paneRoots = []
    for child of children {
      child.prepareLayout()
      paneRoots.push(LayoutNode {
        style: LayoutStyle { direction: .Column, padding: LayoutEdges.all(INSET) },
        children: [child.node],
      })
    }
    owner := ViewReference { view: this }
    native.setPaneLayoutHandler((index: int, width: double, height: double): none => {
      _ := owner.view?.placePane(index, width, height) else { }
    })
  }

  private placePane(index: int, width: double, height: double): none {
    if disposed { return }
    if index >= 0 && index < paneRoots.length {
      // NSSplitView owns the wrapper frame; Doof lays out its padded content.
      layout(paneRoots[index], LayoutRect { width, height })
    }
  }
}

function createView(native: NativeView, style: LayoutStyle, kind: int, measured: bool = false, ownedContent: View[] = []): View {
  node := LayoutNode { style }
  if measured {
    node.measure = (constraints): LayoutSize => LayoutSize {
      width: native.measureWidth(constraints.maxWidth, constraints.maxHeight),
      height: native.measureHeight(constraints.maxWidth, constraints.maxHeight),
    }
  }
  view := View { native, node, kind, ownedContent }
  owner := ViewReference { view }
  node.onPlace = (placement): none => {
    _ := owner.view?.place(
      placement.layoutBounds.x,
      placement.layoutBounds.y,
      placement.layoutBounds.width,
      placement.layoutBounds.height,
    ) else { }
  }
  return view
}

export function layoutContainer(native: NativeView, style: LayoutStyle): View {
  return createView(native, style, KIND_CONTAINER)
}

export function measuredControl(native: NativeView, ownedContent: View[] = []): View {
  return createView(native, LayoutStyle { shrink: 0.0 }, KIND_LEAF, true, ownedContent)
}

export function growingControl(native: NativeView, minHeight: double = 80.0): View {
  return createView(native, LayoutStyle { grow: 1.0, minHeight }, KIND_LEAF)
}

function container(
  children: ViewElement[],
  direction: FlexDirection,
  padding: double = 0.0,
  gap: double = GAP,
  grow: double = 0.0,
): View {
  if gap < 0.0 { panic("container gap cannot be negative") }
  if grow < 0.0 { panic("container grow cannot be negative") }
  style := LayoutStyle {
    direction,
    gap,
    grow,
    padding: LayoutEdges.all(padding),
    alignItems: if direction == .Row then AlignItems.Center else AlignItems.Stretch,
  }
  if grow > 0.0 { style.flexBasis = 0.0 }
  view := createView(NativeView.container(), style, KIND_CONTAINER)
  for child of children { view.append(child.asView()) }
  return view
}

export function Row(
  children: ViewElement[] = [],
  hidden: bool | ((): bool) = false,
  gap: double = GAP,
  grow: double = 0.0,
): View {
  return container(children, .Row, 0.0, gap, grow).hidden(hidden)
}

export function Column(
  children: ViewElement[] = [],
  hidden: bool | ((): bool) = false,
  gap: double = GAP,
  grow: double = 0.0,
): View {
  return container(children, .Column, 0.0, gap, grow).hidden(hidden)
}

export function SplitView(
  children: ViewElement[] = [],
  axis: Axis = Axis.Horizontal,
  hidden: bool | ((): bool) = false,
  weights: double[] = [],
): View {
  if weights.length != 0 && weights.length != children.length { panic("SplitView weights must match children") }
  for weight of weights { if !(weight > 0.0) { panic("SplitView weights must be positive") } }
  view := createView(NativeView.split(axis.value), LayoutStyle { grow: 1.0, minHeight: 80.0 }, KIND_SPLIT)
  for child of children { view.append(child.asView()) }
  view.native.setPaneWeights(weights)
  view.configureSplit()
  return view.hidden(hidden)
}

export function ScrollView(children: ViewElement[] = [], hidden: bool | ((): bool) = false): View {
  if children.length != 1 { panic("ScrollView requires exactly one child") }
  view := createView(NativeView.scroll(), LayoutStyle { grow: 1.0, minHeight: 80.0 }, KIND_SCROLL)
  view.append(children[0].asView())
  return view.hidden(hidden)
}

export function windowContent(children: ViewElement[]): View => container(children, .Column, INSET)
