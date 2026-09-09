#pragma once

// NSTabView owns tab chrome and page frames. Each page is a flipped host;
// Doof lays out the retained content at (0, 0) inside that host exactly once.
@interface DoofTabView : NSTabView <NSTabViewDelegate>
@property(nonatomic) doof::callback<void(int32_t)> selectionAction;
@property(nonatomic) doof::callback<void(int32_t, double, double)> pageLayout;
@property(nonatomic) BOOL suppressAction;
@property(nonatomic) BOOL placingPage;
- (void)placeSelectedPage;
@end

@implementation DoofTabView
- (void)placeSelectedPage {
    if (self.placingPage || !self.pageLayout || !self.selectedTabViewItem) return;
    self.placingPage = YES;
    NSView* host = self.selectedTabViewItem.view;
    host.frame = self.contentRect;
    self.pageLayout.call((int32_t)[self indexOfTabViewItem:self.selectedTabViewItem],
        std::max(0.0, NSWidth(host.bounds)), std::max(0.0, NSHeight(host.bounds)));
    self.placingPage = NO;
}
- (void)layout { [super layout]; [self placeSelectedPage]; }
- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(NSTabViewItem*)item {
    [self placeSelectedPage];
    if (!self.suppressAction && self.selectionAction && item)
        self.selectionAction.call((int32_t)[self indexOfTabViewItem:item]);
}
@end

static std::shared_ptr<std::vector<double>> measureTabs(NSTabView* tabs) {
    NSTabView* probe = [[NSTabView alloc] initWithFrame:NSMakeRect(0, 0, 10000, 10000)];
    probe.tabViewType = tabs.tabViewType;
    probe.font = tabs.font;
    probe.controlSize = tabs.controlSize;
    for (NSTabViewItem* source in tabs.tabViewItems) {
        NSTabViewItem* item = [[NSTabViewItem alloc] initWithIdentifier:nil];
        item.label = source.label;
        [probe addTabViewItem:item];
    }
    NSRect content = probe.contentRect;
    NSSize minimum = probe.minimumSize;
    return std::make_shared<std::vector<double>>(std::initializer_list<double>{
        NSWidth(probe.bounds) - NSWidth(content), NSHeight(probe.bounds) - NSHeight(content),
        minimum.width, minimum.height,
    });
}

static std::string snapshotTabs(NSTabView* tabs) {
    NSMutableArray* items = [NSMutableArray array];
    for (NSTabViewItem* item in tabs.tabViewItems) {
        NSView* host = item.view;
        NSView* content = host.subviews.firstObject;
        [items addObject:@{
            @"title": item.label, @"attached": @(host.superview != nil),
            @"flipped": @(host.isFlipped), @"width": @(NSWidth(host.bounds)),
            @"height": @(NSHeight(host.bounds)),
            @"childX": @(NSMinX(content.frame)), @"childY": @(NSMinY(content.frame)),
            @"childWidth": @(NSWidth(content.frame)), @"childHeight": @(NSHeight(content.frame)),
        }];
    }
    NSDictionary* data = @{
        @"selectedIndex": @([tabs indexOfTabViewItem:tabs.selectedTabViewItem]),
        @"items": items, @"role": tabs.accessibilityRole ?: @"",
        @"label": tabs.accessibilityLabel ?: @"", @"hidden": @(tabs.hidden),
    };
    NSData* json = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    return utf8([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
}
