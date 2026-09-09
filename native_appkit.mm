#include "native_appkit.hpp"
#import <Cocoa/Cocoa.h>
#if !__has_feature(objc_arc)
#error "std/appkit requires Objective-C ARC (-fobjc-arc)"
#endif
#include <algorithm>
#include <functional>
#include <unordered_set>

static NSString* ns(const std::string& value) { return [NSString stringWithUTF8String:value.c_str()]; }
static std::string utf8(NSString* value) { return value ? std::string([value UTF8String]) : std::string(); }
static NSDateFormatter* dateFormatter() { NSDateFormatter* formatter = [NSDateFormatter new]; formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]; formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; formatter.dateFormat = @"yyyy-MM-dd"; return formatter; }
static NSDate* dateFromISO(const std::string& value) { return [dateFormatter() dateFromString:ns(value)]; }
static std::string isoFromDate(NSDate* value) { return utf8([dateFormatter() stringFromDate:value]); }
static NSColor* colorFromRGBA(double red, double green, double blue, double alpha) { return [NSColor colorWithSRGBRed:std::clamp(red, 0.0, 1.0) green:std::clamp(green, 0.0, 1.0) blue:std::clamp(blue, 0.0, 1.0) alpha:std::clamp(alpha, 0.0, 1.0)]; }

@interface DoofFlippedView : NSView @end
@implementation DoofFlippedView
- (BOOL)isFlipped { return YES; }
- (BOOL)isAccessibilityElement { return NO; }
@end

#include "native_group_box.hpp"
#include "native_tab_view.hpp"
#include "native_outline_view.hpp"
#include "native_source_view.hpp"

@interface DoofValueTarget : NSObject
@property(nonatomic) doof::callback<void(double)> callback;
- (void)activate:(id)sender;
@end
@implementation DoofValueTarget
- (void)activate:(id)sender { self.callback.call([sender doubleValue]); }
@end

@interface DoofIndexTarget : NSObject
@property(nonatomic) doof::callback<void(int32_t)> callback;
- (void)activate:(id)sender;
@end
@implementation DoofIndexTarget
- (void)activate:(id)sender { self.callback.call((int32_t)[sender selectedSegment]); }
@end

@interface DoofColorTarget : NSObject
@property(nonatomic) doof::callback<void(double, double, double, double)> callback;
- (void)activate:(id)sender;
@end
@implementation DoofColorTarget
- (void)activate:(id)sender { NSColor* color = [[sender color] colorUsingColorSpace:NSColorSpace.sRGBColorSpace]; self.callback.call(color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent); }
@end

@interface DoofTextViewTarget : NSObject <NSTextViewDelegate>
@property(nonatomic) doof::callback<void(std::string, bool)> callback;
@end
@implementation DoofTextViewTarget
- (void)textDidChange:(NSNotification*)notification { self.callback.call(utf8([(NSTextView*)notification.object string]), false); }
@end

@interface DoofLayoutHostView : DoofFlippedView
@property(nonatomic) doof::callback<void(double, double)> callback;
@end
@implementation DoofLayoutHostView
- (void)layout { [super layout]; if (self.callback) self.callback.call(self.bounds.size.width, self.bounds.size.height); }
@end

#include "native_split_view.hpp"

@interface DoofImageCanvasView : NSView
@property(nonatomic) doof::callback<void(double, double)> clickCallback;
@property(nonatomic) doof::callback<void(std::shared_ptr<std::vector<std::string>>)> dropCallback;
@property(nonatomic, strong) NSImage* image;
@property(nonatomic) NSPoint pointerDown;
@property(nonatomic) NSPoint scrollOriginDown;
@property(nonatomic) BOOL dragging;
@property(nonatomic) BOOL dropActive;
@property(nonatomic) int32_t backgroundMode;
@end

@implementation DoofImageCanvasView
- (BOOL)isFlipped { return YES; }
- (BOOL)isAccessibilityElement { return YES; }
- (NSString*)accessibilityRole { return NSAccessibilityImageRole; }
- (void)drawRect:(NSRect)dirtyRect {
    if (self.backgroundMode == 1) {
        [NSColor.whiteColor setFill];
        NSRectFill(dirtyRect);
    } else if (self.backgroundMode == 2) {
        [NSColor.blackColor setFill];
        NSRectFill(dirtyRect);
    } else {
        const CGFloat tile = 12.0;
        [[NSColor colorWithWhite:0.72 alpha:1.0] setFill];
        NSRectFill(dirtyRect);
        [[NSColor colorWithWhite:0.88 alpha:1.0] setFill];
        NSInteger minX = (NSInteger)floor(NSMinX(dirtyRect) / tile);
        NSInteger maxX = (NSInteger)ceil(NSMaxX(dirtyRect) / tile);
        NSInteger minY = (NSInteger)floor(NSMinY(dirtyRect) / tile);
        NSInteger maxY = (NSInteger)ceil(NSMaxY(dirtyRect) / tile);
        for (NSInteger y = minY; y < maxY; ++y) {
            for (NSInteger x = minX; x < maxX; ++x) {
                if ((x + y) % 2 == 0) NSRectFill(NSMakeRect(x * tile, y * tile, tile, tile));
            }
        }
    }
    if (self.image) {
        [self.image drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:@{NSImageHintInterpolation: @(NSImageInterpolationNone)}];
    }
    if (self.dropActive) {
        [NSColor.controlAccentColor setStroke];
        NSFrameRectWithWidth(NSInsetRect(self.bounds, 4.0, 4.0), 5.0);
    }
}
- (void)mouseDown:(NSEvent*)event {
    self.pointerDown = [self convertPoint:event.locationInWindow fromView:nil];
    self.scrollOriginDown = self.enclosingScrollView.contentView.bounds.origin;
    self.dragging = NO;
}
- (void)mouseDragged:(NSEvent*)event {
    NSPoint current = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat dx = current.x - self.pointerDown.x;
    CGFloat dy = current.y - self.pointerDown.y;
    if (!self.dragging && hypot(dx, dy) < 4.0) return;
    self.dragging = YES;
    NSClipView* clip = self.enclosingScrollView.contentView;
    [clip scrollToPoint:NSMakePoint(self.scrollOriginDown.x - dx, self.scrollOriginDown.y - dy)];
    [self.enclosingScrollView reflectScrolledClipView:clip];
}
- (void)mouseUp:(NSEvent*)event {
    if (self.dragging || !self.clickCallback) return;
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (NSPointInRect(point, self.bounds)) self.clickCallback.call(point.x, point.y);
}
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (!self.dropCallback || ![sender.draggingPasteboard canReadObjectForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}]) {
        return NSDragOperationNone;
    }
    self.dropActive = YES;
    [self setNeedsDisplay:YES];
    return NSDragOperationCopy;
}
- (void)draggingExited:(id<NSDraggingInfo>)sender {
    self.dropActive = NO;
    [self setNeedsDisplay:YES];
}
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender { return self.dropCallback ? YES : NO; }
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    self.dropActive = NO;
    [self setNeedsDisplay:YES];
    if (!self.dropCallback) return NO;
    NSArray<NSURL*>* urls = [sender.draggingPasteboard readObjectsForClasses:@[NSURL.class] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    auto paths = std::make_shared<std::vector<std::string>>();
    paths->reserve(urls.count);
    for (NSURL* url in urls) if (url.fileURL) paths->push_back(utf8(url.path));
    if (paths->empty()) return NO;
    self.dropCallback.call(paths);
    return YES;
}
@end

@interface DoofTableTextField : NSTextField
@property(nonatomic) int32_t sourceRow;
@property(nonatomic) int32_t sourceColumn;
@end
@implementation DoofTableTextField @end

@interface DoofTableCheckbox : NSButton
@property(nonatomic) int32_t sourceRow;
@property(nonatomic) int32_t sourceColumn;
@end
@implementation DoofTableCheckbox @end

@interface DoofTableDatePicker : NSDatePicker
@property(nonatomic) int32_t sourceRow;
@property(nonatomic) int32_t sourceColumn;
@end
@implementation DoofTableDatePicker @end

@interface DoofTableAdapter : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate> {
@public
    std::vector<int32_t> _displayRows;
    std::vector<std::string> _columnIds;
}
@property(nonatomic, weak) NSTableView* tableView;
@property(nonatomic) doof::callback<int32_t()> rowCount;
@property(nonatomic) doof::callback<std::string(int32_t)> rowKey;
@property(nonatomic) doof::callback<int32_t(int32_t)> columnKind;
@property(nonatomic) doof::callback<bool(int32_t)> columnEditable;
@property(nonatomic) doof::callback<std::string(int32_t, int32_t)> textValue;
@property(nonatomic) doof::callback<bool(int32_t, int32_t)> boolValue;
@property(nonatomic) doof::callback<double(int32_t, int32_t)> numberValue;
@property(nonatomic) doof::callback<void(int32_t, int32_t, std::string)> textChanged;
@property(nonatomic) doof::callback<void(int32_t, int32_t, bool)> boolChanged;
@property(nonatomic) doof::callback<void(int32_t, int32_t, double)> numberChanged;
@property(nonatomic) doof::callback<void(int32_t, int32_t, std::string)> dateChanged;
- (void)reloadResetRows:(BOOL)resetRows;
@end

