// Included inside namespace doof_appkit after NativeView::Impl is defined.
std::shared_ptr<NativeView> NativeView::tabView() {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    auto tabs = [[DoofTabView alloc] initWithFrame:NSMakeRect(0, 0, 10000, 10000)];
    tabs.tabViewType = NSTopTabsBezelBorder;
    tabs.delegate = tabs;
    result->impl_->tabs = tabs;
    result->impl_->view = tabs;
    return result;
}
void NativeView::addTab(const std::string& title, std::shared_ptr<NativeView> content) {
    if (impl_->disposed) return;
    auto item = [[NSTabViewItem alloc] initWithIdentifier:nil];
    item.label = ns(title);
    auto host = [[DoofFlippedView alloc] initWithFrame:NSZeroRect];
    [host addSubview:content->impl_->view];
    item.view = host;
    [impl_->tabs addTabViewItem:item];
    impl_->children.push_back(std::move(content));
}
void NativeView::setTabTitle(int32_t index, const std::string& title) {
    if (impl_->disposed || index < 0 || index >= impl_->tabs.numberOfTabViewItems) return;
    [impl_->tabs tabViewItemAtIndex:index].label = ns(title);
    [impl_->tabs setNeedsLayout:YES];
}
void NativeView::selectTab(int32_t index) {
    if (impl_->disposed || index < 0 || index >= impl_->tabs.numberOfTabViewItems) return;
    impl_->tabs.suppressAction = YES;
    [impl_->tabs selectTabViewItemAtIndex:index];
    impl_->tabs.suppressAction = NO;
    [impl_->tabs placeSelectedPage];
}
void NativeView::setTabAction(doof::callback<void(int32_t)> handler) {
    if (!impl_->disposed) impl_->tabs.selectionAction = std::move(handler);
}
void NativeView::setTabLayoutHandler(doof::callback<void(int32_t, double, double)> handler) {
    if (!impl_->disposed) impl_->tabs.pageLayout = std::move(handler);
}
std::shared_ptr<std::vector<double>> NativeView::tabMetrics() { return measureTabs(impl_->tabs); }
std::string NativeView::tabSnapshot() { return snapshotTabs(impl_->tabs); }
// Integration-test hook: exercise the same delegate path as a native tab click.
void NativeView::performTabSelection(int32_t index) {
    if (!impl_->disposed && index >= 0 && index < impl_->tabs.numberOfTabViewItems)
        [impl_->tabs selectTabViewItemAtIndex:index];
}
