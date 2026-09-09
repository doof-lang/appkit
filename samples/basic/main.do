import {
  Alert,
  AlertAction,
  AlertStyle,
  Button,
  Checkbox,
  Color,
  ColorWell,
  Column,
  ComboBox,
  DatePicker,
  FileDialogOptions,
  GroupBox,
  Menu,
  MenuItem,
  Picker,
  ProgressBar,
  RadioGroup,
  Row,
  SearchField,
  ScrollView,
  SegmentedControl,
  Separator,
  Sheet,
  SheetAction,
  SplitView,
  Slider,
  StandardApplicationMenu,
  StandardEditMenu,
  StandardViewMenu,
  StandardWindowMenu,
  Spinner,
  Stepper,
  Switch,
  Tab,
  TabView,
  Text,
  TextArea,
  TextField,
  Toolbar,
  ToolbarFlexibleSpace,
  ToolbarItem,
  Window,
  openFile,
  runApp,
  setAppMenus,
} from "std/appkit"
import { Date } from "std/time"

function main(): none {
  let selectedTab = 0
  let count = 0
  let enabled = true
  let name = ""
  let color = "Blue"
  let filter = ""
  let quantity = 1.0
  let viewMode = 0
  let notifications = true
  let notes = ""
  let delivery = "Email"
  let city = "Sydney"
  let chosenDate = try! Date.create(2026, 9, 3)
  let accent = Color { red: 0.2, green: 0.45, blue: 0.9 }

  toolbar := <Toolbar displayMode=.IconOnly>
    <ToolbarItem id="increment" label="Increment" symbol="plus"
      enabled=>enabled onClick=>{ count += 1 }/>
    <ToolbarFlexibleSpace/>
    <ToolbarItem id="reset" label="Reset" symbol="arrow.counterclockwise"
      enabled=>count != 0 onClick=>{ count = 0 }/>
  </Toolbar>

  let window: Window | none = none
  window = <Window title="" width=720 height=760 toolbar={toolbar}>
    <Text value={(): string => if name == "" then "Welcome" else "Welcome, ${name}"}/>
    <TextField label="Name" value=>name placeholder="Your name" onChange=>{name = value}/>
    <TabView selectedIndex=>selectedTab onChange=>{ selectedTab = selectedIndex }>
      <Tab title="Preferences">
        <GroupBox title="Preferences">
          <Picker label="Favorite color" options={["Blue", "Green", "Orange"]} selected=>color onChange=>{ color = value }/>
          <SearchField label="Filter" value=>filter onChange=>{ filter = value }/>
          <SegmentedControl label="View" segments={["List", "Grid"]} selectedIndex=>viewMode onChange=>{ viewMode = selectedIndex }/>
          <Stepper label="Quantity" value=>quantity minimum=0.0 maximum=10.0 onChange=>{ quantity = value }/>
          <Switch title="Notifications" checked=>notifications onChange=>{ notifications = checked }/>
        </GroupBox>
      </Tab>
      <Tab title="Delivery">
        <GroupBox title="Delivery and notes">
          <TextArea label="Notes" value=>notes minHeight=80.0 onChange=>{ notes = value }/>
          <RadioGroup label="Delivery" options={["Email", "Post", "Pickup"]} selected=>delivery onChange=>{ delivery = value }/>
          <ComboBox label="City" options={["Sydney", "Melbourne", "Brisbane"]} value=>city onChange=>{ city = value }/>
          <DatePicker label="Date" value=>chosenDate onChange=>{ chosenDate = value }/>
          <ColorWell label="Accent" value=>accent onChange=>{ accent = value }/>
        </GroupBox>
      </Tab>
    </TabView>
    <Slider value=>double(count) minimum=0.0 maximum=10.0 onChange=>{ count = int(value) } accessibilityLabel="Count"/>
    <ProgressBar value=>double(count) minimum=0.0 maximum=10.0 accessibilityLabel="Count progress"/>
    <Separator/>
    <Row><Spinner/><Text value="Native work in progress"/></Row>
    <Row>
      <Button title="Increment" enabled=>enabled onClick=> { count += 1 }/>
      <Checkbox title="Enable increment" checked=>enabled onChange=>{ enabled = checked }/>
    </Row>
    <SplitView>
      <Column>
        <Text value=> "Count: ${count}"/>
          <Button title="Choose file…" onClick=> {
            files := openFile(FileDialogOptions { title: "Choose a file" })
            if files.length > 0 {
              currentWindow := window as Window else { return }
              currentWindow.showAlert(Alert {
                title: "Selected",
                message: files[0],
                primary: AlertAction("Done"),
              })
            }
          }/>      
      </Column>
      <ScrollView>
        <Column>
          <Text value="Native AppKit controls"/>
          <Text value="std/layout geometry"/>
          <Text value="Native scrolling and split dividers"/>
          <Text value="Accessible labels and keyboard behavior"/>
        </Column>
      </ScrollView>
    </SplitView>
  </Window>

  currentWindow := window!
  showProfileSheet := (): none => {
    let draftName = name
    let validationMessage = ""
    sheet := <Sheet
      title="Edit Profile"
      width=440
      height=240
      primary={SheetAction(
        "Save",
        (): none => { name = draftName },
        (): bool => {
          if draftName.trim() != "" { return true }
          validationMessage = "Enter a name before saving."
          return false
        },
      )}
      cancel={SheetAction("Cancel")}>
      <TextField label="Name" value=>draftName placeholder="Your name" onChange=>{ draftName = value }/>
      <Text value=>validationMessage hidden=>validationMessage == ""/>
    </Sheet>
    currentWindow.showSheet(sheet)
  }
  setAppMenus([
    StandardApplicationMenu(),
    <Menu title="File">
      <MenuItem title="Edit Profile…" onSelect=>showProfileSheet()/>
    </Menu>,
    StandardEditMenu(),
    StandardViewMenu(),
    StandardWindowMenu(),
  ])
  currentWindow.show()
  runApp()
}