@implementation DoofTableAdapter
- (int32_t)sourceRowForDisplayRow:(NSInteger)row {
    if (row < 0 || (size_t)row >= _displayRows.size()) return -1;
    return _displayRows[(size_t)row];
}
- (int32_t)sourceColumnForTableColumn:(NSTableColumn*)tableColumn {
    std::string id = utf8(tableColumn.identifier);
    for (size_t index = 0; index < _columnIds.size(); ++index) {
        if (_columnIds[index] == id) return (int32_t)index;
    }
    return -1;
}
- (void)sortDisplayRows {
    NSArray<NSSortDescriptor*>* descriptors = self.tableView.sortDescriptors;
    if (descriptors.count == 0) return;
    std::stable_sort(_displayRows.begin(), _displayRows.end(), [self, descriptors](int32_t left, int32_t right) {
        for (NSSortDescriptor* descriptor in descriptors) {
            NSTableColumn* tableColumn = [self.tableView tableColumnWithIdentifier:descriptor.key];
            int32_t column = tableColumn ? [self sourceColumnForTableColumn:tableColumn] : -1;
            if (column < 0) continue;
            NSComparisonResult comparison = NSOrderedSame;
            int32_t kind = self.columnKind ? self.columnKind.call(column) : 0;
            if (kind == 1) {
                bool leftValue = self.boolValue && self.boolValue.call(left, column);
                bool rightValue = self.boolValue && self.boolValue.call(right, column);
                if (leftValue != rightValue) comparison = leftValue ? NSOrderedDescending : NSOrderedAscending;
            } else if (kind == 2) {
                double leftValue = self.numberValue ? self.numberValue.call(left, column) : 0.0;
                double rightValue = self.numberValue ? self.numberValue.call(right, column) : 0.0;
                if (leftValue < rightValue) comparison = NSOrderedAscending;
                else if (leftValue > rightValue) comparison = NSOrderedDescending;
            } else {
                std::string leftValue = self.textValue ? self.textValue.call(left, column) : std::string();
                std::string rightValue = self.textValue ? self.textValue.call(right, column) : std::string();
                comparison = [ns(leftValue) localizedCaseInsensitiveCompare:ns(rightValue)];
            }
            if (comparison != NSOrderedSame) return descriptor.ascending ? comparison == NSOrderedAscending : comparison == NSOrderedDescending;
        }
        return false;
    });
}
- (void)reloadResetRows:(BOOL)resetRows {
    std::unordered_set<std::string> selectedKeys;
    NSIndexSet* previousSelection = self.tableView.selectedRowIndexes;
    for (NSUInteger displayRow = previousSelection.firstIndex; displayRow != NSNotFound; displayRow = [previousSelection indexGreaterThanIndex:displayRow]) {
        int32_t sourceRow = [self sourceRowForDisplayRow:(NSInteger)displayRow];
        if (sourceRow >= 0 && self.rowKey) selectedKeys.insert(self.rowKey.call(sourceRow));
    }
    if (resetRows) {
        _displayRows.clear();
        int32_t count = self.rowCount ? self.rowCount.call() : 0;
        _displayRows.reserve((size_t)std::max(0, count));
        for (int32_t row = 0; row < count; ++row) _displayRows.push_back(row);
    }
    [self sortDisplayRows];
    [self.tableView reloadData];
    auto selectedRows = [NSMutableIndexSet indexSet];
    for (size_t displayRow = 0; displayRow < _displayRows.size(); ++displayRow) {
        int32_t sourceRow = _displayRows[displayRow];
        if (self.rowKey && selectedKeys.find(self.rowKey.call(sourceRow)) != selectedKeys.end()) [selectedRows addIndex:(NSUInteger)displayRow];
    }
    [self.tableView selectRowIndexes:selectedRows byExtendingSelection:NO];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    return (NSInteger)_displayRows.size();
}
- (NSView*)tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row {
    int32_t column = [self sourceColumnForTableColumn:tableColumn];
    int32_t sourceRow = [self sourceRowForDisplayRow:row];
    if (column < 0 || sourceRow < 0) return nil;
    int32_t kind = self.columnKind ? self.columnKind.call(column) : 0;
    bool editable = self.columnEditable && self.columnEditable.call(column);
    NSTableCellView* cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = tableColumn.identifier;
        if (kind == 1) {
            DoofTableCheckbox* checkbox = [[DoofTableCheckbox alloc] initWithFrame:NSZeroRect];
            checkbox.buttonType = NSButtonTypeSwitch;
            checkbox.title = @"";
            checkbox.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:checkbox];
            [NSLayoutConstraint activateConstraints:@[
                [checkbox.centerXAnchor constraintEqualToAnchor:cell.centerXAnchor],
                [checkbox.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            ]];
        } else if (kind == 3 && editable) {
            DoofTableDatePicker* picker = [[DoofTableDatePicker alloc] initWithFrame:NSZeroRect];
            picker.datePickerElements = NSYearMonthDayDatePickerElementFlag;
            picker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
            picker.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            picker.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:picker];
            [NSLayoutConstraint activateConstraints:@[
                [picker.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4.0],
                [picker.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-4.0],
                [picker.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            ]];
        } else {
            DoofTableTextField* field = [[DoofTableTextField alloc] initWithFrame:NSZeroRect];
            field.bezeled = NO;
            field.drawsBackground = NO;
            field.lineBreakMode = NSLineBreakByTruncatingTail;
            if (kind == 2) {
                NSNumberFormatter* formatter = [NSNumberFormatter new];
                formatter.numberStyle = NSNumberFormatterDecimalStyle;
                field.formatter = formatter;
            }
            field.translatesAutoresizingMaskIntoConstraints = NO;
            cell.textField = field;
            [cell addSubview:field];
            [NSLayoutConstraint activateConstraints:@[
                [field.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4.0],
                [field.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-4.0],
                [field.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            ]];
        }
    }
    if (kind == 1) {
        DoofTableCheckbox* checkbox = (DoofTableCheckbox*)cell.subviews.firstObject;
        checkbox.sourceRow = sourceRow;
        checkbox.sourceColumn = column;
        checkbox.enabled = editable;
        checkbox.target = editable ? self : nil;
        checkbox.action = editable ? @selector(checkboxChanged:) : nil;
        checkbox.state = self.boolValue && self.boolValue.call(sourceRow, column)
            ? NSControlStateValueOn : NSControlStateValueOff;
    } else if (kind == 3 && editable) {
        DoofTableDatePicker* picker = (DoofTableDatePicker*)cell.subviews.firstObject;
        picker.sourceRow = sourceRow;
        picker.sourceColumn = column;
        picker.target = self;
        picker.action = @selector(dateChanged:);
        NSDate* value = dateFromISO(self.textValue ? self.textValue.call(sourceRow, column) : std::string());
        if (value) picker.dateValue = value;
    } else {
        DoofTableTextField* field = (DoofTableTextField*)cell.textField;
        field.sourceRow = sourceRow;
        field.sourceColumn = column;
        field.editable = editable;
        field.selectable = editable;
        field.delegate = editable ? self : nil;
        if (kind == 2) field.doubleValue = self.numberValue ? self.numberValue.call(sourceRow, column) : 0.0;
        else field.stringValue = ns(self.textValue ? self.textValue.call(sourceRow, column) : std::string());
    }
    return cell;
}
- (void)controlTextDidEndEditing:(NSNotification*)notification {
    DoofTableTextField* field = (DoofTableTextField*)notification.object;
    int32_t kind = self.columnKind ? self.columnKind.call(field.sourceColumn) : 0;
    if (kind == 2) {
        if (self.numberChanged) self.numberChanged.call(field.sourceRow, field.sourceColumn, field.doubleValue);
    } else if (self.textChanged) {
        self.textChanged.call(field.sourceRow, field.sourceColumn, utf8(field.stringValue));
    }
}
- (void)checkboxChanged:(DoofTableCheckbox*)checkbox {
    if (self.boolChanged) self.boolChanged.call(checkbox.sourceRow, checkbox.sourceColumn, checkbox.state == NSControlStateValueOn);
}
- (void)dateChanged:(DoofTableDatePicker*)picker {
    if (self.dateChanged) self.dateChanged.call(picker.sourceRow, picker.sourceColumn, isoFromDate(picker.dateValue));
}
- (void)tableView:(NSTableView*)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor*>*)oldDescriptors {
    [self reloadResetRows:NO];
}
@end

@interface DoofTarget : NSObject <NSTextFieldDelegate>
@property(nonatomic) doof::callback<void(std::string, bool)> callback;
@property(nonatomic) BOOL menuItemEnabled;
- (void)activate:(id)sender;
@end
@implementation DoofTarget
- (void)activate:(id)sender {
    bool checked = [sender respondsToSelector:@selector(state)] && [sender state] == NSControlStateValueOn;
    std::string value;
    if ([sender isKindOfClass:NSDatePicker.class]) value = isoFromDate([(NSDatePicker*)sender dateValue]);
    else if ([sender isKindOfClass:NSPopUpButton.class]) value = utf8([(NSPopUpButton*)sender titleOfSelectedItem]);
    else if ([sender isKindOfClass:NSButton.class]) value = utf8([(NSButton*)sender title]);
    else if ([sender respondsToSelector:@selector(stringValue)]) value = utf8([sender stringValue]);
    self.callback.call(value, checked);
}
- (void)controlTextDidChange:(NSNotification*)notification {
    self.callback.call(utf8([(NSTextField*)notification.object stringValue]), false);
}
- (void)comboBoxSelectionDidChange:(NSNotification*)notification {
    self.callback.call(utf8([(NSComboBox*)notification.object stringValue]), false);
}
- (BOOL)validateMenuItem:(NSMenuItem*)menuItem { return self.menuItemEnabled; }
@end

