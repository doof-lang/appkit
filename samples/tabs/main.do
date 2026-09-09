import {
  Button, GroupBox, Row, Switch, Tab, TabView, Text, TextField, Window, runApp,
} from "std/appkit"

function main(): none {
  let selectedTab = 0
  let name = "Ada"
  let email = "ada@example.com"
  let notifications = true
  let dirty = false
  let userChanges = 0
  let status = "No changes applied."

  tabs := <TabView selectedIndex=>selectedTab
    onChange=>{ selectedTab = selectedIndex; userChanges += 1 }
    accessibilityLabel="Settings pages">
    <Tab title={(): string => if dirty then "Profile *" else "Profile"}>
      <GroupBox title="Profile">
        <TextField label="Name" value=>name onChange=>{ name = value; dirty = true }/>
        <TextField label="Email" value=>email onChange=>{ email = value; dirty = true }/>
        <Text value="Switch pages and return: your draft stays here."/>
      </GroupBox>
    </Tab>
    <Tab title="Notifications">
      <GroupBox title="Delivery">
        <Switch title="Enable notifications" checked=>notifications
          onChange=>{ notifications = checked; dirty = true }/>
        <Text value=>"Send to: ${email}"/>
      </GroupBox>
    </Tab>
    <Tab title="Review">
      <Text value=>"Name: ${name}"/>
      <Text value=>"Email: ${email}"/>
      <Text value={(): string => if notifications then "Notifications on" else "Notifications off"}/>
      <Button title="Apply" enabled={(): bool => dirty && name.trim() != ""}
        onClick=>{ status = "Applied settings for ${name.trim()}."; dirty = false }/>
      <Text value="Settings live in memory for this session."/>
    </Tab>
  </TabView>

  window := <Window title="Tabbed settings" width=600 height=380>
    {tabs}
    <Row>
      <Button title="Edit profile" onClick=>{ selectedTab = 0 }/>
      <Button title="Review changes" onClick=>{ selectedTab = 2 }/>
      <Text value=>"Page ${selectedTab + 1} of 3"/>
    </Row>
    <Text value=>"Native tab changes: ${userChanges}"/>
    <Text value=>status/>
  </Window>
  window.show()
  runApp()
  tabs.dispose()
}
