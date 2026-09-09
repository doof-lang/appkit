# Files-tree sample

Run on macOS with `doof run appkit/samples/outline` from the stdlib workspace.
When developing against this checkout, set `DOOF_STDLIB_ROOT` to the workspace
directory. The sample uses in-memory file nodes; it does not access the filesystem.

Select a file, collapse folders, and reload to exercise stable-key preservation
across replacement row instances. Reload updates the revision in `main.do`.
Clear removes all rows; Reload repopulates them. Reveal main.do expands its
ancestors and selects it without firing the user selection callback.

Interactive QA:

- Click disclosure triangles and rows; verify the selected name below the tree.
- Focus the tree and use Up/Down and Left/Right to navigate and expand/collapse.
- Select main.do, reload, and verify selection survives with its revised label.
- Clear and reload; verify stale selection does not return.
- Resize the window and check clipping, scrolling, and disclosure indentation.
- With VoiceOver, verify the Project files outline, row labels, hierarchy,
  expansion state, and selection are announced.
- Close the window after repeated reloads and selections; the app should exit.

Automated tests exercise hierarchy, selection delegate callbacks, reload, and
disposal. VoiceOver announcements and cross-macOS visual behavior require manual QA.
