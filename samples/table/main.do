import {
  Button,
  CheckboxColumn,
  DateColumn,
  NumberColumn,
  Table,
  TextColumn,
  Window,
  runApp,
} from "std/appkit"
import { Date } from "std/time"

class Person {
  readonly id: string
  let name: string
  readonly email: string
  let active: bool
  let score: double
  let joined: Date
}

function main(): none {
  let people = [
    Person { id: "ada", name: "Ada Lovelace", email: "ada@example.com", active: true,
      score: 98.5, joined: try! Date.parse("2025-03-12") },
    Person { id: "grace", name: "Grace Hopper", email: "grace@example.com", active: true,
      score: 94.0, joined: try! Date.parse("2024-11-09") },
  ]

  table := <Table<Person> rows={people} rowKey=>row.id>
    <TextColumn<Person> id="name" title="Name" value=>row.name
      onChange=>{ row.name = value } sortable=true width=180.0/>
    <TextColumn<Person> id="email" title="Email" value=>row.email
      sortable=true width=240.0/>
    <CheckboxColumn<Person> id="active" title="Active" value=>row.active
      onChange=>{ row.active = value } sortable=true width=80.0/>
    <NumberColumn<Person> id="score" title="Score" value=>row.score
      onChange=>{ row.score = value } sortable=true width=90.0/>
    <DateColumn<Person> id="joined" title="Joined" value=>row.joined
      onChange=>{ row.joined = value } sortable=true width=140.0/>
  </Table>

  window := <Window title="People" width=860 height=360>
    <Button title="Add person" onClick=> {
      people.push(Person {
        id: "person-${people.length}",
        name: "Person ${people.length + 1}",
        email: "person${people.length + 1}@example.com",
        active: false,
        score: 0.0,
        joined: try! Date.parse("2026-09-03"),
      })
      table.reload(people)
    }/>
    {table}
  </Window>

  window.show()
  runApp()
}