@interface DoofToolbarDelegate : NSObject <NSToolbarDelegate> {
    std::vector<doof::callback<void(std::string, bool)>> _handlers;
    std::vector<DoofTarget*> _targets;
}
@property(nonatomic, strong) NSArray<NSString*>* itemIdentifiers;
@property(nonatomic, strong) NSArray<NSString*>* labels;
@property(nonatomic, strong) NSArray<NSString*>* symbols;
@property(nonatomic, strong) NSArray<NSString*>* toolTips;
@property(nonatomic, strong) NSArray<NSNumber*>* kinds;
@property(nonatomic, strong) NSArray<NSNumber*>* enabledItems;
@property(nonatomic, strong) NSMutableArray* items;
@end

@implementation DoofToolbarDelegate
- (NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return self.itemIdentifiers;
}
- (NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return self.itemIdentifiers;
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)identifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSUInteger index = [self.itemIdentifiers indexOfObject:identifier];
    if (index == NSNotFound || index >= self.kinds.count || self.kinds[index].intValue != 0) return nil;
    NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.autovalidates = NO;
    item.label = self.labels[index];
    item.paletteLabel = self.labels[index];
    item.toolTip = self.toolTips[index].length > 0 ? self.toolTips[index] : nil;
    item.enabled = index < self.enabledItems.count ? self.enabledItems[index].boolValue : YES;
    if (self.symbols[index].length > 0) {
        if (@available(macOS 11.0, *)) {
            item.image = [NSImage imageWithSystemSymbolName:self.symbols[index] accessibilityDescription:self.labels[index]];
        }
    }
    DoofTarget* target = [DoofTarget new];
    target.callback = _handlers[index];
    _targets.push_back(target);
    item.target = target;
    item.action = @selector(activate:);
    self.items[index] = item;
    return item;
}
- (void)setHandlers:(const std::shared_ptr<std::vector<doof::callback<void(std::string, bool)>>>&)handlers {
    _handlers = *handlers;
}
@end

@interface DoofSheetButtonTarget : NSObject
@property(nonatomic, weak) NSWindow* sheet;
@property(nonatomic) int32_t index;
@property(nonatomic) doof::callback<bool(int32_t)> validate;
- (void)activate:(id)sender;
@end
@implementation DoofSheetButtonTarget
- (void)activate:(id)sender {
    if (self.validate && !self.validate.call(self.index)) return;
    [self.sheet.sheetParent endSheet:self.sheet returnCode:NSAlertFirstButtonReturn + self.index];
}
@end

namespace {
bool appRunning = false;
int32_t shownWindows = 0;
doof::callback<int32_t()> appDrain;
void stopIfLastWindowClosed() { if (appRunning && shownWindows == 0) [NSApplication.sharedApplication stop:nil]; }

NSAlertStyle alertStyle(int32_t style) {
    if (style == 1) return NSAlertStyleWarning;
    if (style == 2) return NSAlertStyleCritical;
    return NSAlertStyleInformational;
}

NSAlert* createAlert(
    const std::string& title,
    const std::string& message,
    int32_t style,
    const std::shared_ptr<std::vector<std::string>>& buttonTitles,
    const std::shared_ptr<std::vector<bool>>& destructive,
    int32_t primaryIndex,
    int32_t cancelIndex
) {
    NSAlert* alert = [NSAlert new];
    alert.messageText = ns(title);
    alert.informativeText = ns(message);
    alert.alertStyle = alertStyle(style);
    for (size_t index = 0; index < buttonTitles->size(); ++index) {
        NSButton* button = [alert addButtonWithTitle:ns((*buttonTitles)[index])];
        button.keyEquivalent = @"";
        button.keyEquivalentModifierMask = 0;
        if (index < destructive->size() && (*destructive)[index]) {
            if (@available(macOS 11.0, *)) button.hasDestructiveAction = YES;
        }
    }
    if (primaryIndex >= 0 && (size_t)primaryIndex < alert.buttons.count) {
        alert.buttons[(NSUInteger)primaryIndex].keyEquivalent = @"\r";
    }
    if (cancelIndex >= 0 && (size_t)cancelIndex < alert.buttons.count) {
        alert.buttons[(NSUInteger)cancelIndex].keyEquivalent = @"\033";
    }
    return alert;
}

int32_t alertResponseIndex(NSModalResponse response, size_t buttonCount) {
    NSInteger index = response - NSAlertFirstButtonReturn;
    if (index < 0 || (size_t)index >= buttonCount) return -1;
    return (int32_t)index;
}
}

@interface DoofWindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic) bool counted;
@end
@implementation DoofWindowDelegate
- (void)windowWillClose:(NSNotification*)notification {
    if (!self.counted) return;
    self.counted = false;
    [NSApplication.sharedApplication removeWindowsItem:(NSWindow*)notification.object];
    shownWindows = std::max<int32_t>(0, shownWindows - 1);
    dispatch_async(dispatch_get_main_queue(), ^{ stopIfLastWindowClosed(); });
}
@end

