import { Assert } from "std/assert"
import { parseJsonValue } from "std/json"

import { CodeEditor, CodeEditorHighlight, CodeEditorSelection } from "../code_editor"

export function testCodeEditorTextHighlightsAndUtf8Selection(): none {
  editor := CodeEditor{value: "let tool = \"工具🙂\"", lineNumbers: true, wrapLines: false, tabWidth: 2}
  Assert.equal(editor.text(), "let tool = \"工具🙂\"")
  editor.setHighlights([
    CodeEditorHighlight { start: 0, length: 3, style: .Keyword },
    CodeEditorHighlight { start: 11, length: 12, style: .String },
  ])
  editor.setSelection(CodeEditorSelection { start: 11, length: 12 })
  Assert.equal(editor.selection().start, 11)
  Assert.equal(editor.selection().length, 12)
  editor.setText("function main(): none {}")
  Assert.equal(editor.text(), "function main(): none {}")
  editor.asView().dispose()
  editor.asView().dispose()
}

export function testCodeEditorValidatesConfigurationAndRanges(): none {
  case catchPanic(=> CodeEditor{fontSize: 0.0}) {
    _: Success -> Assert.fail("expected invalid font size to panic")
    failure: Failure -> Assert.stringContains(failure.error, "fontSize")
  }
  editor := CodeEditor("abc")
  case catchPanic(=> editor.setSelection(CodeEditorSelection { start: 4, length: 0 })) {
    _: Success -> Assert.fail("expected invalid selection to panic")
    failure: Failure -> Assert.stringContains(failure.error, "selection range")
  }
  case catchPanic(=> editor.setHighlights([CodeEditorHighlight { start: 1, length: 9, style: .Comment }])) {
    _: Success -> Assert.fail("expected invalid highlight to panic")
    failure: Failure -> Assert.stringContains(failure.error, "highlight range")
  }
  editor.asView().dispose()
}

export function testCodeEditorNativeConfigurationSnapshot(): none {
  editor := CodeEditor{value: "hello", lineNumbers: false, wrapLines: true, fontSize: 15.0, tabWidth: 8}
  snapshot := try! parseJsonValue(editor.asView().nativeView().codeEditorSnapshot()) as JsonObject
  Assert.equal(snapshot.get("text")!, "hello")
  Assert.equal(snapshot.get("lineNumbers")!, false)
  Assert.equal(snapshot.get("wrapLines")!, true)
  Assert.approxEqual(try! snapshot.get("fontSize")! as double, 15.0)
  Assert.approxEqual(try! snapshot.get("tabWidth")! as double, 8.0)
  Assert.equal(snapshot.get("autoIndent")!, true)
  editor.asView().dispose()
}

export function testCodeEditorAutoIndentsNewlines(): none {
  editor := CodeEditor{value: "  if ready {", tabWidth: 2}
  editor.setSelection(CodeEditorSelection { start: editor.text().length, length: 0 })
  editor.asView().nativeView().performCodeEditorNewline()
  Assert.equal(editor.text(), "  if ready {\n    ")
  Assert.equal(editor.selection().start, editor.text().length)

  editor.setText("  println(\"hello\")")
  editor.setSelection(CodeEditorSelection { start: editor.text().length, length: 0 })
  editor.asView().nativeView().performCodeEditorNewline()
  Assert.equal(editor.text(), "  println(\"hello\")\n  ")
  editor.asView().dispose()
}

export function testCodeEditorCanDisableAutoIndent(): none {
  editor := CodeEditor{value: "  block {", tabWidth: 2, autoIndent: false}
  editor.setSelection(CodeEditorSelection { start: editor.text().length, length: 0 })
  editor.asView().nativeView().performCodeEditorNewline()
  Assert.equal(editor.text(), "  block {\n")
  editor.asView().dispose()
}

export function testCodeEditorResolvesHoverTextAtUtf8Offsets(): none {
  editor := CodeEditor{
    value: "let tool = \"工具🙂\"",
    hoverText: (offset): string => if offset == 11 then "String diagnostic" else "",
  }
  native := editor.asView().nativeView()
  Assert.equal(native.codeEditorHoverText(11), "String diagnostic")
  Assert.equal(native.codeEditorHoverText(12), "")
  Assert.equal(native.codeEditorHoverText(100), "")
  editor.asView().dispose()
  Assert.equal(native.codeEditorHoverText(11), "")
}
