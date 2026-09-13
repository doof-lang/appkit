import { NativeView } from "./native"
import { bindString, initialString, syncUI } from "./runtime"
import { SourceStyle } from "./source_view"
import { View, ViewElement, growingControl } from "./view"

/** A UTF-8 byte range in the editor document. */
export class CodeEditorSelection {
  start: int
  length: int
}

/** A styled UTF-8 byte range in the editor document. */
export class CodeEditorHighlight {
  start: int
  length: int
  style: SourceStyle
}

/** Native NSTextView-based source editor with selection and attributed spans. */
export class CodeEditor implements ViewElement {
  private native: NativeView
  private content: View

  static constructor(
    value: string | ((): string) = "",
    onChange: (value: string): none = (value): none => {},
    onSelectionChange: (selection: CodeEditorSelection): none = (selection): none => {},
    hoverText: (offset: int): string = (offset): string => "",
    completions: (offset: int): string = (offset): string => "",
    lineNumbers: bool = true,
    wrapLines: bool = false,
    fontSize: double = 13.0,
    tabWidth: int = 4,
    autoIndent: bool = true,
    minHeight: double = 120.0,
    enabled: bool | ((): bool) = true,
    hidden: bool | ((): bool) = false,
    accessibilityLabel: string = "Source editor",
    accessibilityHelp: string = "",
    accessibilityIdentifier: string = "",
  ): CodeEditor {
    if fontSize <= 0.0 { panic("CodeEditor fontSize must be positive") }
    if tabWidth <= 0 { panic("CodeEditor tabWidth must be positive") }
    if minHeight <= 0.0 { panic("CodeEditor minHeight must be positive") }
    native := NativeView.codeEditor(
      initialString(value), lineNumbers, wrapLines, fontSize, tabWidth, autoIndent,
      (next): none => { onChange(next); syncUI() },
      (start, length): none => {
        onSelectionChange(CodeEditorSelection { start, length })
        syncUI()
      },
      hoverText,
      completions,
    )
    content := growingControl(native, minHeight)
      .enabled(enabled)
      .hidden(hidden)
      .accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
    bindString(value, (next): none => native.setCodeEditorText(next))
    return CodeEditor { native, content }
  }

  asView(): View => content
  text(): string => native.codeEditorText()
  setText(value: string): none { native.setCodeEditorText(value) }
  complete(): none { native.completeCodeEditor() }

  selection(): CodeEditorSelection => CodeEditorSelection {
    start: native.codeEditorSelectionStart(),
    length: native.codeEditorSelectionLength(),
  }

  setSelection(selection: CodeEditorSelection, reveal: bool = true): none {
    validateRange(selection.start, selection.length, "selection")
    native.setCodeEditorSelection(selection.start, selection.length, reveal)
  }

  setHighlights(highlights: CodeEditorHighlight[]): none {
    let starts: int[] = []
    let lengths: int[] = []
    let styles: int[] = []
    for highlight of highlights {
      validateRange(highlight.start, highlight.length, "highlight")
      starts.push(highlight.start)
      lengths.push(highlight.length)
      styles.push(highlight.style.value)
    }
    native.setCodeEditorHighlights(starts, lengths, styles)
  }

  private validateRange(start: int, length: int, kind: string): none {
    sourceLength := text().length
    if start < 0 || length < 0 || start > sourceLength || length > sourceLength - start {
      panic("CodeEditor ${kind} range is out of bounds")
    }
  }
}