@interface DoofAppDelegate : NSObject <NSApplicationDelegate> {
@public
    doof::callback<void(std::shared_ptr<std::vector<std::string>>)> _openFilesHandler;
    std::shared_ptr<std::vector<std::string>> _pendingOpenFiles;
}
@end
@implementation DoofAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender { return NO; }
- (void)application:(NSApplication*)sender openFiles:(NSArray<NSString*>*)filenames {
    auto paths = std::make_shared<std::vector<std::string>>();
    paths->reserve(filenames.count);
    for (NSString* filename in filenames) paths->push_back(utf8(filename));
    if (_openFilesHandler) {
        _openFilesHandler.call(paths);
    } else {
        _pendingOpenFiles = paths;
    }
    [sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}
@end

namespace doof_appkit {
struct NativeView::Impl {
    DoofSourceAdapter* sourceAdapter = nil;
    NSView* view = nil;
    NSBox* groupBox = nil;
    DoofTabView* tabs = nil;
    NSOutlineView* outline = nil;
    DoofOutlineAdapter* outlineAdapter = nil;
    NSScrollView* scroll = nil;
    DoofSplitView* split = nil;
    NSTextView* textView = nil;
    NSStackView* radioGroup = nil;
    NSTableView* table = nil;
    DoofImageCanvasView* imageCanvas = nil;
    DoofTableAdapter* tableAdapter = nil;
    NSObject* target = nil;
    std::vector<std::shared_ptr<NativeView>> children;
    bool disposed = false;
    bool splitSized = false;
};
NativeView::NativeView() : impl_(std::make_shared<Impl>()) {}
NativeView::~NativeView() = default;

#include "native_tab_methods.inc"
#include "native_outline_methods.inc"
#include "native_source_methods.inc"

std::shared_ptr<NativeView> NativeView::container() { auto result = std::shared_ptr<NativeView>(new NativeView()); result->impl_->view = [[DoofFlippedView alloc] initWithFrame:NSZeroRect]; return result; }
std::shared_ptr<NativeView> NativeView::groupBox(const std::string& title) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    result->impl_->groupBox = makeGroupBox(ns(title));
    result->impl_->view = result->impl_->groupBox;
    return result;
}
std::shared_ptr<std::vector<double>> NativeView::groupBoxMetrics() {
    return measureGroupBox(impl_->groupBox);
}
std::string NativeView::groupBoxSnapshot() { return snapshotGroupBox(impl_->groupBox); }
std::shared_ptr<NativeView> NativeView::split(int32_t axis) { auto result = std::shared_ptr<NativeView>(new NativeView()); result->impl_->split = [[DoofSplitView alloc] initWithFrame:NSZeroRect]; result->impl_->split.delegate = result->impl_->split; result->impl_->split.vertical = axis == 0; result->impl_->split.dividerStyle = NSSplitViewDividerStyleThin; result->impl_->view = result->impl_->split; return result; }
std::shared_ptr<NativeView> NativeView::scroll() { auto result = std::shared_ptr<NativeView>(new NativeView()); result->impl_->scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect]; result->impl_->scroll.hasVerticalScroller = YES; result->impl_->scroll.autohidesScrollers = YES; result->impl_->scroll.drawsBackground = NO; result->impl_->view = result->impl_->scroll; return result; }
std::shared_ptr<NativeView> NativeView::text(const std::string& value) { auto result = std::shared_ptr<NativeView>(new NativeView()); result->impl_->view = [NSTextField labelWithString:ns(value)]; return result; }
std::shared_ptr<NativeView> NativeView::button(const std::string& title) { auto result = std::shared_ptr<NativeView>(new NativeView()); result->impl_->view = [NSButton buttonWithTitle:ns(title) target:nil action:nil]; return result; }
std::shared_ptr<NativeView> NativeView::textField(const std::string& value, const std::string& placeholder) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto field = [[NSTextField alloc] initWithFrame:NSZeroRect]; field.stringValue = ns(value); field.placeholderString = ns(placeholder); result->impl_->view = field; return result; }
std::shared_ptr<NativeView> NativeView::secureTextField(const std::string& value, const std::string& placeholder) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto field = [[NSSecureTextField alloc] initWithFrame:NSZeroRect]; field.stringValue = ns(value); field.placeholderString = ns(placeholder); result->impl_->view = field; return result; }
std::shared_ptr<NativeView> NativeView::checkbox(const std::string& title, bool checked) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto button = [NSButton checkboxWithTitle:ns(title) target:nil action:nil]; button.state = checked ? NSControlStateValueOn : NSControlStateValueOff; result->impl_->view = button; return result; }
std::shared_ptr<NativeView> NativeView::picker(const std::shared_ptr<std::vector<std::string>>& options, const std::string& selected) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto picker = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO]; for (const auto& option : *options) [picker addItemWithTitle:ns(option)]; if (!selected.empty()) [picker selectItemWithTitle:ns(selected)]; result->impl_->view = picker; return result; }
std::shared_ptr<NativeView> NativeView::slider(double value, double minimum, double maximum) { auto result = std::shared_ptr<NativeView>(new NativeView()); result->impl_->view = [NSSlider sliderWithValue:value minValue:minimum maxValue:maximum target:nil action:nil]; return result; }
std::shared_ptr<NativeView> NativeView::progressBar(double value, double minimum, double maximum) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto progress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect]; progress.indeterminate = NO; progress.minValue = minimum; progress.maxValue = maximum; progress.doubleValue = value; result->impl_->view = progress; return result; }
std::shared_ptr<NativeView> NativeView::searchField(const std::string& value, const std::string& placeholder) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto field = [[NSSearchField alloc] initWithFrame:NSZeroRect]; field.stringValue = ns(value); field.placeholderString = ns(placeholder); result->impl_->view = field; return result; }
std::shared_ptr<NativeView> NativeView::stepper(double value, double minimum, double maximum, double increment) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto stepper = [[NSStepper alloc] initWithFrame:NSZeroRect]; stepper.minValue = minimum; stepper.maxValue = maximum; stepper.increment = increment; stepper.doubleValue = value; result->impl_->view = stepper; return result; }
std::shared_ptr<NativeView> NativeView::segmentedControl(const std::shared_ptr<std::vector<std::string>>& segments, int32_t selectedIndex) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto control = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect]; control.segmentCount = segments->size(); control.trackingMode = NSSegmentSwitchTrackingSelectOne; for (size_t i = 0; i < segments->size(); ++i) [control setLabel:ns((*segments)[i]) forSegment:i]; control.selectedSegment = selectedIndex; result->impl_->view = control; return result; }
std::shared_ptr<NativeView> NativeView::separator() { auto result = std::shared_ptr<NativeView>(new NativeView()); auto separator = [[NSBox alloc] initWithFrame:NSZeroRect]; separator.boxType = NSBoxSeparator; result->impl_->view = separator; return result; }
std::shared_ptr<NativeView> NativeView::spinner() { auto result = std::shared_ptr<NativeView>(new NativeView()); auto spinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect]; spinner.style = NSProgressIndicatorStyleSpinning; spinner.indeterminate = YES; [spinner startAnimation:nil]; result->impl_->view = spinner; return result; }
std::shared_ptr<NativeView> NativeView::switchControl(bool checked) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto control = [[NSSwitch alloc] initWithFrame:NSZeroRect]; control.state = checked ? NSControlStateValueOn : NSControlStateValueOff; result->impl_->view = control; return result; }
std::shared_ptr<NativeView> NativeView::textArea(const std::string& value) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect]; scroll.hasVerticalScroller = YES; scroll.autohidesScrollers = YES; scroll.borderType = NSBezelBorder; auto text = [[NSTextView alloc] initWithFrame:NSZeroRect]; text.string = ns(value); text.verticallyResizable = YES; text.horizontallyResizable = NO; text.autoresizingMask = NSViewWidthSizable; text.textContainer.widthTracksTextView = YES; scroll.documentView = text; result->impl_->textView = text; result->impl_->view = scroll; return result; }
std::shared_ptr<NativeView> NativeView::radioGroup(const std::shared_ptr<std::vector<std::string>>& options, const std::string& selected) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto stack = [[NSStackView alloc] initWithFrame:NSZeroRect]; stack.orientation = NSUserInterfaceLayoutOrientationVertical; stack.alignment = NSLayoutAttributeLeading; stack.spacing = 4.0; for (const auto& option : *options) { auto button = [NSButton radioButtonWithTitle:ns(option) target:nil action:nil]; button.state = option == selected ? NSControlStateValueOn : NSControlStateValueOff; [stack addArrangedSubview:button]; } result->impl_->radioGroup = stack; result->impl_->view = stack; return result; }
std::shared_ptr<NativeView> NativeView::comboBox(const std::shared_ptr<std::vector<std::string>>& options, const std::string& value) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto combo = [[NSComboBox alloc] initWithFrame:NSZeroRect]; for (const auto& option : *options) [combo addItemWithObjectValue:ns(option)]; combo.stringValue = ns(value); result->impl_->view = combo; return result; }
std::shared_ptr<NativeView> NativeView::datePicker(const std::string& value) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto picker = [[NSDatePicker alloc] initWithFrame:NSZeroRect]; picker.datePickerElements = NSYearMonthDayDatePickerElementFlag; picker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper; picker.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; NSDate* date = dateFromISO(value); if (date) picker.dateValue = date; result->impl_->view = picker; return result; }
std::shared_ptr<NativeView> NativeView::colorWell(double red, double green, double blue, double alpha) { auto result = std::shared_ptr<NativeView>(new NativeView()); auto well = [[NSColorWell alloc] initWithFrame:NSZeroRect]; well.color = colorFromRGBA(red, green, blue, alpha); result->impl_->view = well; return result; }
std::shared_ptr<NativeView> NativeView::table(const std::shared_ptr<std::vector<std::string>>& columnIds, const std::shared_ptr<std::vector<std::string>>& columnTitles, const std::shared_ptr<std::vector<double>>& columnWidths, const std::shared_ptr<std::vector<bool>>& columnSortable) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    auto scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    auto table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    table.usesAlternatingRowBackgroundColors = YES;
    table.allowsColumnReordering = YES;
    table.allowsColumnResizing = YES;
    table.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    for (size_t index = 0; index < columnIds->size(); ++index) {
        auto column = [[NSTableColumn alloc] initWithIdentifier:ns((*columnIds)[index])];
        column.title = ns((*columnTitles)[index]);
        if (index < columnWidths->size() && (*columnWidths)[index] > 0.0) column.width = (*columnWidths)[index];
        if (index < columnSortable->size() && (*columnSortable)[index]) {
            column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:column.identifier ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        }
        [table addTableColumn:column];
    }
    auto adapter = [DoofTableAdapter new];
    adapter.tableView = table;
    adapter->_columnIds = *columnIds;
    table.dataSource = adapter;
    table.delegate = adapter;
    scroll.documentView = table;
    result->impl_->scroll = scroll;
    result->impl_->table = table;
    result->impl_->tableAdapter = adapter;
    result->impl_->view = scroll;
    return result;
}

