import { Assert } from "std/assert"
import { SourceView, SourceHighlight } from "../source_view"

export function testSourceViewUpdatesAndDisposes(): none {
  source := SourceView()
  Assert.equal(source.lineCount(), 0)
  source.setLines(["function main(): none {", "  println(\"工具\")", "}"], [0, 2, 0], 2, true)
  Assert.equal(source.lineCount(), 3)
  source.setLines([], [], 0)
  Assert.equal(source.lineCount(), 0)
  source.asView().dispose()
  source.asView().dispose()
}

export function testSourceViewAcceptsUtf8HighlightsAndRejectsInvalidRanges(): none {
  source := SourceView()
  source.setLines(["let name = \"工具🙂\"; let count = 41"])
  source.setHighlights([
    SourceHighlight { line: 1, start: 0, length: 3, style: .Keyword },
    SourceHighlight { line: 1, start: 11, length: 12, style: .String },
    SourceHighlight { line: 1, start: 25, length: 3, style: .Keyword },
  ])
  case catchPanic(=> source.setHighlights([SourceHighlight { line: 1, start: 999, length: 1, style: .Number }])) {
    _: Success -> Assert.fail("expected an invalid source range to panic")
    failure: Failure -> Assert.stringContains(failure.error, "range")
  }
  source.setLines([])
  source.setHighlights([])
  source.asView().dispose()
}
