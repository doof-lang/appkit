export import class NativeView from "native_appkit.hpp" as doof_appkit::NativeView {
  static codeEditor(
    value: string,
    lineNumbers: bool,
    wrapLines: bool,
    fontSize: double,
    tabWidth: int,
    autoIndent: bool,
    change: (value: string): none,
    selectionChange: (start: int, length: int): none,
    hoverText: (offset: int): string,
    completions: (offset: int): string,
  ): NativeView
  setCodeEditorText(value: string): none
  codeEditorText(): string
  setCodeEditorHighlights(starts: int[], lengths: int[], styles: int[]): none
  codeEditorSelectionStart(): int
  codeEditorSelectionLength(): int
  setCodeEditorSelection(start: int, length: int, reveal: bool): none
  codeEditorHoverText(offset: int): string
  completeCodeEditor(): none
  performCodeEditorCompletion(index: int): none
  performCodeEditorCompletionMovement(index: int, movement: int): none
  undoCodeEditor(): none
  redoCodeEditor(): none
  performCodeEditorNewline(): none
  performCodeEditorText(text: string): none
  codeEditorSnapshot(): string
  static sourceView(toggle: (line: int): none): NativeView
  setSourceLines(lines: string[], markers: int[], currentLine: int, reveal: bool): none
  setSourceHighlights(rows: int[], starts: int[], lengths: int[], styles: int[]): none
  sourceLineCount(): int
  static container(): NativeView
  static outlineView(): NativeView
  setOutlineData(label: (index: int): string, selection: (index: int): none): none
  reloadOutline(keys: string[], parents: int[]): none
  outlineSelectedIndex(): int
  selectOutline(key: string): none
  expandOutline(key: string, recursive: bool): none
  collapseOutline(key: string, recursive: bool): none
  outlineSnapshot(): string
  performOutlineSelection(row: int): none
  static tabView(): NativeView
  addTab(title: string, content: NativeView): none
  setTabTitle(index: int, title: string): none
  selectTab(index: int): none
  setTabAction(handler: (index: int): none): none
  setTabLayoutHandler(handler: (index: int, width: double, height: double): none): none
  tabMetrics(): double[]
  tabSnapshot(): string
  performTabSelection(index: int): none
  static groupBox(title: string): NativeView
  groupBoxMetrics(): double[]
  groupBoxSnapshot(): string
  static split(axis: int): NativeView
  static scroll(): NativeView
  static text(value: string): NativeView
  static button(title: string): NativeView
  static textField(value: string, placeholder: string): NativeView
  static secureTextField(value: string, placeholder: string): NativeView
  static checkbox(title: string, checked: bool): NativeView
  static picker(options: string[], selected: string): NativeView
  static slider(value: double, minimum: double, maximum: double): NativeView
  static progressBar(value: double, minimum: double, maximum: double): NativeView
  static searchField(value: string, placeholder: string): NativeView
  static stepper(value: double, minimum: double, maximum: double, increment: double): NativeView
  static segmentedControl(segments: string[], selectedIndex: int): NativeView
  static separator(): NativeView
  static spinner(): NativeView
  static switchControl(checked: bool): NativeView
  static textArea(value: string): NativeView
  static radioGroup(options: string[], selected: string): NativeView
  static comboBox(options: string[], value: string): NativeView
  static datePicker(value: string): NativeView
  static colorWell(red: double, green: double, blue: double, alpha: double): NativeView
  static table(columnIds: string[], columnTitles: string[], columnWidths: double[], columnSortable: bool[]): NativeView
  static imageCanvas(): NativeView
  append(child: NativeView): none
  insertBefore(child: NativeView, reference: NativeView): none
  replace(child: NativeView, target: NativeView): none
  detach(): none
  dispose(): none
  setFrame(x: double, y: double, width: double, height: double): none
  setDocumentSize(width: double, height: double): none
  measureWidth(maxWidth: double | none, maxHeight: double | none): double
  measureHeight(maxWidth: double | none, maxHeight: double | none): double
  setText(value: string): none
  setEnabled(value: bool): none
  setHidden(value: bool): none
  setChecked(value: bool): none
  setSelectedValue(value: string): none
  setValue(value: double): none
  setSelectedIndex(value: int): none
  setDate(value: string): none
  setColor(red: double, green: double, blue: double, alpha: double): none
  setAction(handler: (value: string, checked: bool): none): none
  setValueAction(handler: (value: double): none): none
  setIndexAction(handler: (value: int): none): none
  setColorAction(handler: (red: double, green: double, blue: double, alpha: double): none): none
  setAccessibility(label: string, help: string, identifier: string): none
  setTitleElement(label: NativeView): none
  setSplitPosition(index: int, position: double): none
  setPaneWeights(weights: double[]): none
  setTextStyle(size: double, semibold: bool, secondary: bool): none
  setPaneLayoutHandler(handler: (index: int, width: double, height: double): none): none
  setTableData(
    rowCount: (): int,
    rowKey: (row: int): string,
    columnKind: (column: int): int,
    columnEditable: (column: int): bool,
    textValue: (row: int, column: int): string,
    boolValue: (row: int, column: int): bool,
    numberValue: (row: int, column: int): double,
    textChanged: (row: int, column: int, value: string): none,
    boolChanged: (row: int, column: int, value: bool): none,
    numberChanged: (row: int, column: int, value: double): none,
    dateChanged: (row: int, column: int, value: string): none,
  ): none
  reloadTable(): none
  setCanvasImage(encodedImage: readonly byte[]): none
  setCanvasBackground(background: int): none
  setCanvasClickAction(handler: (x: double, y: double): none): none
  setCanvasDropAction(handler: (paths: string[]): none): none
  zoomCanvas(factor: double): none
  actualSizeCanvas(): none
  fitCanvas(): none
}

