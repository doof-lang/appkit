import { Button, OutlineView, Row, Text, Window, runApp } from "std/appkit"

class FileNode {
  id: string
  name: string
  nodes: FileNode[] = []
}

function files(revision: int): FileNode[] {
  return [FileNode { id: "project", name: "Project", nodes: [
    FileNode { id: "sources", name: "Sources", nodes: [
      FileNode { id: "main", name: "main.do (revision ${revision})" },
      FileNode { id: "model", name: "model.do" },
    ] },
    FileNode { id: "readme", name: "README.md" },
  ] }]
}

function main(): none {
  let revision = 1
  let selection = "No selection"
  outline := OutlineView<FileNode>{rows: files(revision),
    rowKey: =>row.id, children: =>row.nodes, label: =>row.name,
    accessibilityLabel: "Project files",
    accessibilityHelp: "Use arrow keys to navigate and expand folders",
    accessibilityIdentifier: "project-files",
    onSelect: (row): none => {
      file := row as FileNode else { selection = "No selection"; return }
      selection = file.name
    }}
  outline.expand("project", true)
  window := <Window title="Files — OutlineView" width=600 height=420>
    <Text value="Project files"/>
    <Row>
      <Button title="Reload" onClick=>{
        revision += 1
        outline.reload(files(revision))
        selected := outline.selected() as FileNode else { selection = "No selection"; return }
        selection = selected.name
      }/>
      <Button title="Reveal main.do" enabled={(): bool => outline.rowCount() > 0} onClick=>{
        outline.select("main")
        selection = outline.selected()!.name
      }/>
      <Button title="Collapse all" enabled={(): bool => outline.rowCount() > 0}
        onClick=>outline.collapse("project", true)/>
      <Button title="Clear" onClick=>{ outline.reload([]); selection = "No selection" }/>
    </Row>
    {outline}
    <Text value=>selection/>
  </Window>
  window.show()
  runApp()
  outline.asView().dispose()
}
