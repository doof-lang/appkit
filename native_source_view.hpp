#pragma once
// Read-only source listing: breakpoint buttons are separate from text/selection.
@interface DoofBreakpointButton : NSButton
@property(nonatomic) BOOL marked;
@end
@implementation DoofBreakpointButton
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea* area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
}
- (void)mouseEntered:(NSEvent*)event { self.alphaValue = 1; }
- (void)mouseExited:(NSEvent*)event { self.alphaValue = self.marked ? 1 : 0.12; }
@end

@interface DoofSourceAdapter : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, weak) NSTableView* table;
@property(nonatomic, copy) NSArray<NSString*>* lines;
@property(nonatomic, copy) NSArray<NSAttributedString*>* highlighted;
@property(nonatomic, copy) NSArray<NSNumber*>* markers;
@property(nonatomic) int32_t currentLine;
@property(nonatomic) doof::callback<void(int32_t)> toggle;
- (void)toggleBreakpoint:(NSButton*)sender;
@end
@implementation DoofSourceAdapter
- (NSInteger)numberOfRowsInTableView:(NSTableView*)table { return self.lines.count; }
- (BOOL)tableView:(NSTableView*)table shouldSelectRow:(NSInteger)row { return NO; }
- (NSView*)tableView:(NSTableView*)table viewForTableColumn:(NSTableColumn*)column row:(NSInteger)row {
    NSInteger marker = row < self.markers.count ? self.markers[row].integerValue : 0;
    if ([column.identifier isEqualToString:@"breakpoint"]) {
        auto button = (DoofBreakpointButton*)[table makeViewWithIdentifier:column.identifier owner:nil];
        if (!button) {
            button = [[DoofBreakpointButton alloc] initWithFrame:NSMakeRect(0, 0, 22, 22)];
            button.identifier = column.identifier; button.bordered = NO; button.title = @"";
            button.imagePosition = NSImageOnly; button.target = self; button.action = @selector(toggleBreakpoint:);
        }
        button.tag = row + 1; button.marked = marker != 0;
        button.image = [NSImage imageWithSystemSymbolName:marker == 2 ? @"circle.fill" : @"circle" accessibilityDescription:nil];
        button.contentTintColor = marker ? NSColor.systemRedColor : NSColor.secondaryLabelColor;
        button.alphaValue = marker ? 1 : 0.12;
        button.toolTip = [NSString stringWithFormat:@"%@ breakpoint at line %ld", marker ? @"Remove" : @"Add", row + 1];
        button.accessibilityLabel = button.toolTip;
        return button;
    }
    NSTextField* cell = [table makeViewWithIdentifier:column.identifier owner:nil];
    if (!cell) {
        cell = [NSTextField labelWithString:@""];
        cell.identifier = column.identifier;
        cell.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
        cell.lineBreakMode = NSLineBreakByClipping;
        cell.selectable = NO;
    }
    BOOL gutter = [column.identifier isEqualToString:@"gutter"];
    if (!gutter && self.highlighted.count == self.lines.count) cell.attributedStringValue = self.highlighted[row];
    else cell.stringValue = gutter ? [NSString stringWithFormat:@"%ld", row + 1] : self.lines[row];
    if (gutter) { cell.textColor = NSColor.secondaryLabelColor; cell.alignment = NSTextAlignmentRight; }
    cell.drawsBackground = self.currentLine == row + 1;
    cell.backgroundColor = [NSColor.systemYellowColor colorWithAlphaComponent:0.18];
    cell.accessibilityLabel = gutter ? [NSString stringWithFormat:@"Line %ld", row + 1] : self.lines[row];
    return cell;
}
- (void)toggleBreakpoint:(NSButton*)sender {
    if (self.toggle) self.toggle.call((int32_t)sender.tag);
}
@end
