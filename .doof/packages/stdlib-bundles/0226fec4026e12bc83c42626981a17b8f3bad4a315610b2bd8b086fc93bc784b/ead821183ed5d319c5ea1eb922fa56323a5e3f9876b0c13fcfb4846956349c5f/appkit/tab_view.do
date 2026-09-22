import { LayoutConstraints, LayoutRect, LayoutSize, layout, measureLayout } from "std/layout"
import { NativeView } from "./native"
import { bindInt, bindString, initialString, syncUI } from "./runtime"
import { Column, View, ViewElement, measuredControl } from "./view"

// A tab retains its content for the lifetime of its owning TabView.
export class TabItem {
  title: string | ((): string)
  content: View
}

export function Tab(
  title: string | ((): string),
  children: ViewElement[] = [],
  gap: double = 8.0,
): TabItem {
  return TabItem { title, content: Column{children, gap} }
}

export function TabView(
  children: TabItem[],
  selectedIndex: int | ((): int) = 0,
  onChange: (selectedIndex: int): none = (selectedIndex: int): none => {},
  grow: double = 1.0,
  hidden: bool | ((): bool) = false,
  accessibilityLabel: string = "",
  accessibilityHelp: string = "",
  accessibilityIdentifier: string = "",
): View {
  if children.length == 0 { panic("TabView requires at least one Tab") }
  if grow < 0.0 { panic("TabView grow cannot be negative") }
  // Copy the collection: tabs are fixed after construction.
  tabs: TabItem[] := []
  for child of children {
    for existing of tabs {
      if existing.content == child.content { panic("TabView cannot reuse a Tab content view") }
    }
    tabs.push(child)
  }
  native := NativeView.tabView()
  for tab of tabs { native.addTab(initialString(tab.title), tab.content.nativeView()) }
  for index of 0..<tabs.length {
    bindString(tabs[index].title, (title): none => native.setTabTitle(index, title))
  }
  bindInt(selectedIndex, (index): none => {
    if index < 0 || index >= tabs.length { panic("TabView selectedIndex is out of range") }
    native.selectTab(index)
  })
  native.setTabAction((index): none => { onChange(index); syncUI() })
  native.setTabLayoutHandler((index, width, height): none => {
    content := tabs[index].content
    content.prepareLayout()
    layout(content.layoutNode(), LayoutRect { width, height })
  })
  pages: View[] := []
  for tab of tabs { pages.push(tab.content) }
  view := measuredControl(native, pages)
  view.layoutNode().style.grow = grow
  view.layoutNode().style.shrink = 1.0
  // Measure every page so switching tabs does not change the preferred size.
  view.layoutNode().measure = (constraints): LayoutSize => {
    metrics := native.tabMetrics()
    let width = metrics[2]
    let height = metrics[3]
    let contentMaxWidth: double | none = none
    let contentMaxHeight: double | none = none
    if constraints.maxWidth != none {
      contentMaxWidth = if constraints.maxWidth! > metrics[0] then constraints.maxWidth! - metrics[0] else 0.0
    }
    if constraints.maxHeight != none {
      contentMaxHeight = if constraints.maxHeight! > metrics[1] then constraints.maxHeight! - metrics[1] else 0.0
    }
    for tab of tabs {
      tab.content.prepareLayout()
      size := measureLayout(tab.content.layoutNode(), LayoutConstraints {
        maxWidth: contentMaxWidth, maxHeight: contentMaxHeight,
      })
      if size.width + metrics[0] > width { width = size.width + metrics[0] }
      if size.height + metrics[1] > height { height = size.height + metrics[1] }
    }
    return LayoutSize { width, height }
  }
  return view.hidden(hidden)
    .accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
}
