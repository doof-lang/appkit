# Files and event-loop work

[Cookbook index](README.md)

## Choose input and output paths

File panels return paths. Handle cancellation without clearing the current
document, then perform your own reading or writing. This program displays the
chosen paths so it can run without application-specific file handling.

```doof
import {
  Button, FileDialogOptions, Text, Window, openFile, runApp, saveFile,
  setOpenFilesHandler,
} from "std/appkit"

function main(): none {
  let status = "Choose files or a destination."
  acceptPaths := (paths: string[]): none => {
    if paths.length == 0 { return }
    status = "Received ${paths.length} path(s). First: ${paths[0]}"
  }
  setOpenFilesHandler(acceptPaths)

  window := <Window title="File panels" width=680 height=260>
    <Button title="Open files…" onClick=>{
      acceptPaths(openFile(FileDialogOptions {
        title: "Choose input files",
        multiple: true,
      }))
    }/>
    <Button title="Choose folder…" onClick=>{
      acceptPaths(openFile(FileDialogOptions {
        title: "Choose a folder",
        directories: true,
      }))
    }/>
    <Button title="Choose export path…" onClick=>{
      path := saveFile(FileDialogOptions {
        title: "Export report",
        suggestedName: "report.txt",
      }) as string else { return }
      status = "Export destination: ${path}"
    }/>
    <Text value=>status/>
  </Window>
  window.show()
  runApp()
}
```

Choose multiple files, then cancel another panel: the previous status remains.
Try folder selection and an export destination. No file is written by this
example. `openFile` ignores `suggestedName`; `saveFile` ignores `directories`
and `multiple`.

Register `setOpenFilesHandler` once before `runApp` to share the same path
handling with Finder/Dock requests. Delivery through Finder also depends on
your application's bundle/file associations; this recipe does not register
document types. Launch-time requests are retained until the handler is set.
Treat received paths as input: actual file access and decoding can still fail.

For an image tool, the same path handler can be the second `ImageCanvas`
constructor callback. Read and decode the selected file with your image/IO
code, then pass encoded image bytes to `canvas.setImage(...)`. Call `fit()`
after the canvas has a laid-out viewport, or provide a Fit button. Background
choices affect the preview only. See [Image canvases](../../README.md#image-canvases).

## Update UI from a timer

`runApp` drains ready `std/event` work and synchronizes bindings. A timer can
update ordinary model state; no manual UI refresh or extra event loop is
required. This is a small demonstration of that integration, not a background
worker: the callback runs on the event-loop thread.

```doof
import { Button, Text, Window, runApp } from "std/appkit"
import { setInterval } from "std/event"
import { Duration } from "std/time"

function main(): none {
  let ticks = 0
  let paused = false
  timer := setInterval(Duration.ofSeconds(1L), (): none => {
    if !paused { ticks += 1 }
  })
  window := <Window title="Timer" width=360 height=200>
    <Text value=>"Timer ticks: ${ticks}"/>
    <Button title=>if paused then "Resume" else "Pause"
      onClick=>{ paused = !paused }/>
    <Button title="Reset" onClick=>{ ticks = 0 }/>
  </Window>
  window.show()
  runApp()
  timer.cancel()
}
```

Watch the count advance, pause it, reset it, and close the window. Cancel the
timer after `runApp` returns to release repeating work. Timer ticks are not a
precise elapsed-time measurement; callbacks may be delayed by other work.
Long-running actions block input and repainting, so use a worker plus a
[`std/event` channel](../../../event/README.md) for expensive operations.