std::shared_ptr<NativeView> NativeView::imageCanvas() {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    auto scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = [NSColor colorWithWhite:0.12 alpha:1.0];
    scroll.allowsMagnification = YES;
    scroll.minMagnification = 0.05;
    scroll.maxMagnification = 16.0;
    auto canvas = [[DoofImageCanvasView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
    [canvas registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    canvas.accessibilityLabel = @"Editable image";
    scroll.documentView = canvas;
    result->impl_->scroll = scroll;
    result->impl_->imageCanvas = canvas;
    result->impl_->view = scroll;
    return result;
}

void NativeView::append(std::shared_ptr<NativeView> child) {
    if (impl_->groupBox) {
        [impl_->groupBox.contentView addSubview:child->impl_->view];
    } else if (impl_->scroll) {
        impl_->scroll.documentView = child->impl_->view;
    } else if (impl_->split) {
        DoofFlippedView* pane = [[DoofFlippedView alloc] initWithFrame:NSZeroRect];
        [pane addSubview:child->impl_->view];
        [impl_->split addSubview:pane];
    } else {
        [impl_->view addSubview:child->impl_->view];
    }
    impl_->children.push_back(std::move(child));
}
void NativeView::insertBefore(std::shared_ptr<NativeView> child, std::shared_ptr<NativeView> reference) {
    auto found = std::find(impl_->children.begin(), impl_->children.end(), reference);
    if (found == impl_->children.end()) { append(std::move(child)); return; }
    if (impl_->split) {
        NSUInteger index = static_cast<NSUInteger>(std::distance(impl_->children.begin(), found));
        NSView* referencePane = impl_->split.subviews[index];
        DoofFlippedView* pane = [[DoofFlippedView alloc] initWithFrame:NSZeroRect];
        [pane addSubview:child->impl_->view];
        [impl_->split addSubview:pane positioned:NSWindowBelow relativeTo:referencePane];
    } else {
        [(impl_->groupBox ? impl_->groupBox.contentView : impl_->view) addSubview:child->impl_->view positioned:NSWindowBelow relativeTo:reference->impl_->view];
    }
    impl_->children.insert(found, std::move(child));
}
void NativeView::replace(std::shared_ptr<NativeView> child, std::shared_ptr<NativeView> target) {
    auto found = std::find(impl_->children.begin(), impl_->children.end(), target);
    if (found == impl_->children.end()) { append(std::move(child)); target->detach(); return; }
    if (impl_->split) {
        NSUInteger index = static_cast<NSUInteger>(std::distance(impl_->children.begin(), found));
        [impl_->split.subviews[index] replaceSubview:target->impl_->view with:child->impl_->view];
    } else {
        [(impl_->groupBox ? impl_->groupBox.contentView : impl_->view) replaceSubview:target->impl_->view with:child->impl_->view];
    }
    *found = std::move(child);
}
void NativeView::detach() { [impl_->view removeFromSuperview]; }
void NativeView::dispose() {
    if (impl_->disposed) return;
    impl_->disposed = true;
    if (impl_->sourceAdapter) {
        impl_->sourceAdapter.toggle = {};
        impl_->sourceAdapter.table.delegate = nil;
        impl_->sourceAdapter.table.dataSource = nil;
        impl_->sourceAdapter.table.target = nil;
    }
    if (impl_->outline) {
        impl_->outline.delegate = nil;
        impl_->outline.dataSource = nil;
        impl_->outlineAdapter.label = {};
        impl_->outlineAdapter.selection = {};
    }
    if (impl_->tabs) {
        impl_->tabs.delegate = nil;
        impl_->tabs.selectionAction = {};
        impl_->tabs.pageLayout = {};
    }
    if (impl_->split) {
        impl_->split.delegate = nil;
        impl_->split.callback = {};
    }
    for (auto& child : impl_->children) child->dispose();
    impl_->children.clear();
    [impl_->view removeFromSuperview];
    impl_->target = nil;
}
void NativeView::setFrame(double x, double y, double width, double height) {
    impl_->view.frame = groupBoxChildFrame(impl_->view, NSMakeRect(x, y, std::max(0.0, width), std::max(0.0, height)));
    if (impl_->split && !impl_->splitSized && impl_->split.subviews.count > 1 && width > 200 && height > 80) {
        // Seed every pane before asking NSSplitView to constrain dividers. Moving
        // dividers while all sibling frames are zero can collapse outer panes.
        impl_->splitSized = true;
        NSUInteger count = impl_->split.subviews.count;
        double divider = impl_->split.dividerThickness;
        double extent = impl_->split.vertical ? width : height;
        double available = std::max(0.0, extent - divider * (count - 1));
        double total = 0;
        for (NSUInteger i = 0; i < count; ++i) total += impl_->split.weights.count == count ? impl_->split.weights[i].doubleValue : 1;
        double origin = 0;
        for (NSUInteger i = 0; i < count; ++i) {
            double weight = impl_->split.weights.count == count ? impl_->split.weights[i].doubleValue : 1;
            double size = available * weight / total;
            impl_->split.subviews[i].frame = impl_->split.vertical
                ? NSMakeRect(origin, 0, size, height) : NSMakeRect(0, origin, width, size);
            origin += size + divider;
        }
        [impl_->split adjustSubviews];
    }
    [impl_->view setNeedsLayout:YES];
    [impl_->view layoutSubtreeIfNeeded];
}

void NativeView::setDocumentSize(double width, double height) { if (impl_->scroll && impl_->scroll.documentView) impl_->scroll.documentView.frame = NSMakeRect(0, 0, std::max(0.0, width), std::max(0.0, height)); }
static NSSize measuredSize(NSView* view, const std::optional<double>& maxWidth, const std::optional<double>& maxHeight) { NSSize size = view.fittingSize; if (maxWidth) size.width = std::min(size.width, *maxWidth); if (maxHeight) size.height = std::min(size.height, *maxHeight); return size; }
double NativeView::measureWidth(const std::optional<double>& maxWidth, const std::optional<double>& maxHeight) { return measuredSize(impl_->view, maxWidth, maxHeight).width; }
double NativeView::measureHeight(const std::optional<double>& maxWidth, const std::optional<double>& maxHeight) { return measuredSize(impl_->view, maxWidth, maxHeight).height; }
void NativeView::setText(const std::string& value) { if (impl_->groupBox) impl_->groupBox.title = ns(value); else if (impl_->textView) impl_->textView.string = ns(value); else if ([impl_->view isKindOfClass:NSButton.class]) [(NSButton*)impl_->view setTitle:ns(value)]; else if ([impl_->view respondsToSelector:@selector(setStringValue:)]) [(id)impl_->view setStringValue:ns(value)]; [impl_->view invalidateIntrinsicContentSize]; }
void NativeView::setEnabled(bool value) { if (impl_->textView) impl_->textView.editable = value; else if (impl_->radioGroup) for (NSButton* button in impl_->radioGroup.arrangedSubviews) button.enabled = value; else if ([impl_->view respondsToSelector:@selector(setEnabled:)]) [(id)impl_->view setEnabled:value]; }
void NativeView::setHidden(bool value) { impl_->view.hidden = value; }
void NativeView::setChecked(bool value) { if ([impl_->view respondsToSelector:@selector(setState:)]) [(id)impl_->view setState:value ? NSControlStateValueOn : NSControlStateValueOff]; }
void NativeView::setSelectedValue(const std::string& value) { if ([impl_->view isKindOfClass:NSPopUpButton.class]) [(NSPopUpButton*)impl_->view selectItemWithTitle:ns(value)]; else if (impl_->radioGroup) for (NSButton* button in impl_->radioGroup.arrangedSubviews) button.state = [button.title isEqualToString:ns(value)] ? NSControlStateValueOn : NSControlStateValueOff; }
void NativeView::setValue(double value) { if ([impl_->view respondsToSelector:@selector(setDoubleValue:)]) [(id)impl_->view setDoubleValue:value]; }
void NativeView::setSelectedIndex(int32_t value) { if ([impl_->view isKindOfClass:NSSegmentedControl.class]) [(NSSegmentedControl*)impl_->view setSelectedSegment:value]; }
void NativeView::setDate(const std::string& value) { if ([impl_->view isKindOfClass:NSDatePicker.class]) { NSDate* date = dateFromISO(value); if (date) [(NSDatePicker*)impl_->view setDateValue:date]; } }
void NativeView::setColor(double red, double green, double blue, double alpha) { if ([impl_->view isKindOfClass:NSColorWell.class]) [(NSColorWell*)impl_->view setColor:colorFromRGBA(red, green, blue, alpha)]; }
void NativeView::setAction(doof::callback<void(std::string, bool)> handler) { if (impl_->textView) { auto target = [DoofTextViewTarget new]; target.callback = std::move(handler); impl_->target = target; impl_->textView.delegate = target; return; } auto target = [DoofTarget new]; target.callback = std::move(handler); impl_->target = target; if (impl_->radioGroup) { for (NSButton* button in impl_->radioGroup.arrangedSubviews) { button.target = target; button.action = @selector(activate:); } return; } if ([impl_->view isKindOfClass:NSTextField.class]) { [(NSTextField*)impl_->view setDelegate:target]; return; } if ([impl_->view respondsToSelector:@selector(setTarget:)]) [(id)impl_->view setTarget:target]; if ([impl_->view respondsToSelector:@selector(setAction:)]) [(id)impl_->view setAction:@selector(activate:)]; }
void NativeView::setValueAction(doof::callback<void(double)> handler) { auto target = [DoofValueTarget new]; target.callback = std::move(handler); impl_->target = target; if ([impl_->view respondsToSelector:@selector(setTarget:)]) [(id)impl_->view setTarget:target]; if ([impl_->view respondsToSelector:@selector(setAction:)]) [(id)impl_->view setAction:@selector(activate:)]; }
void NativeView::setIndexAction(doof::callback<void(int32_t)> handler) { auto target = [DoofIndexTarget new]; target.callback = std::move(handler); impl_->target = target; if ([impl_->view respondsToSelector:@selector(setTarget:)]) [(id)impl_->view setTarget:target]; if ([impl_->view respondsToSelector:@selector(setAction:)]) [(id)impl_->view setAction:@selector(activate:)]; }
void NativeView::setColorAction(doof::callback<void(double, double, double, double)> handler) { auto target = [DoofColorTarget new]; target.callback = std::move(handler); impl_->target = target; if ([impl_->view respondsToSelector:@selector(setTarget:)]) [(id)impl_->view setTarget:target]; if ([impl_->view respondsToSelector:@selector(setAction:)]) [(id)impl_->view setAction:@selector(activate:)]; }
void NativeView::setAccessibility(const std::string& label, const std::string& help, const std::string& identifier) { NSView* view = impl_->outline ? impl_->outline : (impl_->textView ? impl_->textView : impl_->view); if (!label.empty()) view.accessibilityLabel = ns(label); if (!help.empty()) view.accessibilityHelp = ns(help); if (!identifier.empty()) view.accessibilityIdentifier = ns(identifier); }
void NativeView::setTitleElement(std::shared_ptr<NativeView> label) { (impl_->textView ? impl_->textView : impl_->view).accessibilityTitleUIElement = label->impl_->view; }
void NativeView::setPaneLayoutHandler(doof::callback<void(int32_t, double, double)> handler) { if (impl_->split && !impl_->disposed) impl_->split.callback = std::move(handler); }
void NativeView::setTableData(doof::callback<int32_t()> rowCount, doof::callback<std::string(int32_t)> rowKey, doof::callback<int32_t(int32_t)> columnKind, doof::callback<bool(int32_t)> columnEditable, doof::callback<std::string(int32_t, int32_t)> textValue, doof::callback<bool(int32_t, int32_t)> boolValue, doof::callback<double(int32_t, int32_t)> numberValue, doof::callback<void(int32_t, int32_t, std::string)> textChanged, doof::callback<void(int32_t, int32_t, bool)> boolChanged, doof::callback<void(int32_t, int32_t, double)> numberChanged, doof::callback<void(int32_t, int32_t, std::string)> dateChanged) {
    if (!impl_->tableAdapter) return;
    impl_->tableAdapter.rowCount = std::move(rowCount);
    impl_->tableAdapter.rowKey = std::move(rowKey);
    impl_->tableAdapter.columnKind = std::move(columnKind);
    impl_->tableAdapter.columnEditable = std::move(columnEditable);
    impl_->tableAdapter.textValue = std::move(textValue);
    impl_->tableAdapter.boolValue = std::move(boolValue);
    impl_->tableAdapter.numberValue = std::move(numberValue);
    impl_->tableAdapter.textChanged = std::move(textChanged);
    impl_->tableAdapter.boolChanged = std::move(boolChanged);
    impl_->tableAdapter.numberChanged = std::move(numberChanged);
    impl_->tableAdapter.dateChanged = std::move(dateChanged);
}
void NativeView::reloadTable() {
    if (!impl_->table || !impl_->tableAdapter) return;
    [impl_->tableAdapter reloadResetRows:YES];
}
void NativeView::setCanvasImage(const std::shared_ptr<std::vector<uint8_t>>& encodedImage) {
    if (!impl_->imageCanvas || !encodedImage || encodedImage->empty()) return;
    NSData* data = [NSData dataWithBytes:encodedImage->data() length:encodedImage->size()];
    NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:data];
    if (!bitmap) return;
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(bitmap.pixelsWide, bitmap.pixelsHigh)];
    [image addRepresentation:bitmap];
    impl_->imageCanvas.image = image;
    impl_->imageCanvas.frame = NSMakeRect(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh);
    [impl_->imageCanvas setNeedsDisplay:YES];
}
void NativeView::setCanvasBackground(int32_t background) {
    if (!impl_->imageCanvas || background < 0 || background > 2) return;
    impl_->imageCanvas.backgroundMode = background;
    [impl_->imageCanvas setNeedsDisplay:YES];
}
void NativeView::setCanvasClickAction(doof::callback<void(double, double)> handler) {
    if (impl_->imageCanvas) impl_->imageCanvas.clickCallback = std::move(handler);
}
void NativeView::setCanvasDropAction(doof::callback<void(std::shared_ptr<std::vector<std::string>>)> handler) {
    if (impl_->imageCanvas) impl_->imageCanvas.dropCallback = std::move(handler);
}
void NativeView::zoomCanvas(double factor) {
    if (!impl_->scroll || !impl_->imageCanvas) return;
    double next = std::clamp(impl_->scroll.magnification * factor, impl_->scroll.minMagnification, impl_->scroll.maxMagnification);
    [impl_->scroll setMagnification:next centeredAtPoint:NSMakePoint(NSMidX(impl_->imageCanvas.bounds), NSMidY(impl_->imageCanvas.bounds))];
}
void NativeView::actualSizeCanvas() {
    if (impl_->scroll && impl_->imageCanvas) [impl_->scroll setMagnification:1.0 centeredAtPoint:NSMakePoint(NSMidX(impl_->imageCanvas.bounds), NSMidY(impl_->imageCanvas.bounds))];
}
void NativeView::fitCanvas() {
    if (!impl_->scroll || !impl_->imageCanvas || NSIsEmptyRect(impl_->imageCanvas.bounds)) return;
    NSSize viewport = impl_->scroll.contentView.bounds.size;
    NSSize image = impl_->imageCanvas.bounds.size;
    if (viewport.width <= 0.0 || viewport.height <= 0.0) return;
    double fit = std::min(viewport.width / image.width, viewport.height / image.height);
    [impl_->scroll setMagnification:std::clamp(fit, impl_->scroll.minMagnification, impl_->scroll.maxMagnification) centeredAtPoint:NSMakePoint(image.width * 0.5, image.height * 0.5)];
}

struct NativeWindow::Impl {
    NSWindow* window = nil;
    DoofWindowDelegate* delegate = nil;
    DoofLayoutHostView* host = nil;
    NSWindow* sheet = nil;
    DoofLayoutHostView* sheetHost = nil;
    std::shared_ptr<NativeView> sheetContent;
    std::vector<DoofSheetButtonTarget*> sheetTargets;
    NSToolbar* toolbar = nil;
    DoofToolbarDelegate* toolbarDelegate = nil;
};
NativeWindow::NativeWindow() : impl_(std::make_shared<Impl>()) {}
NativeWindow::~NativeWindow() = default;
std::shared_ptr<NativeWindow> NativeWindow::create(const std::string& title, int32_t width, int32_t height, bool resizable) { auto result = std::shared_ptr<NativeWindow>(new NativeWindow()); NSWindowStyleMask mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable; if (resizable) mask |= NSWindowStyleMaskResizable; result->impl_->window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:mask backing:NSBackingStoreBuffered defer:NO]; result->impl_->window.releasedWhenClosed = NO; result->impl_->window.title = ns(title); result->impl_->host = [[DoofLayoutHostView alloc] initWithFrame:NSMakeRect(0, 0, width, height)]; result->impl_->window.contentView = result->impl_->host; result->impl_->delegate = [DoofWindowDelegate new]; result->impl_->window.delegate = result->impl_->delegate; return result; }
void NativeWindow::setRoot(std::shared_ptr<NativeView> view) { [impl_->host addSubview:view->impl_->view]; }
void NativeWindow::setLayoutHandler(doof::callback<void(double, double)> handler) { impl_->host.callback = std::move(handler); }
void NativeWindow::setToolbar(
    const std::shared_ptr<std::vector<std::string>>& ids,
    const std::shared_ptr<std::vector<std::string>>& labels,
    const std::shared_ptr<std::vector<std::string>>& symbols,
    const std::shared_ptr<std::vector<std::string>>& toolTips,
    const std::shared_ptr<std::vector<int32_t>>& kinds,
    const std::shared_ptr<std::vector<bool>>& enabled,
    const std::shared_ptr<std::vector<doof::callback<void(std::string, bool)>>>& handlers,
    int32_t displayMode,
    bool allowsCustomization
) {
    DoofToolbarDelegate* delegate = [DoofToolbarDelegate new];
    NSMutableArray<NSString*>* identifiers = [NSMutableArray arrayWithCapacity:ids->size()];
    NSMutableArray<NSString*>* nativeLabels = [NSMutableArray arrayWithCapacity:ids->size()];
    NSMutableArray<NSString*>* nativeSymbols = [NSMutableArray arrayWithCapacity:ids->size()];
    NSMutableArray<NSString*>* nativeToolTips = [NSMutableArray arrayWithCapacity:ids->size()];
    NSMutableArray<NSNumber*>* nativeKinds = [NSMutableArray arrayWithCapacity:ids->size()];
    NSMutableArray<NSNumber*>* nativeEnabled = [NSMutableArray arrayWithCapacity:ids->size()];
    NSMutableArray* items = [NSMutableArray arrayWithCapacity:ids->size()];
    for (size_t index = 0; index < ids->size(); ++index) {
        int32_t kind = index < kinds->size() ? (*kinds)[index] : 0;
        if (kind == 1) [identifiers addObject:NSToolbarSpaceItemIdentifier];
        else if (kind == 2) [identifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
        else [identifiers addObject:ns("doof.toolbar." + (*ids)[index])];
        [nativeLabels addObject:index < labels->size() ? ns((*labels)[index]) : @""];
        [nativeSymbols addObject:index < symbols->size() ? ns((*symbols)[index]) : @""];
        [nativeToolTips addObject:index < toolTips->size() ? ns((*toolTips)[index]) : @""];
        [nativeKinds addObject:@(kind)];
        [nativeEnabled addObject:@(index < enabled->size() ? (*enabled)[index] : true)];
        [items addObject:NSNull.null];
    }
    delegate.itemIdentifiers = identifiers;
    delegate.labels = nativeLabels;
    delegate.symbols = nativeSymbols;
    delegate.toolTips = nativeToolTips;
    delegate.kinds = nativeKinds;
    delegate.enabledItems = nativeEnabled;
    delegate.items = items;
    [delegate setHandlers:handlers];
    NSString* identifier = [NSString stringWithFormat:@"doof.toolbar.%p", impl_->window];
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:identifier];
    toolbar.delegate = delegate;
    toolbar.allowsUserCustomization = allowsCustomization;
    if (displayMode == 1) toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    else if (displayMode == 2) toolbar.displayMode = NSToolbarDisplayModeLabelOnly;
    else if (displayMode == 3) toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
    else toolbar.displayMode = NSToolbarDisplayModeDefault;
    impl_->toolbarDelegate = delegate;
    impl_->toolbar = toolbar;
    impl_->window.toolbar = toolbar;
}
void NativeWindow::setToolbarItemEnabled(int32_t index, bool enabled) {
    if (!impl_->toolbarDelegate || index < 0 || (NSUInteger)index >= impl_->toolbarDelegate.items.count) return;
    id item = impl_->toolbarDelegate.items[(NSUInteger)index];
    if ([item isKindOfClass:NSToolbarItem.class]) [(NSToolbarItem*)item setEnabled:enabled];
}
void NativeWindow::show() { bool firstShow = !impl_->delegate.counted; if (firstShow) { impl_->delegate.counted = true; shownWindows += 1; } [impl_->window makeKeyAndOrderFront:nil]; if (firstShow) [NSApplication.sharedApplication addWindowsItem:impl_->window title:impl_->window.title filename:NO]; [NSApplication.sharedApplication activateIgnoringOtherApps:YES]; [impl_->host setNeedsLayout:YES]; [impl_->host layoutSubtreeIfNeeded]; }
void NativeWindow::close() { [impl_->window close]; }
bool NativeWindow::isShown() { return impl_->delegate.counted; }
void NativeWindow::presentAlert(const std::string& title, const std::string& message, int32_t style, const std::shared_ptr<std::vector<std::string>>& buttonTitles, const std::shared_ptr<std::vector<bool>>& destructive, int32_t primaryIndex, int32_t cancelIndex, doof::callback<void(int32_t)> handler) {
    NSAlert* alert = createAlert(title, message, style, buttonTitles, destructive, primaryIndex, cancelIndex);
    auto completion = std::make_shared<doof::callback<void(int32_t)>>(std::move(handler));
    size_t buttonCount = buttonTitles->size();
    [alert beginSheetModalForWindow:impl_->window completionHandler:^(NSModalResponse response) {
        completion->call(alertResponseIndex(response, buttonCount));
    }];
}
void NativeWindow::presentSheet(const std::string& title, int32_t width, int32_t height, std::shared_ptr<NativeView> content, const std::shared_ptr<std::vector<std::string>>& buttonTitles, const std::shared_ptr<std::vector<bool>>& destructive, int32_t primaryIndex, int32_t cancelIndex, doof::callback<void(double, double)> layoutHandler, doof::callback<bool(int32_t)> validateHandler, doof::callback<void(int32_t)> completionHandler) {
    NSWindow* sheet = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    sheet.releasedWhenClosed = NO;
    sheet.title = ns(title);
    sheet.contentMinSize = NSMakeSize(width, height);

    NSView* chrome = [[NSView alloc] initWithFrame:NSZeroRect];
    DoofLayoutHostView* host = [[DoofLayoutHostView alloc] initWithFrame:NSZeroRect];
    host.callback = std::move(layoutHandler);
    host.translatesAutoresizingMaskIntoConstraints = NO;
    [host addSubview:content->impl_->view];
    [chrome addSubview:host];

    NSTextField* titleLabel = nil;
    if (!title.empty()) {
        titleLabel = [NSTextField labelWithString:ns(title)];
        titleLabel.font = [NSFont boldSystemFontOfSize:NSFont.systemFontSize];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [chrome addSubview:titleLabel];
    }

    NSStackView* actions = [[NSStackView alloc] initWithFrame:NSZeroRect];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.alignment = NSLayoutAttributeCenterY;
    actions.spacing = 8.0;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [chrome addSubview:actions];

    impl_->sheetTargets.clear();
    std::vector<NSButton*> buttons(buttonTitles->size(), nil);
    for (size_t reverseIndex = buttonTitles->size(); reverseIndex > 0; --reverseIndex) {
        size_t index = reverseIndex - 1;
        DoofSheetButtonTarget* target = [DoofSheetButtonTarget new];
        target.sheet = sheet;
        target.index = (int32_t)index;
        target.validate = validateHandler;
        impl_->sheetTargets.push_back(target);
        NSButton* button = [NSButton buttonWithTitle:ns((*buttonTitles)[index]) target:target action:@selector(activate:)];
        button.keyEquivalent = @"";
        button.keyEquivalentModifierMask = 0;
        if (index < destructive->size() && (*destructive)[index]) {
            if (@available(macOS 11.0, *)) button.hasDestructiveAction = YES;
        }
        buttons[index] = button;
        [actions addArrangedSubview:button];
    }
    if (primaryIndex >= 0 && (size_t)primaryIndex < buttons.size()) buttons[(size_t)primaryIndex].keyEquivalent = @"\r";
    if (cancelIndex >= 0 && (size_t)cancelIndex < buttons.size()) buttons[(size_t)cancelIndex].keyEquivalent = @"\033";

    NSMutableArray<NSLayoutConstraint*>* constraints = [NSMutableArray arrayWithArray:@[
        [host.leadingAnchor constraintEqualToAnchor:chrome.leadingAnchor],
        [host.trailingAnchor constraintEqualToAnchor:chrome.trailingAnchor],
        [host.bottomAnchor constraintEqualToAnchor:actions.topAnchor constant:-16.0],
        [actions.leadingAnchor constraintGreaterThanOrEqualToAnchor:chrome.leadingAnchor constant:20.0],
        [actions.trailingAnchor constraintEqualToAnchor:chrome.trailingAnchor constant:-20.0],
        [actions.bottomAnchor constraintEqualToAnchor:chrome.bottomAnchor constant:-20.0],
    ]];
    if (titleLabel) {
        [constraints addObjectsFromArray:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:chrome.leadingAnchor constant:20.0],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chrome.trailingAnchor constant:-20.0],
            [titleLabel.topAnchor constraintEqualToAnchor:chrome.topAnchor constant:20.0],
            [host.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        ]];
    } else {
        [constraints addObject:[host.topAnchor constraintEqualToAnchor:chrome.topAnchor]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    sheet.contentView = chrome;

    impl_->sheet = sheet;
    impl_->sheetHost = host;
    impl_->sheetContent = std::move(content);
    auto state = impl_;
    auto completion = std::make_shared<doof::callback<void(int32_t)>>(std::move(completionHandler));
    size_t buttonCount = buttonTitles->size();
    [impl_->window beginSheet:sheet completionHandler:^(NSModalResponse response) {
        int32_t index = alertResponseIndex(response, buttonCount);
        state->sheetTargets.clear();
        state->sheetContent.reset();
        state->sheetHost = nil;
        state->sheet = nil;
        completion->call(index);
    }];
}

struct NativeApplication::Impl {
    DoofAppDelegate* delegate = nil;
    std::vector<DoofTarget*> menuTargets;
    std::vector<NSMenuItem*> menuItems;
};
NativeApplication::NativeApplication() : impl_(std::make_shared<Impl>()) { NSApplication* app = NSApplication.sharedApplication; [app setActivationPolicy:NSApplicationActivationPolicyRegular]; impl_->delegate = [DoofAppDelegate new]; app.delegate = impl_->delegate; }
std::shared_ptr<NativeApplication> NativeApplication::shared() { static std::shared_ptr<NativeApplication> instance(new NativeApplication()); return instance; }
bool NativeApplication::isRunning() { return appRunning; }
bool NativeApplication::isMainThread() { return NSThread.isMainThread; }
int32_t NativeApplication::shownWindowCount() { return shownWindows; }
void NativeApplication::run(doof::callback<int32_t()> drain) { appDrain = std::move(drain); appRunning = true; appDrain.call(); [NSApplication.sharedApplication run]; appRunning = false; appDrain = {}; }
void NativeApplication::quit() {
    if (!appRunning) return;
    auto app = NSApplication.sharedApplication;
    [app stop:nil];
    // stop: takes effect after the current event finishes. Wake nextEvent when
    // quit was requested from a dispatched timer rather than a mouse/key event.
    [app postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
        location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil
        subtype:0 data1:0 data2:0] atStart:YES];
}
void NativeApplication::requestWake() { dispatch_async(dispatch_get_main_queue(), ^{ if (appRunning && appDrain) appDrain.call(); }); }
void NativeApplication::setOpenFilesHandler(doof::callback<void(std::shared_ptr<std::vector<std::string>>)> handler) {
    impl_->delegate->_openFilesHandler = std::move(handler);
    if (impl_->delegate->_pendingOpenFiles) {
        auto paths = std::move(impl_->delegate->_pendingOpenFiles);
        impl_->delegate->_pendingOpenFiles.reset();
        impl_->delegate->_openFilesHandler.call(paths);
    }
}
void NativeApplication::setMenu(
    const std::shared_ptr<std::vector<int32_t>>& nodeKinds,
    const std::shared_ptr<std::vector<int32_t>>& parentIndices,
    const std::shared_ptr<std::vector<int32_t>>& menuRoles,
    const std::shared_ptr<std::vector<int32_t>>& actions,
    const std::shared_ptr<std::vector<std::string>>& titles,
    const std::shared_ptr<std::vector<std::string>>& keys,
    const std::shared_ptr<std::vector<int32_t>>& modifierMasks,
    const std::shared_ptr<std::vector<bool>>& enabled,
    const std::shared_ptr<std::vector<bool>>& checked,
    const std::shared_ptr<std::vector<int32_t>>& handlerIndices,
    const std::shared_ptr<std::vector<doof::callback<void(std::string, bool)>>>& handlers
) {
    NSApplication* app = NSApplication.sharedApplication;
    impl_->menuTargets.clear();
    impl_->menuItems.assign(nodeKinds->size(), nil);
    app.servicesMenu = nil;
    app.windowsMenu = nil;
    app.helpMenu = nil;
    if (nodeKinds->empty()) {
        app.mainMenu = nil;
        return;
    }

    NSString* applicationName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (applicationName.length == 0) applicationName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
    if (applicationName.length == 0) applicationName = NSProcessInfo.processInfo.processName;
    if (applicationName.length == 0) applicationName = @"App";

    NSMenu* main = [[NSMenu alloc] initWithTitle:@""];
    NSMutableArray* nativeMenus = [NSMutableArray arrayWithCapacity:nodeKinds->size()];
    for (size_t index = 0; index < nodeKinds->size(); ++index) [nativeMenus addObject:NSNull.null];

    auto menuAt = [&](int32_t index) -> NSMenu* {
        if (index < 0 || (size_t)index >= nativeMenus.count) return nil;
        id value = nativeMenus[(NSUInteger)index];
        return [value isKindOfClass:NSMenu.class] ? (NSMenu*)value : nil;
    };
    // These values mirror ACTION_* in menu.do. They are semantic action IDs
    // carried by each prepared node, not the node's index. A nil target lets
    // AppKit route the selector through the responder chain and validate it for
    // the current text field, window, or application context.
    auto actionSelector = [](int32_t action) -> SEL {
        switch (action) {
            // Standard Application menu commands.
            case 1: return @selector(orderFrontStandardAboutPanel:);
            case 2: return @selector(hide:);
            case 3: return @selector(hideOtherApplications:);
            case 4: return @selector(unhideAllApplications:);
            case 5: return @selector(terminate:);
            // Standard Edit commands target the active control's responder.
            case 6: return @selector(undo:);
            case 7: return @selector(redo:);
            case 8: return @selector(cut:);
            case 9: return @selector(copy:);
            case 10: return @selector(paste:);
            case 11: return @selector(delete:);
            case 12: return @selector(selectAll:);
            // Standard View commands target the active window and its toolbar.
            case 13: return @selector(toggleToolbarShown:);
            case 14: return @selector(runToolbarCustomizationPalette:);
            case 15: return @selector(toggleFullScreen:);
            // Standard Window commands target or arrange application windows.
            case 16: return @selector(performMiniaturize:);
            case 17: return @selector(performZoom:);
            case 18: return @selector(arrangeInFront:);
            default: return nil;
        }
    };

    for (size_t index = 0; index < nodeKinds->size(); ++index) {
        int32_t kind = (*nodeKinds)[index];
        int32_t parentIndex = index < parentIndices->size() ? (*parentIndices)[index] : -1;
        int32_t role = index < menuRoles->size() ? (*menuRoles)[index] : 0;
        NSString* title = index < titles->size() ? ns((*titles)[index]) : @"";
        NSMenu* parent = menuAt(parentIndex);

        // Node kinds and menu roles mirror NODE_* and MENU_* in menu.do. Menu
        // roles are significant beyond presentation: assigning these properties
        // lets NSApplication manage Services, windows, and Help content.
        if (kind == 0) {
            if (role == 1) title = applicationName;
            NSMenu* menu = [[NSMenu alloc] initWithTitle:title];
            NSMenuItem* root = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
            root.submenu = menu;
            if (parent) [parent addItem:root];
            else [main addItem:root];
            nativeMenus[(NSUInteger)index] = menu;
            if (role == 2) app.servicesMenu = menu;
            else if (role == 3) app.windowsMenu = menu;
            else if (role == 4) app.helpMenu = menu;
            continue;
        }
        if (!parent) continue;
        if (kind == 2) {
            [parent addItem:NSMenuItem.separatorItem];
            continue;
        }

        int32_t action = index < actions->size() ? (*actions)[index] : 0;
        if (action == 1) title = [@"About " stringByAppendingString:applicationName];
        else if (action == 2) title = [@"Hide " stringByAppendingString:applicationName];
        else if (action == 5) title = [@"Quit " stringByAppendingString:applicationName];
        NSString* key = index < keys->size() ? ns((*keys)[index]) : @"";
        SEL selector = action == 0 ? @selector(activate:) : actionSelector(action);
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:key];
        // Modifier bits mirror modifierMask in menu.do: Command=1, Shift=2,
        // Option=4, and Control=8.
        int32_t mask = index < modifierMasks->size() ? (*modifierMasks)[index] : 0;
        NSEventModifierFlags nativeMask = 0;
        if (mask & 1) nativeMask |= NSEventModifierFlagCommand;
        if (mask & 2) nativeMask |= NSEventModifierFlagShift;
        if (mask & 4) nativeMask |= NSEventModifierFlagOption;
        if (mask & 8) nativeMask |= NSEventModifierFlagControl;
        item.keyEquivalentModifierMask = nativeMask;
        item.state = index < checked->size() && (*checked)[index] ? NSControlStateValueOn : NSControlStateValueOff;
        if (action == 0) {
            int32_t handlerIndex = index < handlerIndices->size() ? (*handlerIndices)[index] : -1;
            if (handlerIndex >= 0 && (size_t)handlerIndex < handlers->size()) {
                DoofTarget* target = [DoofTarget new];
                target.callback = (*handlers)[(size_t)handlerIndex];
                target.menuItemEnabled = index >= enabled->size() || (*enabled)[index];
                item.target = target;
                impl_->menuTargets.push_back(target);
            }
        }
        impl_->menuItems[index] = item;
        [parent addItem:item];
    }
    app.mainMenu = main;
    if (app.windowsMenu) {
        for (NSWindow* window in app.windows) {
            if (window.isVisible && !window.excludedFromWindowsMenu) [app addWindowsItem:window title:window.title filename:NO];
        }
    }
}
void NativeApplication::setMenuItemEnabled(int32_t index, bool enabled) {
    if (index < 0 || (size_t)index >= impl_->menuItems.size()) return;
    NSMenuItem* item = impl_->menuItems[(size_t)index];
    if (!item) return;
    item.enabled = enabled;
    if ([item.target isKindOfClass:DoofTarget.class]) [(DoofTarget*)item.target setMenuItemEnabled:enabled];
}
void NativeApplication::setMenuItemChecked(int32_t index, bool checked) {
    if (index < 0 || (size_t)index >= impl_->menuItems.size()) return;
    NSMenuItem* item = impl_->menuItems[(size_t)index];
    if (item) item.state = checked ? NSControlStateValueOn : NSControlStateValueOff;
}
std::string NativeApplication::menuSnapshot() {
    NSApplication* app = NSApplication.sharedApplication;
    // Synchronous recursion borrows the stack callable instead of retaining itself.
    std::function<void(NSMenu*, NSMutableArray*)> recursiveAppend;
    recursiveAppend = [&](NSMenu* menu, NSMutableArray* destination) {
        [menu update];
        for (NSMenuItem* item in menu.itemArray) {
            NSMutableDictionary* value = [NSMutableDictionary dictionary];
            value[@"title"] = item.title ?: @"";
            value[@"action"] = item.action ? NSStringFromSelector(item.action) : @"";
            value[@"key"] = item.keyEquivalent ?: @"";
            NSInteger mask = 0;
            if (item.keyEquivalentModifierMask & NSEventModifierFlagCommand) mask |= 1;
            if (item.keyEquivalentModifierMask & NSEventModifierFlagShift) mask |= 2;
            if (item.keyEquivalentModifierMask & NSEventModifierFlagOption) mask |= 4;
            if (item.keyEquivalentModifierMask & NSEventModifierFlagControl) mask |= 8;
            value[@"modifiers"] = @(mask);
            value[@"enabled"] = @(item.enabled);
            value[@"checked"] = @(item.state == NSControlStateValueOn);
            if (item.submenu) {
                NSString* role = @"menu";
                if (item.submenu == app.servicesMenu) role = @"services";
                else if (item.submenu == app.windowsMenu) role = @"window";
                else if (item.submenu == app.helpMenu) role = @"help";
                value[@"role"] = role;
                NSMutableArray* children = [NSMutableArray array];
                recursiveAppend(item.submenu, children);
                value[@"children"] = children;
            } else if (item.isSeparatorItem) {
                value[@"role"] = @"separator";
            } else {
                value[@"role"] = @"item";
            }
            [destination addObject:value];
        }
    };
    NSMutableArray* menus = [NSMutableArray array];
    NSMenu* main = app.mainMenu;
    for (NSUInteger index = 0; index < main.itemArray.count; ++index) {
        NSMenuItem* item = main.itemArray[index];
        NSMutableDictionary* value = [NSMutableDictionary dictionary];
        value[@"title"] = item.title ?: @"";
        NSString* role = index == 0 ? @"application" : @"menu";
        if (item.submenu == app.windowsMenu) role = @"window";
        else if (item.submenu == app.helpMenu) role = @"help";
        value[@"role"] = role;
        NSMutableArray* children = [NSMutableArray array];
        if (item.submenu) recursiveAppend(item.submenu, children);
        value[@"children"] = children;
        [menus addObject:value];
    }
    recursiveAppend = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:@{ @"menus": menus } options:0 error:nil];
    if (!data) return "{}";
    return utf8([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}
void NativeApplication::performMenuItem(int32_t index) {
    if (index < 0 || (size_t)index >= impl_->menuItems.size()) return;
    NSMenuItem* item = impl_->menuItems[(size_t)index];
    if (item && item.action) [NSApplication.sharedApplication sendAction:item.action to:item.target from:item];
}
int32_t NativeApplication::alert(const std::string& title, const std::string& message, int32_t style, const std::shared_ptr<std::vector<std::string>>& buttonTitles, const std::shared_ptr<std::vector<bool>>& destructive, int32_t primaryIndex, int32_t cancelIndex) {
    NSAlert* alert = createAlert(title, message, style, buttonTitles, destructive, primaryIndex, cancelIndex);
    return alertResponseIndex([alert runModal], buttonTitles->size());
}
std::shared_ptr<std::vector<std::string>> NativeApplication::openFile(const std::string& title, bool directories, bool multiple) { NSOpenPanel* panel = [NSOpenPanel openPanel]; panel.title = ns(title); panel.canChooseDirectories = directories; panel.canChooseFiles = !directories; panel.allowsMultipleSelection = multiple; auto result = std::make_shared<std::vector<std::string>>(); if ([panel runModal] != NSModalResponseOK) return result; for (NSURL* url in panel.URLs) result->push_back(utf8(url.path)); return result; }
std::optional<std::string> NativeApplication::saveFile(const std::string& title, const std::string& suggestedName) { NSSavePanel* panel = [NSSavePanel savePanel]; panel.title = ns(title); panel.nameFieldStringValue = ns(suggestedName); if ([panel runModal] != NSModalResponseOK) return std::nullopt; return utf8(panel.URL.path); }
void NativeView::setSplitPosition(int32_t index, double position) { if (impl_->split && !impl_->disposed) [impl_->split moveDivider:index toPosition:position]; }
void NativeView::setPaneWeights(const std::shared_ptr<std::vector<double>>& weights) {
    auto values = [NSMutableArray arrayWithCapacity:weights->size()];
    for (double weight : *weights) [values addObject:@(weight)];
    impl_->split.weights = values;
}
void NativeView::setTextStyle(double size, bool semibold, bool secondary) {
    if (![impl_->view isKindOfClass:NSTextField.class]) return;
    auto label = (NSTextField*)impl_->view;
    label.font = [NSFont systemFontOfSize:size weight:semibold ? NSFontWeightSemibold : NSFontWeightRegular];
    label.textColor = secondary ? NSColor.secondaryLabelColor : NSColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [label invalidateIntrinsicContentSize];
}

} // namespace doof_appkit
