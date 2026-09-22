std::shared_ptr<NativeView> NativeView::codeEditor(
    const std::string& value, bool lineNumbers, bool wrapLines, double fontSize, int32_t tabWidth, bool autoIndent,
    doof::callback<void(std::string)> change,
    doof::callback<void(int32_t, int32_t)> selectionChange,
    doof::callback<std::string(int32_t)> hoverText,
    doof::callback<std::string(int32_t)> completions) {
    auto result = std::shared_ptr<NativeView>(new NativeView());
    auto scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = !wrapLines;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    auto text = [[DoofCodeEditorTextView alloc] initWithFrame:NSZeroRect];
    text.autoIndent = autoIndent;
    text.indentationWidth = tabWidth;
    text.completionProvider = std::move(completions);
    text.string = ns(value);
    text.richText = NO;
    text.importsGraphics = NO;
    text.allowsUndo = YES;
    text.usesFindBar = YES;
    text.incrementalSearchingEnabled = YES;
    text.automaticQuoteSubstitutionEnabled = NO;
    text.automaticDashSubstitutionEnabled = NO;
    text.automaticTextReplacementEnabled = NO;
    text.automaticSpellingCorrectionEnabled = NO;
    text.continuousSpellCheckingEnabled = NO;
    text.grammarCheckingEnabled = NO;
    text.textContainerInset = NSMakeSize(8.0, 8.0);
    text.textContainer.lineFragmentPadding = 4.0;
    text.verticallyResizable = YES;
    text.horizontallyResizable = !wrapLines;
    // The document must acquire the clip view's width on its first layout even
    // when its text container is allowed to grow horizontally without wrapping.
    text.autoresizingMask = NSViewWidthSizable;
    text.textContainer.widthTracksTextView = wrapLines;
    if (!wrapLines) text.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    auto adapter = [DoofCodeEditorAdapter new];
    adapter.textView = text;
    adapter.change = std::move(change);
    adapter.selectionChange = std::move(selectionChange);
    adapter.hoverText = std::move(hoverText);
    adapter.fontSize = fontSize;
    adapter.tabWidth = tabWidth;
    adapter.autoIndent = autoIndent;
    adapter.lineNumbers = lineNumbers;
    adapter.wrapLines = wrapLines;
    text.delegate = adapter;
    NSDictionary* base = codeEditorBaseAttributes(fontSize, tabWidth);
    [text.textStorage beginEditing];
    [text.textStorage setAttributes:base range:NSMakeRange(0, text.textStorage.length)];
    [text.textStorage endEditing];
    text.typingAttributes = base;
    text.needsDisplay = YES;
    scroll.documentView = text;
    if (lineNumbers) {
        scroll.verticalRulerView = [[DoofCodeEditorRuler alloc] initWithScrollView:scroll textView:text];
        scroll.hasVerticalRuler = YES;
        scroll.rulersVisible = YES;
        [scroll tile];
    }
    result->impl_->codeEditorAdapter = adapter;
    result->impl_->textView = text;
    result->impl_->view = scroll;
    return result;
}

void NativeView::setCodeEditorText(const std::string& value) {
    auto adapter = impl_->codeEditorAdapter;
    if (!adapter || impl_->disposed) return;
    NSString* next = ns(value);
    if ([impl_->textView.string isEqualToString:next]) return;
    impl_->textView.string = next;
    NSDictionary* base = codeEditorBaseAttributes(adapter.fontSize, adapter.tabWidth);
    [impl_->textView.textStorage beginEditing];
    [impl_->textView.textStorage setAttributes:base range:NSMakeRange(0, impl_->textView.textStorage.length)];
    [impl_->textView.textStorage endEditing];
    impl_->textView.typingAttributes = base;
    impl_->textView.needsDisplay = YES;
    layoutCodeEditorTextView(adapter);
    [(DoofCodeEditorRuler*)impl_->textView.enclosingScrollView.verticalRulerView invalidateLineNumbers];
}

std::string NativeView::codeEditorText() {
    return impl_->codeEditorAdapter && !impl_->disposed ? utf8(impl_->textView.string) : std::string();
}

