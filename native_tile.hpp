// Tile: a large, native-behaving button for choosing between a few
// destinations (connections, templates, projects). It keeps NSButton's
// target/action, keyboard activation, and accessibility; only drawing and
// hover tracking are custom. Included by native_appkit.mm.

static NSColor* tintColor(int32_t tint) {
    switch (tint) {
        case 1: return NSColor.systemBlueColor;
        case 2: return NSColor.systemPurpleColor;
        case 3: return NSColor.systemOrangeColor;
        case 4: return NSColor.systemTealColor;
        case 5: return NSColor.systemGreenColor;
        case 6: return NSColor.systemRedColor;
        case 7: return NSColor.systemPinkColor;
        case 8: return NSColor.systemYellowColor;
        case 9: return NSColor.systemGrayColor;
        default: return NSColor.controlAccentColor;
    }
}

@interface DoofTileCell : NSButtonCell
@property(nonatomic, strong) NSColor* accent;
@property(nonatomic) BOOL hovered;
@end

@implementation DoofTileCell
- (NSSize)cellSize { return NSMakeSize(250, 104); }
- (void)drawWithFrame:(NSRect)frame inView:(NSView*)controlView {
    NSColor* accent = self.accent ?: NSColor.controlAccentColor;
    BOOL active = self.hovered || self.isHighlighted;
    NSRect bounds = NSInsetRect(frame, 1, 1);
    NSBezierPath* shape = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:12 yRadius:12];
    [NSColor.controlBackgroundColor setFill];
    [shape fill];
    if (active) {
        [[accent colorWithAlphaComponent:self.isHighlighted ? 0.14 : 0.06] setFill];
        [shape fill];
    }
    [(active ? [accent colorWithAlphaComponent:0.5] : [NSColor.separatorColor colorWithAlphaComponent:0.14]) setStroke];
    shape.lineWidth = 1;
    [shape stroke];

    NSRect badge = NSMakeRect(NSMinX(bounds) + 17, NSMidY(bounds) - 22, 44, 44);
    [[accent colorWithAlphaComponent:0.10] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:badge xRadius:10 yRadius:10] fill];
    [self.image drawInRect:NSInsetRect(badge, 10, 10) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
                  fraction:self.isEnabled ? 1 : 0.5 respectFlipped:YES hints:nil];

    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary* attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: self.isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor,
        NSParagraphStyleAttributeName: paragraph,
    };
    CGFloat textWidth = MAX(0, NSWidth(bounds) - 94);
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading;
    CGFloat height = MIN(NSHeight(bounds) - 28, ceil([self.title boundingRectWithSize:NSMakeSize(textWidth, CGFLOAT_MAX)
        options:options attributes:attributes].size.height));
    [self.title drawWithRect:NSMakeRect(NSMaxX(badge) + 14, NSMidY(bounds) - height / 2, textWidth, height)
                     options:options attributes:attributes];
}
// Let AppKit draw the standard focus ring around the tile's rounded shape.
- (NSRect)focusRingMaskBoundsForFrame:(NSRect)frame inView:(NSView*)controlView { return frame; }
- (void)drawFocusRingMaskWithFrame:(NSRect)frame inView:(NSView*)controlView {
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 1, 1) xRadius:12 yRadius:12] fill];
}
@end

@interface DoofTileButton : NSButton
@end

@implementation DoofTileButton
+ (Class)cellClass { return DoofTileCell.class; }
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.bordered = NO;
        self.buttonType = NSButtonTypeMomentaryPushIn;
    }
    return self;
}
- (void)updateTrackingAreas {
    for (NSTrackingArea* area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
    [super updateTrackingAreas];
}
- (void)setHovered:(BOOL)hovered {
    ((DoofTileCell*)self.cell).hovered = hovered;
    self.needsDisplay = YES;
}
- (void)mouseEntered:(NSEvent*)event { [self setHovered:YES]; }
- (void)mouseExited:(NSEvent*)event { [self setHovered:NO]; }
- (void)setTint:(int32_t)tint symbol:(NSString*)symbol {
    NSColor* color = tintColor(tint);
    ((DoofTileCell*)self.cell).accent = color;
    self.image = symbolImage(symbol, 22, NSFontWeightMedium, color);
    self.needsDisplay = YES;
}
@end
