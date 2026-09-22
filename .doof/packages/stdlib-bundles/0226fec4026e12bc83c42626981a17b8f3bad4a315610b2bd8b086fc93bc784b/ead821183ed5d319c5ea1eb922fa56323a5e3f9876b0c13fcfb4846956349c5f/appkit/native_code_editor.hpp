#pragma once

static NSRange codeEditorUtf16Range(NSString* value, int32_t byteStart, int32_t byteLength) {
    std::string bytes = utf8(value);
    size_t start = std::min(bytes.size(), static_cast<size_t>(std::max(0, byteStart)));
    size_t length = std::min(bytes.size() - start, static_cast<size_t>(std::max(0, byteLength)));
    NSString* prefix = [[NSString alloc] initWithBytes:bytes.data() length:start encoding:NSUTF8StringEncoding];
    NSString* token = [[NSString alloc] initWithBytes:bytes.data() + start length:length encoding:NSUTF8StringEncoding];
    if (!prefix || !token) return NSMakeRange(NSNotFound, 0);
    return NSMakeRange(prefix.length, token.length);
}

static int32_t codeEditorByteLength(NSString* value, NSRange range) {
    if (range.location == NSNotFound || NSMaxRange(range) > value.length) return 0;
    return (int32_t)[[value substringWithRange:range] lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}

static NSDictionary<NSAttributedStringKey, id>* codeEditorBaseAttributes(double fontSize, int32_t tabWidth) {
    NSFont* font = [NSFont monospacedSystemFontOfSize:fontSize weight:NSFontWeightRegular];
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    NSString* spaces = [@"" stringByPaddingToLength:MAX(1, tabWidth) withString:@" " startingAtIndex:0];
    paragraph.defaultTabInterval = [spaces sizeWithAttributes:@{NSFontAttributeName: font}].width;
    paragraph.tabStops = @[];
    return @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: NSColor.textColor,
        NSParagraphStyleAttributeName: paragraph,
    };
}

@interface DoofCodeEditorTextView : NSTextView
@property(nonatomic) BOOL autoIndent;
@property(nonatomic) int32_t indentationWidth;
@property(nonatomic) doof::callback<std::string(int32_t)> completionProvider;
@property(nonatomic, strong) NSDictionary* completionSnapshot;
@property(nonatomic) NSUInteger completionGeneration;
@end