export import class NativeWindow from "native_appkit.hpp" as doof_appkit::NativeWindow {
  static create(title: string, width: int, height: int, resizable: bool): NativeWindow
  setRoot(view: NativeView): none
  setLayoutHandler(handler: (width: double, height: double): none): none
  setToolbar(
    ids: string[],
    labels: string[],
    symbols: string[],
    toolTips: string[],
    kinds: int[],
    enabled: bool[],
    handlers: ((value: string, checked: bool): none)[],
    displayMode: int,
    allowsCustomization: bool,
  ): none
  setToolbarItemEnabled(index: int, enabled: bool): none
  show(): none
  close(): none
  isShown(): bool
  presentAlert(
    title: string,
    message: string,
    style: int,
    buttonTitles: string[],
    destructive: bool[],
    primaryIndex: int,
    cancelIndex: int,
    handler: (index: int): none,
  ): none
  presentSheet(
    title: string,
    width: int,
    height: int,
    content: NativeView,
    buttonTitles: string[],
    destructive: bool[],
    primaryIndex: int,
    cancelIndex: int,
    layoutHandler: (width: double, height: double): none,
    validateHandler: (index: int): bool,
    completionHandler: (index: int): none,
  ): none
}

export import class NativeApplication from "native_appkit.hpp" as doof_appkit::NativeApplication {
  static shared(): NativeApplication
  isRunning(): bool
  isMainThread(): bool
  shownWindowCount(): int
  run(drain: (): int): none
  quit(): none
  requestWake(): none
  setOpenFilesHandler(handler: (paths: string[]): none): none
  // The numeric node, role, action, and modifier values originate in menu.do.
  // NativeApplication::setMenu maps the semantic action IDs to AppKit selectors.
  setMenu(
    nodeKinds: int[],
    parentIndices: int[],
    menuRoles: int[],
    actions: int[],
    titles: string[],
    keys: string[],
    modifierMasks: int[],
    enabled: bool[],
    checked: bool[],
    handlerIndices: int[],
    handlers: ((value: string, checked: bool): none)[],
  ): none
  setMenuItemEnabled(index: int, enabled: bool): none
  setMenuItemChecked(index: int, checked: bool): none
  menuSnapshot(): string
  performMenuItem(index: int): none
  alert(
    title: string,
    message: string,
    style: int,
    buttonTitles: string[],
    destructive: bool[],
    primaryIndex: int,
    cancelIndex: int,
  ): int
  openFile(title: string, directories: bool, multiple: bool): string[]
  saveFile(title: string, suggestedName: string): string | none
}
