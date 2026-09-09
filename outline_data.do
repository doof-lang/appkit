// Flatten a finite tree once at construction/reload. Native item identity uses
// stable keys; row values remain typed and owned by Doof.
export class OutlineSnapshot<Row> {
  rows: Row[] = []
  keys: string[] = []
  parents: int[] = []
  indices: Map<string, int> = {}

  append(rows: Row[], parent: int, rowKey: (row: Row): string,
    children: (row: Row): Row[]): none {
    for row of rows {
      key := rowKey(row)
      if key == "" { panic("OutlineView row keys cannot be empty") }
      if indices.has(key) { panic("OutlineView row keys must be unique; duplicate or cycle: '${key}'") }
      index := this.rows.length
      indices.set(key, index)
      this.rows.push(row)
      keys.push(key)
      parents.push(parent)
      append(children(row), index, rowKey, children)
    }
  }
}

export class OutlineData<Row> {
  let snapshot: OutlineSnapshot<Row>
  rowKey: (row: Row): string
  children: (row: Row): Row[]
  label: (row: Row): string

  build(rows: Row[]): OutlineSnapshot<Row> {
    next := OutlineSnapshot<Row> {}
    next.append(rows, -1, rowKey, children)
    return next
  }

  rowAt(index: int): Row | none {
    if index < 0 || index >= snapshot.rows.length { return none }
    return snapshot.rows[index]
  }

  labelAt(index: int): string {
    row := rowAt(index) as Row else { return "" }
    return label(row)
  }

  requireKey(key: string): none {
    if !snapshot.indices.has(key) { panic("OutlineView row key not found: '${key}'") }
  }
}