void NativeView::setCodeEditorHighlights(
    const std::shared_ptr<std::vector<int32_t>>& starts,
    const std::shared_ptr<std::vector<int32_t>>& lengths,
    const std::shared_ptr<std::vector<int32_t>>& styles) {
    auto adapter = impl_->codeEditorAdapter;
    if (!adapter || impl_->disposed) return;
    NSTextStorage* storage = impl_->textView.textStorage;
    NSDictionary* base = codeEditorBaseAttributes(adapter.fontSize, adapter.tabWidth);
    NSArray<NSColor*>* colors = @[NSColor.textColor, NSColor.systemPurpleColor, NSColor.systemRedColor,
        NSColor.systemBlueColor, NSColor.secondaryLabelColor, NSColor.systemTealColor, NSColor.systemBrownColor];
    [storage beginEditing];
    [storage setAttributes:base range:NSMakeRange(0, storage.length)];
    size_t count = std::min({starts->size(), lengths->size(), styles->size()});
    for (size_t index = 0; index < count; ++index) {
        int32_t style = (*styles)[index];
        if (style < 0 || style > 8) continue;
        NSRange range = codeEditorUtf16Range(impl_->textView.string, (*starts)[index], (*lengths)[index]);
        if (range.location == NSNotFound || NSMaxRange(range) > storage.length) continue;
        if (style == 7 || style == 8) {
            NSColor* color = style == 7 ? NSColor.systemRedColor : NSColor.systemOrangeColor;
            NSNumber* underline = @(NSUnderlineStyleSingle | NSUnderlinePatternDot);
            [storage addAttribute:NSUnderlineStyleAttributeName value:underline range:range];
            [storage addAttribute:NSUnderlineColorAttributeName value:color range:range];
            continue;
        }
        [storage addAttribute:NSForegroundColorAttributeName value:colors[style] range:range];
        if (style == 1) [storage addAttribute:NSFontAttributeName
            value:[NSFont monospacedSystemFontOfSize:adapter.fontSize weight:NSFontWeightSemibold] range:range];
    }
    [storage endEditing];
    impl_->textView.typingAttributes = base;
}

int32_t NativeView::codeEditorSelectionStart() {
    if (!impl_->codeEditorAdapter || impl_->disposed) return 0;
    return codeEditorByteLength(impl_->textView.string, NSMakeRange(0, impl_->textView.selectedRange.location));
}

int32_t NativeView::codeEditorSelectionLength() {
    if (!impl_->codeEditorAdapter || impl_->disposed) return 0;
    return codeEditorByteLength(impl_->textView.string, impl_->textView.selectedRange);
}

void NativeView::setCodeEditorSelection(int32_t start, int32_t length, bool reveal) {
    if (!impl_->codeEditorAdapter || impl_->disposed) return;
    NSRange range = codeEditorUtf16Range(impl_->textView.string, start, length);
    if (range.location == NSNotFound || NSMaxRange(range) > impl_->textView.string.length) return;
    impl_->textView.selectedRange = range;
    if (reveal) [impl_->textView scrollRangeToVisible:range];
}

std::string NativeView::codeEditorHoverText(int32_t offset) {
    auto adapter = impl_->codeEditorAdapter;
    if (!adapter || impl_->disposed || !adapter.hoverText || offset < 0 || offset > codeEditorByteLength(impl_->textView.string, NSMakeRange(0, impl_->textView.string.length))) return {};
    return adapter.hoverText.call(offset);
}

void NativeView::performCodeEditorNewline() {
    if (!impl_->codeEditorAdapter || impl_->disposed) return;
    [impl_->textView insertNewline:nil];
}

void NativeView::performCodeEditorText(std::string text) {
    if (!impl_->codeEditorAdapter || impl_->disposed) return;
    [impl_->textView insertText:ns(text) replacementRange:impl_->textView.selectedRange];
}

std::string NativeView::codeEditorSnapshot() {
    auto adapter = impl_->codeEditorAdapter;
    if (!adapter || impl_->disposed) return "{}";
    NSDictionary* snapshot = @{
        @"text": impl_->textView.string ?: @"",
        @"selectionStart": @(codeEditorSelectionStart()),
        @"selectionLength": @(codeEditorSelectionLength()),
        @"lineNumbers": @(adapter.lineNumbers),
        @"wrapLines": @(adapter.wrapLines),
        @"fontSize": @(adapter.fontSize),
        @"tabWidth": @(adapter.tabWidth),
        @"autoIndent": @(adapter.autoIndent),
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
    return data ? utf8([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]) : "{}";
}

void NativeView::completeCodeEditor() {
    if (!impl_->codeEditorAdapter || impl_->disposed) return;
    [impl_->textView.window makeFirstResponder:impl_->textView];
    [impl_->textView complete:nil];
}

void NativeView::performCodeEditorCompletion(int32_t index) {
    performCodeEditorCompletionMovement(index, NSReturnTextMovement);
}

void NativeView::performCodeEditorCompletionMovement(int32_t index, int32_t movement) {
    if (!impl_->codeEditorAdapter || impl_->disposed || index < 0) return;
    auto text = (DoofCodeEditorTextView*)impl_->textView;
    NSRange range = [text rangeForUserCompletion];
    if (range.location == NSNotFound) return;
    NSArray* words = [text completionsForPartialWordRange:range indexOfSelectedItem:nullptr];
    if ((NSUInteger)index >= words.count) return;
    [text insertCompletion:words[index] forPartialWordRange:range movement:movement isFinal:YES];
}

void NativeView::undoCodeEditor() {
    if (impl_->codeEditorAdapter && !impl_->disposed) [impl_->textView.undoManager undo];
}
void NativeView::redoCodeEditor() {
    if (impl_->codeEditorAdapter && !impl_->disposed) [impl_->textView.undoManager redo];
}
