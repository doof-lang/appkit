import { Date } from "std/time"

import { NativeView } from "./native"
import { syncUI } from "./runtime"
import { View, ViewElement, growingControl } from "./view"

readonly COLUMN_TEXT = 0
readonly COLUMN_CHECKBOX = 1
readonly COLUMN_NUMBER = 2
readonly COLUMN_DATE = 3

export class TableColumn<Row> {
  readonly id: string
  readonly title: string
  readonly width: double
  readonly sortable: bool
  private readonly kind: int
  private readonly editable: bool = false
  private readonly textValue: (row: Row): string = (row): string => ""
  private readonly boolValue: (row: Row): bool = (row): bool => false
  private readonly numberValue: (row: Row): double = (row): double => 0.0
  private readonly textChanged: (row: Row, value: string): none = (row, value): none => {}
  private readonly boolChanged: (row: Row, value: bool): none = (row, value): none => {}
  private readonly numberChanged: (row: Row, value: double): none = (row, value): none => {}
  private readonly dateChanged: (row: Row, value: Date): none = (row, value): none => {}
}

export function NumberColumn<Row>(
  id: string,
  title: string,
  value: (row: Row): double,
  onChange: ((row: Row, value: double): none) | none = none,
  sortable: bool = false,
  width: double = 0.0,
): TableColumn<Row> {
  if id == "" { panic("NumberColumn id cannot be empty") }
  if width < 0.0 { panic("NumberColumn width cannot be negative") }
  changed := onChange as (row: Row, value: double): none else {
    return TableColumn<Row> { id, title, width, sortable, kind: COLUMN_NUMBER, numberValue: value }
  }
  return TableColumn<Row> {
    id, title, width, sortable, kind: COLUMN_NUMBER, editable: true,
    numberValue: value, numberChanged: changed,
  }
}

export function DateColumn<Row>(
  id: string,
  title: string,
  value: (row: Row): Date,
  onChange: ((row: Row, value: Date): none) | none = none,
  sortable: bool = false,
  width: double = 0.0,
): TableColumn<Row> {
  if id == "" { panic("DateColumn id cannot be empty") }
  if width < 0.0 { panic("DateColumn width cannot be negative") }
  textValue := (row: Row): string => value(row).toISOString()
  changed := onChange as (row: Row, value: Date): none else {
    return TableColumn<Row> { id, title, width, sortable, kind: COLUMN_DATE, textValue }
  }
  return TableColumn<Row> {
    id, title, width, sortable, kind: COLUMN_DATE, editable: true,
    textValue, dateChanged: changed,
  }
}

export function TextColumn<Row>(
  id: string,
  title: string,
  value: (row: Row): string,
  onChange: ((row: Row, value: string): none) | none = none,
  sortable: bool = false,
  width: double = 0.0,
): TableColumn<Row> {
  if id == "" { panic("TextColumn id cannot be empty") }
  if width < 0.0 { panic("TextColumn width cannot be negative") }
  changed := onChange as (row: Row, value: string): none else {
    return TableColumn<Row> { id, title, width, sortable, kind: COLUMN_TEXT, textValue: value }
  }
  return TableColumn<Row> {
    id, title, width, sortable, kind: COLUMN_TEXT, editable: true,
    textValue: value, textChanged: changed,
  }
}

export function CheckboxColumn<Row>(
  id: string,
  title: string,
  value: (row: Row): bool,
  onChange: ((row: Row, value: bool): none) | none = none,
  sortable: bool = false,
  width: double = 0.0,
): TableColumn<Row> {
  if id == "" { panic("CheckboxColumn id cannot be empty") }
  if width < 0.0 { panic("CheckboxColumn width cannot be negative") }
  changed := onChange as (row: Row, value: bool): none else {
    return TableColumn<Row> { id, title, width, sortable, kind: COLUMN_CHECKBOX, boolValue: value }
  }
  return TableColumn<Row> {
    id, title, width, sortable, kind: COLUMN_CHECKBOX, editable: true,
    boolValue: value, boolChanged: changed,
  }
}

class TableData<Row> {
  let rows: Row[]
  rowKey: (row: Row): string
  columns: TableColumn<Row>[]

  keyAt(row: int): string {
    if row < 0 || row >= rows.length { return "" }
    return rowKey(rows[row])
  }

  kindAt(column: int): int {
    if column < 0 || column >= columns.length { return COLUMN_TEXT }
    return columns[column].kind
  }

  editableAt(column: int): bool {
    if column < 0 || column >= columns.length { return false }
    return columns[column].editable
  }

  textAt(row: int, column: int): string {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return "" }
    return columns[column].textValue(rows[row])
  }

  boolAt(row: int, column: int): bool {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return false }
    return columns[column].boolValue(rows[row])
  }

  numberAt(row: int, column: int): double {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return 0.0 }
    return columns[column].numberValue(rows[row])
  }

  changeText(row: int, column: int, value: string): none {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return }
    columns[column].textChanged(rows[row], value)
    syncUI()
  }

  changeBool(row: int, column: int, value: bool): none {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return }
    columns[column].boolChanged(rows[row], value)
    syncUI()
  }

  changeNumber(row: int, column: int, value: double): none {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return }
    columns[column].numberChanged(rows[row], value)
    syncUI()
  }

  changeDate(row: int, column: int, value: string): none {
    if row < 0 || row >= rows.length || column < 0 || column >= columns.length { return }
    columns[column].dateChanged(rows[row], try! Date.parse(value))
    syncUI()
  }
}

export class Table<Row> implements ViewElement {
  private data: TableData<Row>
  private native: NativeView
  private content: View

  static constructor(
    rows: Row[],
    rowKey: (row: Row): string,
    children: TableColumn<Row>[] = [],
    hidden: bool | ((): bool) = false,
    accessibilityLabel: string = "",
    accessibilityHelp: string = "",
    accessibilityIdentifier: string = "",
  ): Table<Row> {
    if children.length == 0 { panic("Table requires at least one column") }
    for index of 0..<children.length {
      for previous of 0..<index {
        if children[index].id == children[previous].id {
          panic("Table column ids must be unique: '${children[index].id}'")
        }
      }
    }

    let columnIds: string[] = []
    let columnTitles: string[] = []
    let columnWidths: double[] = []
    let columnSortable: bool[] = []
    for column of children {
      columnIds.push(column.id)
      columnTitles.push(column.title)
      columnWidths.push(column.width)
      columnSortable.push(column.sortable)
    }

    native := NativeView.table(columnIds, columnTitles, columnWidths, columnSortable)
    content := growingControl(native).hidden(hidden)
      .accessibility(accessibilityLabel, accessibilityHelp, accessibilityIdentifier)
    data := TableData<Row> { rows, rowKey, columns: children }
    native.setTableData(
      (): int => data.rows.length,
      (row): string => data.keyAt(row),
      (column): int => data.kindAt(column),
      (column): bool => data.editableAt(column),
      (row, column): string => data.textAt(row, column),
      (row, column): bool => data.boolAt(row, column),
      (row, column): double => data.numberAt(row, column),
      (row, column, value): none => data.changeText(row, column, value),
      (row, column, value): none => data.changeBool(row, column, value),
      (row, column, value): none => data.changeNumber(row, column, value),
      (row, column, value): none => data.changeDate(row, column, value),
    )
    native.reloadTable()
    return Table<Row> { data, native, content }
  }

  asView(): View => content

  reload(rows: Row[]): none {
    data.rows = rows
    native.reloadTable()
  }

  rowCount(): int => data.rows.length
}
