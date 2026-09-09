# A searchable, editable table

[Cookbook index](README.md)

Keep the complete source array separate from the filtered array supplied to
the table. Use stable row IDs, not array indexes or editable names. This
example uses class rows so both arrays refer to the same mutable records.

```doof
import {
  Button, CheckboxColumn, SearchField, Table, Text, TextColumn, Window, runApp,
} from "std/appkit"

class Person {
  readonly id: string
  let name: string
  let active: bool
}

function matching(people: Person[], query: string): Person[] {
  let result: Person[] = []
  for person of people {
    if query == "" || person.name.contains(query) { result.push(person) }
  }
  return result
}

function main(): none {
  let people = [
    Person { id: "ada", name: "Ada Lovelace", active: true },
    Person { id: "grace", name: "Grace Hopper", active: true },
    Person { id: "alan", name: "Alan Turing", active: false },
  ]
  let query = ""
  table := <Table<Person> rows={people} rowKey=>row.id
    accessibilityLabel="People">
    <TextColumn<Person> id="name" title="Name" value=>row.name
      onChange=>{ row.name = value } sortable=true width=280.0/>
    <CheckboxColumn<Person> id="active" title="Active" value=>row.active
      onChange=>{ row.active = value } sortable=true width=90.0/>
  </Table>

  window := <Window title="People" width=520 height=420>
    <SearchField label="Filter names (case-sensitive)" value=>query
      onChange=>{
        query = value
        table.reload(matching(people, query))
      }/>
    <Button title="Add person" onClick=>{
      people.push(Person {
        id: "new-${people.length}",
        name: "New person ${people.length + 1}",
        active: false,
      })
      table.reload(matching(people, query))
    }/>
    <Button title="Reapply filter and sort" onClick=>{
      table.reload(matching(people, query))
    }/>
    {table}
    <Text value=>"${table.rowCount()} of ${people.length} people"/>
  </Window>
  window.show()
  runApp()
}
```

Type `Ada`, clear the query, edit a name, and click a column header to sort.
Try a query with no matches: an empty array is a valid table data set. Adding
a row reapplies the current filter, so the new row may not be visible.

Cell commits update the source model but do not implicitly reload. Press
“Reapply filter and sort” after an edit to reconsider membership and ordering.
This keeps the reload boundary visible in the example. A production workflow
can schedule its refresh at an appropriate point after editing finishes.

Header sorting affects only display order. `reload` reapplies active sort
descriptors and preserves native selection by row key where the selected rows
remain. The public API does not yet report selection changes to Doof; this
recipe does not implement a selected-row inspector or delete-selected action.

The generated IDs here are sufficient because the recipe never removes rows.
If your application deletes or imports records, generate identities that
remain unique across those operations. For number/date columns, see the
[complete table sample](../../samples/table/main.do).
