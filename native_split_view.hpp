#pragma once
// Native split pane layout and continuous divider tracking.
@interface DoofSplitView : NSSplitView <NSSplitViewDelegate>
@property(nonatomic) BOOL hasPaneSizes;
@property(nonatomic, copy) NSArray<NSNumber*>* weights;
- (void)moveDivider:(NSInteger)index toPosition:(CGFloat)position;
@property(nonatomic) doof::callback<void(int32_t, double, double)> callback;
@end
@implementation DoofSplitView
- (BOOL)isFlipped { return YES; }
- (NSInteger)dividerAtPoint:(NSPoint)point {
    CGFloat coordinate = self.vertical ? point.x : point.y;
    for (NSUInteger i = 0; i + 1 < self.subviews.count; ++i) {
        NSRect frame = self.subviews[i].frame;
        CGFloat edge = self.vertical ? NSMaxX(frame) : NSMaxY(frame);
        if (coordinate >= edge - 4 && coordinate <= edge + self.dividerThickness + 4) return i;
    }
    return -1;
}
- (NSView*)hitTest:(NSPoint)point {
    NSPoint local = [self convertPoint:point fromView:self.superview];
    if (NSPointInRect(local, self.bounds) && [self dividerAtPoint:local] >= 0) return self;
    return [super hitTest:point];
}
- (void)resetCursorRects {
    [super resetCursorRects];
    for (NSUInteger i = 0; i + 1 < self.subviews.count; ++i) {
        NSRect frame = self.subviews[i].frame;
        NSRect handle = self.vertical ? NSMakeRect(NSMaxX(frame)-4, 0, self.dividerThickness+8, self.bounds.size.height)
            : NSMakeRect(0, NSMaxY(frame)-4, self.bounds.size.width, self.dividerThickness+8);
        [self addCursorRect:handle cursor:self.vertical ? NSCursor.resizeLeftRightCursor : NSCursor.resizeUpDownCursor];
    }
}
- (void)moveDivider:(NSInteger)index toPosition:(CGFloat)position {
    if (index < 0 || index + 1 >= (NSInteger)self.subviews.count) return;
    NSView* first = self.subviews[index]; NSView* second = self.subviews[index+1];
    NSRect a = first.frame, b = second.frame;
    CGFloat start = self.vertical ? NSMinX(a) : NSMinY(a);
    CGFloat end = self.vertical ? NSMaxX(b) : NSMaxY(b);
    CGFloat available = std::max((CGFloat)0, end - start - self.dividerThickness);
    CGFloat minimum = std::min((CGFloat)80, available / 2);
    CGFloat edge = std::clamp(position, start + minimum, end - self.dividerThickness - minimum);
    if (self.vertical) { a.size.width = edge-start; b.origin.x = edge+self.dividerThickness; b.size.width = end-b.origin.x; }
    else { a.size.height = edge-start; b.origin.y = edge+self.dividerThickness; b.size.height = end-b.origin.y; }
    first.frame = a; second.frame = b; self.hasPaneSizes = YES;
    // Deliver the Doof layout callback directly, including inside event tracking.
    [self layout];
    [self setNeedsDisplay:YES];
    [self.window displayIfNeeded];
    [self.window invalidateCursorRectsForView:self];
}
- (void)mouseDown:(NSEvent*)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger divider = [self dividerAtPoint:point];
    if (divider < 0) { [super mouseDown:event]; return; }
    NSRect first = self.subviews[divider].frame;
    CGFloat offset = (self.vertical ? point.x - NSMaxX(first) : point.y - NSMaxY(first));
    // NSSplitView's legacy tracking defers its divider commit to mouse-up when
    // manually sized panes bypass its constraint layout. Own this small tracking
    // loop so every dragged event commits frames and redraws their contents.
    while (true) {
        NSEvent* next = [self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp
            untilDate:NSDate.distantFuture inMode:NSEventTrackingRunLoopMode dequeue:YES];
        if (!next) break;
        NSPoint moved = [self convertPoint:next.locationInWindow fromView:nil];
        [self moveDivider:divider toPosition:(self.vertical ? moved.x : moved.y) - offset];
        if (next.type == NSEventTypeLeftMouseUp) break;
    }
}
- (void)splitViewDidResizeSubviews:(NSNotification*)notification {
    [self setNeedsLayout:YES];
    [self layoutSubtreeIfNeeded];
    [self.window displayIfNeeded];
}
- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSArray<NSView*>* panes = self.subviews;
    if (panes.count == 0) return;
    double extent = self.vertical ? self.bounds.size.width : self.bounds.size.height;
    double divider = self.dividerThickness;
    if (extent <= divider * (panes.count - 1)) return;
    double available = extent - divider * (panes.count - 1);
    double total = 0;
    for (NSView* pane in panes) total += self.vertical ? pane.frame.size.width : pane.frame.size.height;
    BOOL preserve = self.hasPaneSizes && total > 0;
    double origin = 0;
    for (NSUInteger index = 0; index < panes.count; ++index) {
        NSView* pane = panes[index];
        double old = self.vertical ? pane.frame.size.width : pane.frame.size.height;
        double size = preserve ? available * old / total : available / panes.count;
        if (index + 1 == panes.count) size = extent - origin;
        pane.frame = self.vertical ? NSMakeRect(origin, 0, size, self.bounds.size.height)
            : NSMakeRect(0, origin, self.bounds.size.width, size);
        origin += size + divider;
    }
    self.hasPaneSizes = YES;
}

- (void)layout {
    // Pane frames are managed by resizeSubviewsWithOldSize and divider drags.
    // NSSplitView's constraint layout conflicts with manually laid-out Doof views.
    if (!self.callback) return;
    int32_t index = 0;
    for (NSView* pane in self.subviews) {
        NSSize size = pane.bounds.size;
        self.callback.call(index++, size.width, size.height);
    }
}
@end
