// NSBox owns its title, border, content margins, and accessibility group.
// Doof owns child geometry in box-local, top-left-origin coordinates.
#pragma once

@interface DoofGroupBox : NSBox @end
@implementation DoofGroupBox
@end

static NSBox* makeGroupBox(NSString* title) {
    // A generous initial frame avoids clamping the content rect while measuring.
    NSBox* box = [[DoofGroupBox alloc] initWithFrame:NSMakeRect(0, 0, 10000, 10000)];
    box.boxType = NSBoxPrimary;
    box.titlePosition = NSAtTop;
    box.title = title;
    box.contentView = [[DoofFlippedView alloc] initWithFrame:NSZeroRect];
    return box;
}

static std::shared_ptr<std::vector<double>> measureGroupBox(NSBox* box) {
    // Measure a separate probe so a reactive title never resizes the live tree.
    // Read AppKit's content frame rather than baking in OS/font-specific insets.
    NSBox* probe = makeGroupBox(box.title);
    probe.titleFont = box.titleFont;
    NSRect content = probe.contentView.frame;
    // NSBox must retain its native bottom-left coordinate system. Overriding
    // isFlipped breaks AppKit's content-frame calculation (negative insets).
    double top = NSHeight(probe.bounds) - NSMaxY(content);
    double right = NSWidth(probe.bounds) - NSMaxX(content);
    double bottom = NSMinY(content);
    double left = NSMinX(content);
    double titleWidth = [probe.titleCell cellSize].width + left + right;
    return std::make_shared<std::vector<double>>(
        std::initializer_list<double>{top, right, bottom, left, titleWidth});
}

static NSRect groupBoxChildFrame(NSView* child, NSRect frame) {
    NSView* parent = child.superview;
    if ([parent.superview isKindOfClass:DoofGroupBox.class]) {
        NSBox* box = (NSBox*)parent.superview;
        if (box.contentView == parent) {
            // Layout includes the native insets; AppKit child frames are instead
            // relative to contentView. Converting avoids applying padding twice.
            frame.origin.y = NSHeight(box.bounds) - NSMaxY(frame);
            return [parent convertRect:frame fromView:box];
        }
    }
    return frame;
}

// Internal diagnostic used by integration tests to inspect actual native frames.
static std::string snapshotGroupBox(NSBox* box) {
    NSMutableArray* children = [NSMutableArray array];
    for (NSView* child in box.contentView.subviews) {
        NSRect frame = child.frame;
        [children addObject:@{
            @"x": @(frame.origin.x), @"y": @(frame.origin.y),
            @"width": @(frame.size.width), @"height": @(frame.size.height),
        }];
    }
    NSDictionary* snapshot = @{
        @"title": box.title, @"role": box.accessibilityRole ?: @"",
        @"label": box.accessibilityLabel ?: @"", @"hidden": @(box.hidden),
        @"contentWidth": @(box.contentView.bounds.size.width),
        @"contentHeight": @(box.contentView.bounds.size.height),
        @"flipped": @(box.contentView.isFlipped), @"children": children,
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
    return utf8([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
}
