# Tabbed settings sample

From the standard-library workspace on macOS:

```sh
export DOOF_STDLIB_ROOT="$PWD"
doof check appkit/samples/tabs
doof run appkit/samples/tabs
```

Three native tabs demonstrate retained controls, shared reactive state,
programmatic navigation, a reactive tab title, and nested `GroupBox` content.
Apply updates an in-memory status; nothing is saved to disk or sent.

Try these interactions:

1. Edit Name or Email. Profile gains an asterisk. Switch to Notifications and
   back: the draft survives, and the destination address follows Email.
2. Click Review changes. The selected page and page counter update, while
   Native tab changes stays unchanged: programmatic selection skips `onChange`.
3. Click the native Profile tab. Both page state and Native tab changes update.
4. Blank Name and review: Apply is disabled. Enter a name, review, and apply:
   the asterisk clears and the status changes.
5. Resize and switch pages. Native insets and the preferred size of the largest
   page keep the tab container stable across page changes.

For accessibility QA, navigate the tab strip using the keyboard and verify
VoiceOver announces Settings pages, tab titles, selection, and field labels.
These checks need to be performed on each supported macOS version.

See the [cookbook](../../docs/cookbook/tabs.md) for smaller complete programs,
including adding controls to a retained page.
