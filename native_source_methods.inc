std::shared_ptr<NativeView> NativeView::sourceView(doof::callback<void(int32_t)> toggle) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    auto scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES; scroll.hasHorizontalScroller = YES; scroll.autohidesScrollers = YES;
    auto table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    table.allowsEmptySelection = YES;
    table.headerView = nil; table.rowHeight = 22;
    table.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    for (NSString* name in @[@"breakpoint", @"gutter", @"source"]) {
        auto column = [[NSTableColumn alloc] initWithIdentifier:name];
        column.width = [name isEqualToString:@"breakpoint"] ? 22 : [name isEqualToString:@"gutter"] ? 40 : 500;
        if (![name isEqualToString:@"source"]) { column.minWidth = column.width; column.maxWidth = column.width; }
        [table addTableColumn:column];
    }
    auto adapter = [DoofSourceAdapter new];
    adapter.table = table; adapter.lines = @[]; adapter.markers = @[]; adapter.toggle = toggle;
    table.delegate = adapter; table.dataSource = adapter;
    scroll.documentView = table;
    result->impl_->sourceAdapter = adapter;
    result->impl_->view = scroll;
    return result;
}
void NativeView::setSourceLines(const std::shared_ptr<std::vector<std::string>>& lines,
    const std::shared_ptr<std::vector<int32_t>>& markers, int32_t currentLine, bool reveal) {
    auto adapter = impl_->sourceAdapter;
    if (!adapter || impl_->disposed) return;
    auto text = [NSMutableArray arrayWithCapacity:lines->size()];
    auto points = [NSMutableArray arrayWithCapacity:markers->size()];
    for (const auto& line : *lines) [text addObject:ns(line)];
    for (auto marker : *markers) [points addObject:@(marker)];
    double longest = 0;
    NSDictionary* attributes = @{NSFontAttributeName: [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]};
    for (NSString* line in text) longest = std::max(longest, (double)[line sizeWithAttributes:attributes].width);
    adapter.table.tableColumns[2].minWidth = std::max(100.0, longest + 24);
    adapter.table.tableColumns[2].width = std::max(longest + 24, (double)adapter.table.enclosingScrollView.contentSize.width - 62);
    if (![adapter.lines isEqualToArray:text]) adapter.highlighted = nil;
    adapter.lines = text; adapter.markers = points; adapter.currentLine = currentLine;
    [adapter.table reloadData];
    if (reveal && currentLine > 0 && currentLine <= (int32_t)lines->size())
        [adapter.table scrollRowToVisible:currentLine - 1];
}
int32_t NativeView::sourceLineCount() { return (int32_t)impl_->sourceAdapter.lines.count; }

void NativeView::setSourceHighlights(const std::shared_ptr<std::vector<int32_t>>& rows,
    const std::shared_ptr<std::vector<int32_t>>& starts, const std::shared_ptr<std::vector<int32_t>>& lengths,
    const std::shared_ptr<std::vector<int32_t>>& styles) {
    auto adapter = impl_->sourceAdapter;
    if (!adapter || impl_->disposed) return;
    auto result = [NSMutableArray arrayWithCapacity:adapter.lines.count];
    NSDictionary* base = @{NSFontAttributeName: [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular], NSForegroundColorAttributeName: NSColor.labelColor};
    for (NSString* line in adapter.lines) [result addObject:[[NSMutableAttributedString alloc] initWithString:line attributes:base]];
    NSArray<NSColor*>* colors = @[NSColor.labelColor, NSColor.systemPurpleColor, NSColor.systemRedColor,
        NSColor.systemBlueColor, NSColor.secondaryLabelColor, NSColor.systemTealColor, NSColor.systemBrownColor];
    size_t count = std::min({rows->size(), starts->size(), lengths->size(), styles->size()});
    for (size_t i = 0; i < count; ++i) {
        int row = (*rows)[i], start = (*starts)[i], length = (*lengths)[i], style = (*styles)[i];
        if (row < 0 || row >= (int)adapter.lines.count || start < 0 || length < 0 || style < 0 || style > 8) continue;
        std::string bytes = utf8(adapter.lines[row]);
        if ((size_t)start > bytes.size() || (size_t)length > bytes.size() - start) continue;
        // Compiler spans count UTF-8 bytes; AppKit attributes count UTF-16 units.
        NSString* prefix = [[NSString alloc] initWithBytes:bytes.data() length:start encoding:NSUTF8StringEncoding];
        NSString* token = [[NSString alloc] initWithBytes:bytes.data() + start length:length encoding:NSUTF8StringEncoding];
        if (!prefix || !token) continue;
        NSRange range = NSMakeRange(prefix.length, token.length);
        if (style == 7 || style == 8) {
            NSColor* color = style == 7 ? NSColor.systemRedColor : NSColor.systemOrangeColor;
            NSNumber* underline = @(NSUnderlineStyleSingle | NSUnderlinePatternDot);
            [(NSMutableAttributedString*)result[row] addAttribute:NSUnderlineStyleAttributeName value:underline range:range];
            [(NSMutableAttributedString*)result[row] addAttribute:NSUnderlineColorAttributeName value:color range:range];
        } else {
            [(NSMutableAttributedString*)result[row] addAttribute:NSForegroundColorAttributeName value:colors[style] range:range];
        }
    }
    adapter.highlighted = result;
    [adapter.table reloadData];
}