@implementation DoofCodeEditorTextView
#include "native_completion.inc"
// Replace the indentation and brace together so native undo treats them as one edit.
- (void)insertText:(id)text replacementRange:(NSRange)replacementRange {
    NSString* insertion = [text isKindOfClass:NSAttributedString.class] ? [text string] : text;
    NSRange selected = replacementRange.location == NSNotFound ? self.selectedRange : replacementRange;
    NSString* value = self.string ?: @"";
    if (self.autoIndent && [insertion isEqualToString:@"}"] && selected.length == 0 &&
        selected.location != NSNotFound && selected.location <= value.length) {
        NSRange line = [value lineRangeForRange:NSMakeRange(selected.location, 0)];
        NSUInteger start = line.location;
        while (start < selected.location) {
            unichar character = [value characterAtIndex:start];
            if (character != ' ' && character != '\t') break;
            start += 1;
        }
        if (start == selected.location && start > line.location) {
            NSUInteger removed = 0;
            while (start > line.location && removed < MAX(1, self.indentationWidth)) {
                unichar character = [value characterAtIndex:--start];
                removed += 1;
                if (character == '\t') break;
            }
            selected = NSMakeRange(start, selected.location - start);
        }
    }
    [super insertText:text replacementRange:selected];
    [self scheduleCompletion:insertion];
}
- (void)insertNewline:(id)sender {
    if (!self.autoIndent) {
        [super insertNewline:sender];
        return;
    }

    NSString* value = self.string ?: @"";
    NSRange selected = self.selectedRange;
    if (selected.location == NSNotFound || NSMaxRange(selected) > value.length) {
        [super insertNewline:sender];
        return;
    }

    NSRange line = [value lineRangeForRange:NSMakeRange(selected.location, 0)];
    NSString* prefix = [value substringWithRange:NSMakeRange(line.location, selected.location - line.location)];
    NSUInteger whitespaceLength = 0;
    while (whitespaceLength < prefix.length) {
        unichar character = [prefix characterAtIndex:whitespaceLength];
        if (character != ' ' && character != '\t') break;
        whitespaceLength += 1;
    }

    NSMutableString* insertion = [NSMutableString stringWithString:@"\n"];
    [insertion appendString:[prefix substringToIndex:whitespaceLength]];
    NSString* content = [prefix substringFromIndex:whitespaceLength];
    NSString* trimmed = [content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if ([trimmed hasSuffix:@"{"] || [trimmed hasSuffix:@"["] || [trimmed hasSuffix:@"("]) {
        [insertion appendString:[@"" stringByPaddingToLength:MAX(1, self.indentationWidth)
            withString:@" " startingAtIndex:0]];
    }
    [self insertText:insertion replacementRange:selected];
}
@end

@interface DoofCodeEditorRuler : NSRulerView
@property(nonatomic, weak) NSTextView* textView;
- (void)invalidateLineNumbers;
@end

@implementation DoofCodeEditorRuler
- (instancetype)initWithScrollView:(NSScrollView*)scroll textView:(NSTextView*)textView {
    self = [super initWithScrollView:scroll orientation:NSVerticalRuler];
    if (self) {
        _textView = textView;
        self.ruleThickness = 46.0;
        scroll.contentView.postsBoundsChangedNotifications = YES;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(redisplay:)
            name:NSViewBoundsDidChangeNotification object:scroll.contentView];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(redisplay:)
            name:NSTextDidChangeNotification object:textView];
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)isOpaque { return YES; }
- (void)redisplay:(NSNotification*)notification { [self invalidateLineNumbers]; }
- (void)invalidateLineNumbers {
    [self setNeedsDisplayInRect:self.bounds];
    // NSTextKit invalidates layout during textDidChange. Redraw once more after
    // that transaction settles so removed trailing line labels are erased.
    __weak DoofCodeEditorRuler* ruler = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [ruler setNeedsDisplayInRect:ruler.bounds];
    });
}
- (void)drawRect:(NSRect)rect {
    [NSColor.textBackgroundColor setFill];
    NSRectFill(NSMakeRect(NSMinX(self.bounds), NSMinY(rect), self.ruleThickness, NSHeight(rect)));
    NSTextView* textView = self.textView;
    NSLayoutManager* layout = textView.layoutManager;
    NSTextContainer* container = textView.textContainer;
    if (!textView || !layout || !container) return;
    NSString* text = textView.string ?: @"";
    NSDictionary* attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
    };
    [layout ensureLayoutForTextContainer:container];
    void (^drawNumber)(NSUInteger, NSRect) = ^(NSUInteger lineNumber, NSRect fragment) {
        NSPoint windowPoint = [textView convertPoint:NSMakePoint(0, NSMinY(fragment) + textView.textContainerInset.height) toView:nil];
        NSPoint rulerPoint = [self convertPoint:windowPoint fromView:nil];
        if (rulerPoint.y + 14.0 < NSMinY(rect) || rulerPoint.y > NSMaxY(rect)) return;
        NSString* label = [NSString stringWithFormat:@"%lu", (unsigned long)lineNumber];
        NSSize size = [label sizeWithAttributes:attributes];
        [label drawAtPoint:NSMakePoint(self.ruleThickness - size.width - 8.0, rulerPoint.y) withAttributes:attributes];
    };

    NSUInteger index = 0, lineNumber = 1;
    while (index < text.length) {
        NSRange lineRange = [text lineRangeForRange:NSMakeRange(index, 0)];
        NSUInteger glyph = index < text.length ? [layout glyphIndexForCharacterAtIndex:index] : layout.numberOfGlyphs;
        NSRect fragment = glyph < layout.numberOfGlyphs
            ? [layout lineFragmentRectForGlyphAtIndex:glyph effectiveRange:nullptr]
            : layout.extraLineFragmentRect;
        drawNumber(lineNumber, fragment);
        NSUInteger next = NSMaxRange(lineRange);
        if (next <= index) break;
        index = next;
        lineNumber += 1;
    }

    BOOL hasTrailingLine = text.length == 0 || [text hasSuffix:@"\n"] || [text hasSuffix:@"\r"];
    if (hasTrailingLine) {
        NSRect fragment = layout.extraLineFragmentRect;
        if (NSIsEmptyRect(fragment)) {
            NSRect used = [layout usedRectForTextContainer:container];
            fragment = NSMakeRect(0, NSMaxY(used), 0, [layout defaultLineHeightForFont:textView.font]);
        }
        drawNumber(lineNumber, fragment);
    }
}
@end

