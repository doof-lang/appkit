#pragma once
#include "doof_runtime.hpp"
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace doof_appkit {
class NativeView {
public:
    static std::shared_ptr<NativeView> sourceView(doof::callback<void(int32_t)> toggle);
    void setSourceLines(const std::shared_ptr<std::vector<std::string>>& lines, const std::shared_ptr<std::vector<int32_t>>& markers, int32_t currentLine, bool reveal);
    void setSourceHighlights(const std::shared_ptr<std::vector<int32_t>>& rows, const std::shared_ptr<std::vector<int32_t>>& starts, const std::shared_ptr<std::vector<int32_t>>& lengths, const std::shared_ptr<std::vector<int32_t>>& styles);
    int32_t sourceLineCount();
    static std::shared_ptr<NativeView> container();
    static std::shared_ptr<NativeView> outlineView();
    void setOutlineData(doof::callback<std::string(int32_t)> label, doof::callback<void(int32_t)> selection);
    void reloadOutline(const std::shared_ptr<std::vector<std::string>>& keys, const std::shared_ptr<std::vector<int32_t>>& parents);
    int32_t outlineSelectedIndex();
    void selectOutline(const std::string& key);
    void expandOutline(const std::string& key, bool recursive);
    void collapseOutline(const std::string& key, bool recursive);
    std::string outlineSnapshot();
    void performOutlineSelection(int32_t row);
    static std::shared_ptr<NativeView> tabView();
    void addTab(const std::string& title, std::shared_ptr<NativeView> content);
    void setTabTitle(int32_t index, const std::string& title);
    void selectTab(int32_t index);
    void setTabAction(doof::callback<void(int32_t)> handler);
    void setTabLayoutHandler(doof::callback<void(int32_t, double, double)> handler);
    std::shared_ptr<std::vector<double>> tabMetrics();
    std::string tabSnapshot();
    void performTabSelection(int32_t index);
    static std::shared_ptr<NativeView> groupBox(const std::string& title);
    std::shared_ptr<std::vector<double>> groupBoxMetrics();
    std::string groupBoxSnapshot();
    static std::shared_ptr<NativeView> split(int32_t axis);
    static std::shared_ptr<NativeView> scroll();
    static std::shared_ptr<NativeView> text(const std::string& value);
    static std::shared_ptr<NativeView> button(const std::string& title);
    static std::shared_ptr<NativeView> textField(const std::string& value, const std::string& placeholder);
    static std::shared_ptr<NativeView> secureTextField(const std::string& value, const std::string& placeholder);
    static std::shared_ptr<NativeView> checkbox(const std::string& title, bool checked);
    static std::shared_ptr<NativeView> picker(const std::shared_ptr<std::vector<std::string>>& options, const std::string& selected);
    static std::shared_ptr<NativeView> slider(double value, double minimum, double maximum);
    static std::shared_ptr<NativeView> progressBar(double value, double minimum, double maximum);
    static std::shared_ptr<NativeView> searchField(const std::string& value, const std::string& placeholder);
    static std::shared_ptr<NativeView> stepper(double value, double minimum, double maximum, double increment);
    static std::shared_ptr<NativeView> segmentedControl(const std::shared_ptr<std::vector<std::string>>& segments, int32_t selectedIndex);
    static std::shared_ptr<NativeView> separator();
    static std::shared_ptr<NativeView> spinner();
    static std::shared_ptr<NativeView> switchControl(bool checked);
    static std::shared_ptr<NativeView> textArea(const std::string& value);
    static std::shared_ptr<NativeView> radioGroup(const std::shared_ptr<std::vector<std::string>>& options, const std::string& selected);
    static std::shared_ptr<NativeView> comboBox(const std::shared_ptr<std::vector<std::string>>& options, const std::string& value);
    static std::shared_ptr<NativeView> datePicker(const std::string& value);
    static std::shared_ptr<NativeView> colorWell(double red, double green, double blue, double alpha);
    static std::shared_ptr<NativeView> table(
        const std::shared_ptr<std::vector<std::string>>& columnIds,
        const std::shared_ptr<std::vector<std::string>>& columnTitles,
        const std::shared_ptr<std::vector<double>>& columnWidths,
        const std::shared_ptr<std::vector<bool>>& columnSortable
    );
    static std::shared_ptr<NativeView> imageCanvas();
    ~NativeView();
    void append(std::shared_ptr<NativeView> child);
    void insertBefore(std::shared_ptr<NativeView> child, std::shared_ptr<NativeView> reference);
    void replace(std::shared_ptr<NativeView> child, std::shared_ptr<NativeView> target);
    void detach();
    void dispose();
    void setFrame(double x, double y, double width, double height);
    void setDocumentSize(double width, double height);
    double measureWidth(const std::optional<double>& maxWidth, const std::optional<double>& maxHeight);
    double measureHeight(const std::optional<double>& maxWidth, const std::optional<double>& maxHeight);
    void setText(const std::string& value);
    void setEnabled(bool value);
    void setHidden(bool value);
    void setChecked(bool value);
    void setSelectedValue(const std::string& value);
    void setValue(double value);
    void setSelectedIndex(int32_t value);
    void setDate(const std::string& value);
    void setColor(double red, double green, double blue, double alpha);
    void setAction(doof::callback<void(std::string, bool)> handler);
    void setValueAction(doof::callback<void(double)> handler);
    void setIndexAction(doof::callback<void(int32_t)> handler);
    void setColorAction(doof::callback<void(double, double, double, double)> handler);
    void setAccessibility(const std::string& label, const std::string& help, const std::string& identifier);
    void setTitleElement(std::shared_ptr<NativeView> label);
    void setSplitPosition(int32_t index, double position);
    void setPaneWeights(const std::shared_ptr<std::vector<double>>& weights);
    void setTextStyle(double size, bool semibold, bool secondary);
    void setPaneLayoutHandler(doof::callback<void(int32_t, double, double)> handler);
    void setTableData(
        doof::callback<int32_t()> rowCount,
        doof::callback<std::string(int32_t)> rowKey,
        doof::callback<int32_t(int32_t)> columnKind,
        doof::callback<bool(int32_t)> columnEditable,
        doof::callback<std::string(int32_t, int32_t)> textValue,
        doof::callback<bool(int32_t, int32_t)> boolValue,
        doof::callback<double(int32_t, int32_t)> numberValue,
        doof::callback<void(int32_t, int32_t, std::string)> textChanged,
        doof::callback<void(int32_t, int32_t, bool)> boolChanged,
        doof::callback<void(int32_t, int32_t, double)> numberChanged,
        doof::callback<void(int32_t, int32_t, std::string)> dateChanged
    );
    void reloadTable();
    void setCanvasImage(const std::shared_ptr<std::vector<uint8_t>>& encodedImage);
    void setCanvasBackground(int32_t background);
    void setCanvasClickAction(doof::callback<void(double, double)> handler);
    void setCanvasDropAction(doof::callback<void(std::shared_ptr<std::vector<std::string>>)> handler);
    void zoomCanvas(double factor);
    void actualSizeCanvas();
    void fitCanvas();
private:
    friend class NativeWindow;
    NativeView();
    struct Impl;
    std::shared_ptr<Impl> impl_;
};

class NativeWindow {
public:
    static std::shared_ptr<NativeWindow> create(const std::string& title, int32_t width, int32_t height, bool resizable);
    ~NativeWindow();
    void setRoot(std::shared_ptr<NativeView> view);
    void setLayoutHandler(doof::callback<void(double, double)> handler);
    void setToolbar(
        const std::shared_ptr<std::vector<std::string>>& ids,
        const std::shared_ptr<std::vector<std::string>>& labels,
        const std::shared_ptr<std::vector<std::string>>& symbols,
        const std::shared_ptr<std::vector<std::string>>& toolTips,
        const std::shared_ptr<std::vector<int32_t>>& kinds,
        const std::shared_ptr<std::vector<bool>>& enabled,
        const std::shared_ptr<std::vector<doof::callback<void(std::string, bool)>>>& handlers,
        int32_t displayMode,
        bool allowsCustomization
    );
    void setToolbarItemEnabled(int32_t index, bool enabled);
    void show();
    void close();
    bool isShown();
    void presentAlert(
        const std::string& title,
        const std::string& message,
        int32_t style,
        const std::shared_ptr<std::vector<std::string>>& buttonTitles,
        const std::shared_ptr<std::vector<bool>>& destructive,
        int32_t primaryIndex,
        int32_t cancelIndex,
        doof::callback<void(int32_t)> handler
    );
    void presentSheet(
        const std::string& title,
        int32_t width,
        int32_t height,
        std::shared_ptr<NativeView> content,
        const std::shared_ptr<std::vector<std::string>>& buttonTitles,
        const std::shared_ptr<std::vector<bool>>& destructive,
        int32_t primaryIndex,
        int32_t cancelIndex,
        doof::callback<void(double, double)> layoutHandler,
        doof::callback<bool(int32_t)> validateHandler,
        doof::callback<void(int32_t)> completionHandler
    );
private:
    NativeWindow();
    struct Impl;
    std::shared_ptr<Impl> impl_;
};

class NativeApplication {
public:
    static std::shared_ptr<NativeApplication> shared();
    bool isRunning();
    bool isMainThread();
    int32_t shownWindowCount();
    void run(doof::callback<int32_t()> drain);
    void quit();
    void requestWake();
    void setOpenFilesHandler(doof::callback<void(std::shared_ptr<std::vector<std::string>>)> handler);
    void setMenu(
        const std::shared_ptr<std::vector<int32_t>>& nodeKinds,
        const std::shared_ptr<std::vector<int32_t>>& parentIndices,
        const std::shared_ptr<std::vector<int32_t>>& menuRoles,
        const std::shared_ptr<std::vector<int32_t>>& actions,
        const std::shared_ptr<std::vector<std::string>>& titles,
        const std::shared_ptr<std::vector<std::string>>& keys,
        const std::shared_ptr<std::vector<int32_t>>& modifierMasks,
        const std::shared_ptr<std::vector<bool>>& enabled,
        const std::shared_ptr<std::vector<bool>>& checked,
        const std::shared_ptr<std::vector<int32_t>>& handlerIndices,
        const std::shared_ptr<std::vector<doof::callback<void(std::string, bool)>>>& handlers
    );
    void setMenuItemEnabled(int32_t index, bool enabled);
    void setMenuItemChecked(int32_t index, bool checked);
    std::string menuSnapshot();
    void performMenuItem(int32_t index);
    int32_t alert(
        const std::string& title,
        const std::string& message,
        int32_t style,
        const std::shared_ptr<std::vector<std::string>>& buttonTitles,
        const std::shared_ptr<std::vector<bool>>& destructive,
        int32_t primaryIndex,
        int32_t cancelIndex
    );
    std::shared_ptr<std::vector<std::string>> openFile(const std::string& title, bool directories, bool multiple);
    std::optional<std::string> saveFile(const std::string& title, const std::string& suggestedName);
private:
    NativeApplication();
    struct Impl;
    std::shared_ptr<Impl> impl_;
};
} // namespace doof_appkit
