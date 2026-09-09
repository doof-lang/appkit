import { NativeView } from "./native"
import { syncUI } from "./runtime"
import { View, ViewElement, growingControl } from "./view"

export enum SourceStyle { Plain, Keyword, String, Number, Comment, Type, Function }

/** UTF-8 byte range within a one-based source line. */
export class SourceHighlight {
  line: int
  start: int
  length: int
  style: SourceStyle
}

/** Read-only monospaced source with one-based line numbers and a clickable gutter. */
export class SourceView implements ViewElement {
  private native: NativeView
  private content: View
  private let sourceLines: string[] = []

  static constructor(onToggleBreakpoint: (line: int): none = (line): none => {}): SourceView {
    native := NativeView.sourceView((line): none => { onToggleBreakpoint(line); syncUI() })
    return SourceView { native, content: growingControl(native).accessibility("Source code") }
  }
  setHighlights(highlights: SourceHighlight[]): none {
    let rows: int[] = []; let starts: int[] = []; let lengths: int[] = []; let styles: int[] = []
    for span of highlights {
      if span.line < 1 || span.line > sourceLines.length { panic("Source highlight line is out of range") }
      if span.start < 0 || span.length < 0 || span.start > sourceLines[span.line-1].length ||
        span.length > sourceLines[span.line-1].length - span.start { panic("Source highlight range is out of bounds") }
      rows.push(span.line-1); starts.push(span.start); lengths.push(span.length); styles.push(span.style.value)
    }
    native.setSourceHighlights(rows, starts, lengths, styles)
  }
  asView(): View => content
  lineCount(): int => native.sourceLineCount()
  /** Markers: 0 absent, 1 pending/unverified, 2 verified. Current line 0 means none. */
  setLines(lines: string[], markers: int[] = [], currentLine: int = 0, reveal: bool = false): none {
    if currentLine < 0 || currentLine > lines.length { panic("SourceView current line is out of range") }
    if markers.length != 0 && markers.length != lines.length { panic("SourceView markers must match line count") }
    for marker of markers { if marker < 0 || marker > 2 { panic("SourceView marker must be 0, 1, or 2") } }
    sourceLines = lines
    native.setSourceLines(lines, markers, currentLine, reveal)
  }
}
