import { NativeView } from "./native"
import { syncUI } from "./runtime"
import { View, ViewElement, growingControl } from "./view"

export enum ImageCanvasBackground { Checker, White, Black }

export class ImageCanvas {
  private native: NativeView
  private view: View

  static constructor(
    onClick: (x: double, y: double): none = (x: double, y: double): none => {},
    onDrop: (paths: string[]): none = (paths: string[]): none => {},
  ): ImageCanvas {
    native := NativeView.imageCanvas()
    native.setCanvasClickAction((x: double, y: double): none => {
      onClick(x, y)
      syncUI()
    })
    native.setCanvasDropAction((paths: string[]): none => {
      onDrop(paths)
      syncUI()
    })
    return ImageCanvas { native, view: growingControl(native, 240.0) }
  }

  setImage(encodedImage: readonly byte[]): none { native.setCanvasImage(encodedImage) }
  setBackground(background: ImageCanvasBackground): none { native.setCanvasBackground(background.value) }
  zoomIn(): none { native.zoomCanvas(1.25) }
  zoomOut(): none { native.zoomCanvas(0.8) }
  actualSize(): none { native.actualSizeCanvas() }
  fit(): none { native.fitCanvas() }
  asView(): View => view
}