@interface DoofCodeEditorAdapter : NSObject <NSTextViewDelegate, NSViewToolTipOwner>
@property(nonatomic, weak) NSTextView* textView;
@property(nonatomic) doof::callback<void(std::string)> change;
@property(nonatomic) doof::callback<void(int32_t, int32_t)> selectionChange;
@property(nonatomic) doof::callback<std::string(int32_t)> hoverText;
@property(nonatomic) NSToolTipTag hoverToolTip;
@property(nonatomic) double fontSize;
@property(nonatomic) int32_t tabWidth;
@property(nonatomic) BOOL autoIndent;
@property(nonatomic) BOOL lineNumbers;
@property(nonatomic) BOOL wrapLines;
@end

static void layoutCodeEditorTextView(DoofCodeEditorAdapter* adapter);

@implementation DoofCodeEditorAdapter
- (void)textDidChange:(NSNotification*)notification {
    if (self.change) self.change.call(utf8(self.textView.string));
    layoutCodeEditorTextView(self);
    [(DoofCodeEditorRuler*)self.textView.enclosingScrollView.verticalRulerView invalidateLineNumbers];
}
- (void)textViewDidChangeSelection:(NSNotification*)notification {
    if (!self.selectionChange) return;
    NSString* value = self.textView.string;
    NSRange selected = self.textView.selectedRange;
    int32_t start = codeEditorByteLength(value, NSMakeRange(0, selected.location));
    int32_t length = codeEditorByteLength(value, selected);
    self.selectionChange.call(start, length);
}
- (NSString*)view:(NSView*)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void*)data {
    NSTextView* text = self.textView;
    NSLayoutManager* layout = text.layoutManager;
    NSTextContainer* container = text.textContainer;
    if (!self.hoverText || view != text || !layout || !container || layout.numberOfGlyphs == 0) return nil;

    NSPoint containerPoint = NSMakePoint(
        point.x - text.textContainerInset.width,
        point.y - text.textContainerInset.height);
    if (containerPoint.x < 0.0 || containerPoint.y < 0.0) return nil;
    CGFloat fraction = 0.0;
    NSUInteger glyph = [layout glyphIndexForPoint:containerPoint
        inTextContainer:container fractionOfDistanceThroughGlyph:&fraction];
    if (glyph >= layout.numberOfGlyphs) return nil;
    NSRect glyphRect = [layout boundingRectForGlyphRange:NSMakeRange(glyph, 1) inTextContainer:container];
    if (!NSPointInRect(containerPoint, NSInsetRect(glyphRect, -1.0, -1.0))) return nil;

    NSUInteger character = [layout characterIndexForGlyphAtIndex:glyph];
    if (character > text.string.length) return nil;
    int32_t offset = codeEditorByteLength(text.string, NSMakeRange(0, character));
    std::string value = self.hoverText.call(offset);
    return value.empty() ? nil : ns(value);
}
@end

static void layoutCodeEditorTextView(DoofCodeEditorAdapter* adapter) {
    NSTextView* text = adapter.textView;
    NSScrollView* scroll = text.enclosingScrollView;
    if (!text || !scroll) return;
    NSSize viewport = scroll.contentSize;
    [text.layoutManager ensureLayoutForTextContainer:text.textContainer];
    NSRect used = [text.layoutManager usedRectForTextContainer:text.textContainer];
    CGFloat horizontalInsets = text.textContainerInset.width * 2.0 + text.textContainer.lineFragmentPadding * 2.0;
    CGFloat verticalInsets = text.textContainerInset.height * 2.0;
    CGFloat width = adapter.wrapLines ? viewport.width : MAX(viewport.width, NSWidth(used) + horizontalInsets);
    CGFloat height = MAX(viewport.height, NSHeight(used) + verticalInsets);
    text.frame = NSMakeRect(0, 0, MAX(1.0, width), MAX(1.0, height));
    if (adapter.hoverToolTip != 0) [text removeToolTip:adapter.hoverToolTip];
    adapter.hoverToolTip = [text addToolTipRect:text.bounds owner:adapter userData:nullptr];
}
