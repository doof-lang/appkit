import { Assert } from "std/assert"
import { NativeApplication, NativeWindow } from "../native"

export function testNativeWindowRemainsOwnedAfterClose(): none {
  app := NativeApplication.shared()
  initialCount := app.shownWindowCount()
  window := NativeWindow.create("ARC lifetime", 240, 160, true)
  // Closing must not release the window out from under its native owner.
  for index of 0..<3 {
    window.show()
    Assert.isTrue(window.isShown())
    Assert.equal(app.shownWindowCount(), initialCount + 1)
    window.close()
    Assert.isFalse(window.isShown())
    Assert.equal(app.shownWindowCount(), initialCount)
  }
}
