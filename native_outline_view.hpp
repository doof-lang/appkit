#pragma once

@interface DoofOutlineItem : NSObject
@property(nonatomic, copy) NSString* key;
@property(nonatomic) int32_t index;
@property(nonatomic, strong) NSMutableArray<DoofOutlineItem*>* children;
@property(nonatomic, weak) DoofOutlineItem* parent;
@end
@implementation DoofOutlineItem @end

@interface DoofOutlineAdapter : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property(nonatomic, weak) NSOutlineView* outline;
@property(nonatomic, strong) NSMutableArray<DoofOutlineItem*>* roots;
@property(nonatomic, strong) NSMutableDictionary<NSString*, DoofOutlineItem*>* items;
@property(nonatomic) doof::callback<std::string(int32_t)> label;
@property(nonatomic) doof::callback<void(int32_t)> selection;
@property(nonatomic) BOOL suppressSelection;
- (void)reveal:(DoofOutlineItem*)item;
@end

@implementation DoofOutlineAdapter
- (NSInteger)outlineView:(NSOutlineView*)view numberOfChildrenOfItem:(DoofOutlineItem*)item {
    return item ? item.children.count : self.roots.count;
}
- (id)outlineView:(NSOutlineView*)view child:(NSInteger)index ofItem:(DoofOutlineItem*)item {
    return (item ? item.children : self.roots)[index];
}
- (BOOL)outlineView:(NSOutlineView*)view isItemExpandable:(DoofOutlineItem*)item {
    return item.children.count > 0;
}
- (id)outlineView:(NSOutlineView*)view objectValueForTableColumn:(NSTableColumn*)column byItem:(DoofOutlineItem*)item {
    return self.label ? ns(self.label.call(item.index)) : @"";
}
- (NSView*)outlineView:(NSOutlineView*)view viewForTableColumn:(NSTableColumn*)column item:(DoofOutlineItem*)item {
    NSTableCellView* cell = [view makeViewWithIdentifier:@"outline-label" owner:nil];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"outline-label";
        NSTextField* field = [NSTextField labelWithString:@""];
        field.translatesAutoresizingMaskIntoConstraints = NO;
        field.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:field];
        cell.textField = field;
        [NSLayoutConstraint activateConstraints:@[
            [field.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
            [field.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
            [field.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        ]];
    }
    cell.textField.stringValue = self.label ? ns(self.label.call(item.index)) : @"";
    return cell;
}
- (void)outlineViewSelectionDidChange:(NSNotification*)notification {
    if (self.suppressSelection || !self.selection) return;
    DoofOutlineItem* item = [self.outline itemAtRow:self.outline.selectedRow];
    self.selection.call(item ? item.index : -1);
}
- (void)reveal:(DoofOutlineItem*)item {
    if (!item.parent) return;
    [self reveal:item.parent];
    [self.outline expandItem:item.parent];
}
@end

// Capture stable keys before replacing the data source, then restore in preorder
// so expanded parents exist before their descendants are expanded.
static void reloadOutlineItems(DoofOutlineAdapter* adapter,
    const std::vector<std::string>& keys, const std::vector<int32_t>& parents) {
    NSOutlineView* outline = adapter.outline;
    DoofOutlineItem* selected = [outline itemAtRow:outline.selectedRow];
    NSString* selectedKey = selected.key;
    NSMutableSet<NSString*>* expanded = [NSMutableSet set];
    for (DoofOutlineItem* item in adapter.items.allValues)
        if ([outline isItemExpanded:item]) [expanded addObject:item.key];
    adapter.suppressSelection = YES;
    adapter.roots = [NSMutableArray array];
    adapter.items = [NSMutableDictionary dictionary];
    NSMutableArray<DoofOutlineItem*>* ordered = [NSMutableArray array];
    for (size_t index = 0; index < keys.size(); ++index) {
        auto item = [DoofOutlineItem new];
        item.key = ns(keys[index]);
        item.index = (int32_t)index;
        item.children = [NSMutableArray array];
        [ordered addObject:item];
        adapter.items[item.key] = item;
        if (parents[index] < 0) [adapter.roots addObject:item];
        else {
            item.parent = ordered[parents[index]];
            [item.parent.children addObject:item];
        }
    }
    [outline reloadData];
    for (DoofOutlineItem* item in ordered)
        if ([expanded containsObject:item.key]) [outline expandItem:item];
    DoofOutlineItem* restored = selectedKey ? adapter.items[selectedKey] : nil;
    if (restored) [adapter reveal:restored];
    NSInteger row = restored ? [outline rowForItem:restored] : -1;
    if (row >= 0) [outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    else [outline deselectAll:nil];
    adapter.suppressSelection = NO;
}

static std::string snapshotOutline(DoofOutlineAdapter* adapter) {
    NSOutlineView* outline = adapter.outline;
    NSMutableArray* rows = [NSMutableArray array];
    for (NSInteger row = 0; row < outline.numberOfRows; ++row) {
        DoofOutlineItem* item = [outline itemAtRow:row];
        [rows addObject:@{
            @"key": item.key, @"level": @([outline levelForItem:item]),
            @"expanded": @([outline isItemExpanded:item]),
            @"expandable": @(item.children.count > 0),
            @"label": adapter.label ? ns(adapter.label.call(item.index)) : @"",
        }];
    }
    DoofOutlineItem* selected = [outline itemAtRow:outline.selectedRow];
    NSDictionary* data = @{
        @"rows": rows, @"selectedKey": selected.key ?: @"",
        @"role": outline.accessibilityRole ?: @"",
        @"label": outline.accessibilityLabel ?: @"",
    };
    NSData* json = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    return utf8([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
}
