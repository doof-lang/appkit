// Included inside namespace doof_appkit after NativeView::Impl is defined.
std::shared_ptr<NativeView> NativeView::outlineView() {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    auto scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    auto outline = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    outline.headerView = nil;
    outline.allowsMultipleSelection = NO;
    outline.allowsEmptySelection = YES;
    outline.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    auto column = [[NSTableColumn alloc] initWithIdentifier:@"outline"];
    column.editable = NO;
    [outline addTableColumn:column];
    outline.outlineTableColumn = column;
    auto adapter = [DoofOutlineAdapter new];
    adapter.outline = outline;
    adapter.roots = [NSMutableArray array];
    adapter.items = [NSMutableDictionary dictionary];
    outline.dataSource = adapter;
    outline.delegate = adapter;
    scroll.documentView = outline;
    result->impl_->scroll = scroll;
    result->impl_->outline = outline;
    result->impl_->outlineAdapter = adapter;
    result->impl_->view = scroll;
    return result;
}
void NativeView::setOutlineData(doof::callback<std::string(int32_t)> label,
    doof::callback<void(int32_t)> selection) {
    if (impl_->disposed) return;
    impl_->outlineAdapter.label = std::move(label);
    impl_->outlineAdapter.selection = std::move(selection);
}
void NativeView::reloadOutline(const std::shared_ptr<std::vector<std::string>>& keys,
    const std::shared_ptr<std::vector<int32_t>>& parents) {
    if (!impl_->disposed) reloadOutlineItems(impl_->outlineAdapter, *keys, *parents);
}
int32_t NativeView::outlineSelectedIndex() {
    if (impl_->disposed) return -1;
    DoofOutlineItem* item = [impl_->outline itemAtRow:impl_->outline.selectedRow];
    return item ? item.index : -1;
}
void NativeView::selectOutline(const std::string& key) {
    if (impl_->disposed) return;
    auto adapter = impl_->outlineAdapter;
    adapter.suppressSelection = YES;
    DoofOutlineItem* item = adapter.items[ns(key)];
    [adapter reveal:item];
    NSInteger row = item ? [impl_->outline rowForItem:item] : -1;
    if (row < 0) [impl_->outline deselectAll:nil];
    else {
        [impl_->outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [impl_->outline scrollRowToVisible:row];
    }
    adapter.suppressSelection = NO;
}
void NativeView::expandOutline(const std::string& key, bool recursive) {
    if (impl_->disposed) return;
    DoofOutlineItem* item = impl_->outlineAdapter.items[ns(key)];
    if (item) {
        [impl_->outlineAdapter reveal:item];
        [impl_->outline expandItem:item expandChildren:recursive];
    }
}
void NativeView::collapseOutline(const std::string& key, bool recursive) {
    if (impl_->disposed) return;
    DoofOutlineItem* item = impl_->outlineAdapter.items[ns(key)];
    if (item) [impl_->outline collapseItem:item collapseChildren:recursive];
}
std::string NativeView::outlineSnapshot() { return snapshotOutline(impl_->outlineAdapter); }
// Test hook uses the ordinary native selection delegate path.
void NativeView::performOutlineSelection(int32_t row) {
    if (impl_->disposed) return;
    if (row < 0) [impl_->outline deselectAll:nil];
    else if (row < impl_->outline.numberOfRows)
        [impl_->outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}
