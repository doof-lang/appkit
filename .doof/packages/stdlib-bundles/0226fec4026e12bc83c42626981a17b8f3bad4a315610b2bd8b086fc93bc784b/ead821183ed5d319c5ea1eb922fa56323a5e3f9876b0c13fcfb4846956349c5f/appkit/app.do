import { clearMainEventWakeHandler, drainMainEventLoop, setMainEventWakeHandler } from "std/event"
import { LayoutRect, layout } from "std/layout"

import { Alert, prepareAlert } from "./alert"
import { Menu, defaultAppMenus, installAppMenus } from "./menu"
import { NativeApplication, NativeWindow } from "./native"
import { registerLayoutInvalidator, syncUI } from "./runtime"
import { Sheet, prepareSheet } from "./sheet"
import { Toolbar } from "./toolbar"
import { FileDialogOptions } from "./types"
import { View, ViewElement, windowContent } from "./view"

class ApplicationHolder {
  let value: NativeApplication | none = none
  let hasRun = false
  let hasOpenFilesHandler = false
  let hasConfiguredMenus = false
  let hasInstalledDefaultMenus = false
}
readonly applicationHolder = ApplicationHolder {}

function application(): NativeApplication {
  if applicationHolder.value == none { applicationHolder.value = NativeApplication.shared() }
  return applicationHolder.value!
}

function ensureDefaultAppMenus(): none {
  if applicationHolder.hasConfiguredMenus || applicationHolder.hasInstalledDefaultMenus { return }
  installAppMenus(application(), defaultAppMenus())
  applicationHolder.hasInstalledDefaultMenus = true
}

export class Window {
  readonly title: string
  readonly width: int
  readonly height: int
  readonly resizable: bool
  content: View
  private native: NativeWindow
  private let lastWidth = 0.0
  private let lastHeight = 0.0
  private let presentingModal = false

  static constructor(
    title: string = "Doof App",
    width: int = 800,
    height: int = 600,
    resizable: bool = true,
    children: ViewElement[] = [],
    toolbar: Toolbar | none = none,
  ): Window {
    if width <= 0 || height <= 0 { panic("window dimensions must be positive") }
    content := windowContent(children)
    native := NativeWindow.create(title, width, height, resizable)
    window := Window { title, width, height, resizable, content, native }
    native.setRoot(content.nativeView())
    if toolbar != none { toolbar!.install(native) }
    native.setLayoutHandler((nextWidth: double, nextHeight: double): none => window.relayout(nextWidth, nextHeight))
    registerLayoutInvalidator((): none => {
      if native.isShown() && window.lastWidth > 0.0 && window.lastHeight > 0.0 {
        window.relayout(window.lastWidth, window.lastHeight)
      }
    })
    return window
  }

  show(): none { ensureDefaultAppMenus(); native.show() }
  close(): none { native.close() }
  isShown(): bool => native.isShown()

  showAlert(alert: Alert): none {
    if !native.isShown() { panic("showAlert requires a shown Window") }
    if presentingModal { panic("a Window can present only one modal at a time") }
    prepared := prepareAlert(alert)
    presentingModal = true
    native.presentAlert(
      alert.title,
      alert.message,
      alert.style.value,
      prepared.titles,
      prepared.destructive,
      prepared.primaryIndex,
      prepared.cancelIndex,
      (index: int): none => {
        presentingModal = false
        prepared.perform(index)
      },
    )
  }

  showSheet(sheet: Sheet): none {
    if !native.isShown() { panic("showSheet requires a shown Window") }
    if presentingModal { panic("a Window can present only one modal at a time") }
    prepared := prepareSheet(sheet)
    presentingModal = true
    native.presentSheet(
      sheet.title,
      sheet.width,
      sheet.height,
      sheet.contentView().nativeView(),
      prepared.titles,
      prepared.destructive,
      prepared.primaryIndex,
      prepared.cancelIndex,
      (width: double, height: double): none => sheet.relayout(width, height),
      (index: int): bool => prepared.validate(index),
      (index: int): none => {
        presentingModal = false
        prepared.perform(index)
      },
    )
  }

  private relayout(width: double, height: double): none {
    lastWidth = width
    lastHeight = height
    content.prepareLayout()
    layout(content.layoutNode(), LayoutRect { width, height })
  }
}

export function runApp(): none {
  app := application()
  if !app.isMainThread() { panic("runApp must be called on the main thread") }
  if applicationHolder.hasRun || app.isRunning() { panic("runApp may only be called once") }
  if app.shownWindowCount() == 0 { panic("runApp requires at least one shown Window") }
  ensureDefaultAppMenus()
  applicationHolder.hasRun = true
  setMainEventWakeHandler((): none => app.requestWake())
  app.run((): int => {
    count := drainMainEventLoop()
    syncUI()
    return count
  })
  clearMainEventWakeHandler()
}

export function quitApp(): none { application().quit() }

export function setOpenFilesHandler(handler: (paths: string[]): none): none {
  if applicationHolder.hasOpenFilesHandler { panic("setOpenFilesHandler may only be called once") }
  if applicationHolder.hasRun || application().isRunning() { panic("setOpenFilesHandler must be called before runApp") }
  applicationHolder.hasOpenFilesHandler = true
  application().setOpenFilesHandler((paths: string[]): none => {
    handler(paths)
    syncUI()
  })
}

export function setAppMenus(menus: Menu[]): none {
  if applicationHolder.hasConfiguredMenus { panic("setAppMenus may only be called once") }
  if applicationHolder.hasRun || application().isRunning() { panic("setAppMenus must be called before runApp") }
  installAppMenus(application(), menus)
  applicationHolder.hasConfiguredMenus = true
}

export function showAlert(alert: Alert): none {
  prepared := prepareAlert(alert)
  index := application().alert(
    alert.title,
    alert.message,
    alert.style.value,
    prepared.titles,
    prepared.destructive,
    prepared.primaryIndex,
    prepared.cancelIndex,
  )
  prepared.perform(index)
}

export function openFile(options: FileDialogOptions = FileDialogOptions {}): string[] {
  return application().openFile(options.title, options.directories, options.multiple)
}

export function saveFile(options: FileDialogOptions = FileDialogOptions {}): string | none {
  return application().saveFile(options.title, options.suggestedName)
}
