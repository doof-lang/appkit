// Compiler-provided UTF-8 edits; TextKit owns the popup, keyboard handling and undo.
- (void)scheduleCompletion:(NSString*)insertion {
    NSUInteger generation = ++self.completionGeneration;
    if (!self.completionProvider || insertion.length != 1 || self.hasMarkedText) return;
    unichar character = [insertion characterAtIndex:0];
    if (character != '.' && character != '_' && ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:character]) return;
    NSRange selected = self.selectedRange;
    __weak DoofCodeEditorTextView* weakView = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        DoofCodeEditorTextView* view = weakView;
        if (!view || !view.completionProvider || generation != view.completionGeneration || view.window.firstResponder != view || view.hasMarkedText || !NSEqualRanges(selected, view.selectedRange)) return;
        NSRange range = [view rangeForUserCompletion];
        if (range.location != NSNotFound && (character == '.' || range.length >= 2)) [view complete:nil];
    });
}

- (NSRange)rangeForUserCompletion {
    if (!self.completionProvider) return [super rangeForUserCompletion];
    NSRange selected = self.selectedRange;
    if (selected.location == NSNotFound || selected.length != 0 || self.hasMarkedText) return NSMakeRange(NSNotFound, 0);
    int32_t offset = codeEditorByteLength(self.string, NSMakeRange(0, selected.location));
    NSString* json = ns(self.completionProvider.call(offset));
    id payload = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    self.completionSnapshot = [payload isKindOfClass:NSDictionary.class] ? payload : nil;
    if (![self.completionSnapshot[@"source"] isEqualToString:self.string]) return NSMakeRange(NSNotFound, 0);
    NSArray* items = self.completionSnapshot[@"items"];
    if (![items isKindOfClass:NSArray.class] || items.count == 0) return NSMakeRange(NSNotFound, 0);
    NSDictionary* first = items.firstObject;
    return codeEditorUtf16Range(self.string, [first[@"start"] intValue], [first[@"end"] intValue] - [first[@"start"] intValue]);
}

- (NSArray<NSString*>*)completionsForPartialWordRange:(NSRange)range indexOfSelectedItem:(NSInteger*)index {
    if (!self.completionProvider) return [super completionsForPartialWordRange:range indexOfSelectedItem:index];
    NSMutableArray* labels = [NSMutableArray new];
    for (NSDictionary* item in self.completionSnapshot[@"items"]) {
        NSString* detail = item[@"detail"];
        NSString* label = [detail length] ? [NSString stringWithFormat:@"%@ — %@", item[@"label"], detail] : item[@"label"];
        [labels addObject:label];
    }
    if (index) *index = labels.count > 0 ? 0 : -1;
    return labels;
}

- (void)insertCompletion:(NSString*)word forPartialWordRange:(NSRange)range movement:(NSInteger)movement isFinal:(BOOL)final {
    if (!self.completionProvider) { [super insertCompletion:word forPartialWordRange:range movement:movement isFinal:final]; return; }
    // Do not preview edits: a preview would invalidate the compiler snapshot and
    // could insert an auto-import before the user has accepted the candidate.
    // AppKit also finalizes its list when ordinary typing dismisses it. That
    // finalization is not acceptance: otherwise Po + i becomes Point + i.
    NSEvent* event = NSApp.currentEvent;
    BOOL clicked = movement != NSCancelTextMovement &&
        (event.type == NSEventTypeLeftMouseDown || event.type == NSEventTypeLeftMouseUp);
    BOOL accepted = movement == NSReturnTextMovement || movement == NSTabTextMovement || clicked;
    if (!final || !accepted || ![self.completionSnapshot[@"source"] isEqualToString:self.string]) return;
    for (NSDictionary* item in self.completionSnapshot[@"items"]) {
        NSString* detail = item[@"detail"];
        NSString* label = [detail length] ? [NSString stringWithFormat:@"%@ — %@", item[@"label"], detail] : item[@"label"];
        if (![word isEqualToString:label]) continue;
        [self applyCompletion:item];
        break;
    }
}

- (void)applyCompletion:(NSDictionary*)item {
    NSMutableArray* edits = [NSMutableArray arrayWithArray:item[@"edits"] ?: @[]];
    [edits addObject:item];
    [edits sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [b[@"start"] compare:a[@"start"]];
    }];
    NSString* original = self.string;
    NSMutableArray* ranges = [NSMutableArray new];
    NSUInteger previous = original.length + 1;
    for (NSDictionary* edit in edits) {
        NSRange range = codeEditorUtf16Range(original, [edit[@"start"] intValue], [edit[@"end"] intValue] - [edit[@"start"] intValue]);
        if (range.location == NSNotFound || NSMaxRange(range) > original.length || NSMaxRange(range) > previous) return;
        previous = range.location;
        [ranges addObject:[NSValue valueWithRange:range]];
    }
    NSRange main = codeEditorUtf16Range(original, [item[@"start"] intValue], [item[@"end"] intValue] - [item[@"start"] intValue]);
    NSInteger caret = main.location + [item[@"text"] length];
    for (NSDictionary* edit in item[@"edits"]) {
        NSRange range = codeEditorUtf16Range(original, [edit[@"start"] intValue], [edit[@"end"] intValue] - [edit[@"start"] intValue]);
        if (range.location <= main.location) caret += (NSInteger)[edit[@"text"] length] - (NSInteger)range.length;
    }
    [self breakUndoCoalescing];
    [self.undoManager beginUndoGrouping];
    for (NSUInteger index = 0; index < edits.count; ++index)
        [super insertText:edits[index][@"text"] replacementRange:[ranges[index] rangeValue]];
    self.selectedRange = NSMakeRange(MAX(0, caret), 0);
    [self.undoManager endUndoGrouping];
    [self breakUndoCoalescing];
}
