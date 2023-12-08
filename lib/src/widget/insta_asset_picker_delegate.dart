// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// The reduced height of the crop view

/// The position of the crop view when extended
const _kExtendedCropViewPosition = 0.0;

/// Scroll offset multiplier to start viewer position animation

const _kIndicatorSize = 20.0;

class InstaAssetPickerBuilder extends DefaultAssetPickerBuilderDelegate {
  InstaAssetPickerBuilder({
    required super.initialPermission,
    required super.provider,
    super.gridCount = 4,
    super.pickerTheme,
    super.textDelegate,
    super.locale,
    super.keepScrollOffset,
    super.loadingIndicatorBuilder,
    super.specialItemBuilder,
    SpecialItemPosition? specialItemPosition,
    this.title,
    this.closeOnComplete = false,
  }) : super(
          shouldRevertGrid: false,
          specialItemPosition: specialItemPosition ?? SpecialItemPosition.none,
        );

  final String? title;

  /// Should the picker be closed when the selection is confirmed
  ///
  /// Defaults to `false`, like instagram
  final bool closeOnComplete;

  // LOCAL PARAMETERS
  final ValueNotifier<double> _cropViewPosition = ValueNotifier<double>(0);

  /// Controller handling the state of asset crop values and the exportation

  @override
  void dispose() {
    if (!keepScrollOffset) {
      _cropViewPosition.dispose();
    }
    super.dispose();
  }

  /// Called when the confirmation [TextButton] is tapped
  void onConfirm(BuildContext context) {
    if (closeOnComplete) {
      Navigator.of(context).maybePop(provider.selectedAssets);
    }
  }

  /// Returns thumbnail [index] position in scroll view
  double indexPosition(BuildContext context, int index) {
    final row = (index / gridCount).floor();
    final size =
        (MediaQuery.of(context).size.width - itemSpacing * (gridCount - 1)) /
            gridCount;
    return row * size + (row * itemSpacing);
  }

  /// Unselect all the selected assets
  void unSelectAll() {
    provider.selectedAssets = [];
  }

  /// Called when the asset thumbnail is tapped
  @override
  Future<void> viewAsset(
    BuildContext context,
    int index,
    AssetEntity currentAsset,
  ) async {
    // if is preview asset, unselect it
    if (provider.selectedAssets.isNotEmpty) {
      selectAsset(context, currentAsset, index, true);
      return;
    }

    selectAsset(context, currentAsset, index, false);
  }

  /// Called when an asset is selected
  @override
  Future<void> selectAsset(
    BuildContext context,
    AssetEntity asset,
    int index,
    bool selected,
  ) async {
    await super.selectAsset(context, asset, index, selected);
  }

  /// Returns the [TextButton] that open album list
  @override
  Widget pathEntitySelector(BuildContext context) {
    Widget selector(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4)
            .copyWith(top: 8, bottom: 12),
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: theme.splashColor,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4).copyWith(left: 6),
          ),
          onPressed: () {
            Feedback.forTap(context);
            isSwitchingPath.value = !isSwitchingPath.value;
          },
          child: Selector<DefaultAssetPickerProvider,
              PathWrapper<AssetPathEntity>?>(
            selector: (_, DefaultAssetPickerProvider p) => p.currentPath,
            builder: (_, PathWrapper<AssetPathEntity>? p, Widget? w) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (p != null)
                  Flexible(
                    child: Text(
                      isPermissionLimited && p.path.isAll
                          ? textDelegate.accessiblePathName
                          : p.path.name,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                w!,
              ],
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: isSwitchingPath,
              builder: (_, bool isSwitchingPath, Widget? w) => Transform.rotate(
                angle: isSwitchingPath ? math.pi : 0,
                child: w,
              ),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: theme.iconTheme.color,
              ),
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (BuildContext c, _) => selector(c),
    );
  }

  /// Returns the top right selection confirmation [TextButton]
  /// Calls [onConfirm]
  @override
  Widget confirmButton(BuildContext context) {
    final Widget button = Consumer<DefaultAssetPickerProvider>(
      builder: (_, DefaultAssetPickerProvider p, __) {
        return TextButton(
            style: pickerTheme?.textButtonTheme.style ??
                TextButton.styleFrom(
                  foregroundColor: themeColor,
                  disabledForegroundColor: theme.dividerColor,
                ),
            onPressed: p.isSelectedNotEmpty ? () => onConfirm(context) : null,
            child: Text(
              p.isSelectedNotEmpty && !isSingleAssetMode
                  ? '${textDelegate.confirm}'
                      ' (${p.selectedAssets.length}/${p.maxAssets})'
                  : textDelegate.confirm,
            ));
      },
    );
    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (_, __) => button,
    );
  }

  /// Returns most of the widgets of the layout, the app bar, the crop view and the grid view
  @override
  Widget androidLayout(BuildContext context) {
    return ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (context, _) => AssetPickerAppBarWrapper(
        appBar: AssetPickerAppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          title: title != null
              ? Text(
                  title!,
                  style: theme.appBarTheme.titleTextStyle,
                )
              : null,
          leading: backButton(context),
          actions: <Widget>[confirmButton(context)],
        ),
        body: Column(
          children: [
            Row(
              children: [
                pathEntitySelector(context),
              ],
            ),
            Expanded(child: _buildGrid(context)),
          ],
        ),
      ),
    );
  }

  /// Since the layout is the same on all platform, it simply call [androidLayout]
  @override
  Widget appleOSLayout(BuildContext context) => androidLayout(context);

  /// Returns the [GridView] displaying the assets
  Widget _buildGrid(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (BuildContext context, DefaultAssetPickerProvider p, __) {
        final bool shouldDisplayAssets =
            p.hasAssetsToDisplay || shouldBuildSpecialItem;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: shouldDisplayAssets
              ? MediaQuery(
                  // fix: https://github.com/fluttercandies/flutter_wechat_assets_picker/issues/395
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: -kToolbarHeight),
                  ),
                  child: RepaintBoundary(child: assetsGridBuilder(context)),
                )
              : loadingIndicator(context),
        );
      },
    );
  }

  /// To show selected assets indicator and preview asset overlay
  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    final selectedAssets = provider.selectedAssets;
    final Duration duration = switchingPathDuration * 0.75;

    final int indexSelected = selectedAssets.indexOf(asset);
    final bool isSelected = indexSelected != -1;

    final Widget innerSelector = AnimatedContainer(
      duration: duration,
      width: _kIndicatorSize,
      height: _kIndicatorSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.unselectedWidgetColor, width: 1),
        color: isSelected
            ? themeColor
            : theme.unselectedWidgetColor.withOpacity(.2),
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration: duration,
          child: isSelected
              ? Text((indexSelected + 1).toString())
              : const SizedBox.shrink(),
        ),
      ),
    );

    return Positioned.fill(
      child: GestureDetector(
        onTap: isPreviewEnabled ? () => viewAsset(context, index, asset) : null,
        child: AnimatedContainer(
          duration: switchingPathDuration,
          padding: const EdgeInsets.all(4),
          color: theme.colorScheme.background.withOpacity(.1),
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: isSelected && !isSingleAssetMode
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => selectAsset(context, asset, index, isSelected),
                    child: innerSelector,
                  )
                : innerSelector,
          ),
        ),
      ),
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) =>
      const SizedBox.shrink();
}
