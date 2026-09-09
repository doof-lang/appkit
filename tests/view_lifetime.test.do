import { Assert } from "std/assert"
import { LayoutSize } from "std/layout"
import { Column, SplitView, Tab, TabView, View } from "../index"
import { NativeView } from "../native"

class Lifetime { let released = 0 }
class Tracked {
  lifetime: Lifetime
  destructor { lifetime.released += 1 }
}

function track(view: View, lifetime: Lifetime): none {
  tracked := Tracked { lifetime }
  view.node.measure = (constraints): LayoutSize => {
    Assert.equal(tracked.lifetime.released, 0)
    return LayoutSize { width: 1.0, height: 1.0 }
  }
}

function releaseView(lifetime: Lifetime, dispose: bool, split: bool): none {
  view := if split then SplitView() else Column()
  track(view, lifetime)
  if dispose { view.dispose(); view.dispose() }
}

export function testViewLifetimeReleasesLayoutCaptures(): none {
  for dispose of [false, true] {
    for split of [false, true] {
      lifetime := Lifetime {}
      releaseView(lifetime, dispose, split)
      Assert.equal(lifetime.released, 1)
    }
  }
}

function releaseNested(lifetime: Lifetime): none {
  child := Column()
  track(child, lifetime)
  root := Column([TabView([Tab("Page", [SplitView([child])])])])
  root.dispose()
  Assert.equal(lifetime.released, 1)
  root.dispose()
  root.prepareLayout()
}

export function testViewLifetimeDisposesNestedTabAndSplitContent(): none {
  lifetime := Lifetime {}
  releaseNested(lifetime)
  Assert.equal(lifetime.released, 1)
}

function installPaneCallback(native: NativeView, lifetime: Lifetime): none {
  tracked := Tracked { lifetime }
  native.setPaneLayoutHandler((index, width, height): none => {
    Assert.equal(tracked.lifetime.released, 0)
  })
}

export function testViewLifetimeNativeSplitClearsCallbackOnDispose(): none {
  native := NativeView.split(0)
  lifetime := Lifetime {}
  installPaneCallback(native, lifetime)
  Assert.equal(lifetime.released, 0)
  native.dispose()
  Assert.equal(lifetime.released, 1)
  native.dispose()
  installPaneCallback(native, lifetime)
  Assert.equal(lifetime.released, 2)
}

export function testViewLifetimeDisposedSplitCannotReinstallLayout(): none {
  split := SplitView()
  lifetime := Lifetime {}
  track(split, lifetime)
  split.dispose()
  Assert.equal(lifetime.released, 1)
  split.prepareLayout()
  split.configureSplit()
  Assert.equal(split.node.onPlace, none)
  Assert.equal(split.node.measure, none)
}
