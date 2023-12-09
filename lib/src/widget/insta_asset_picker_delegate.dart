// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wechat_assets_picker/wechat_assets_picker.dart';

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
  final bool closeOnComplete;
  final Map<String, File> _cachedFileMap = {};

  /// Called when the confirmation [TextButton] is tapped
  void onConfirm(BuildContext context) {
    if (closeOnComplete) {
      Navigator.of(context).maybePop(provider.selectedAssets);
    }
  }

  /// Called when the asset thumbnail is tapped
  @override
  Future<void> viewAsset(
    BuildContext context,
    int index,
    AssetEntity currentAsset,
  ) async {
    // if is preview asset, unselect it
    selectAsset(
      context,
      currentAsset,
      index,
      provider.selectedAssets.contains(currentAsset),
    );
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

  Widget _pickerLayout(BuildContext context) =>
      ChangeNotifierProvider<DefaultAssetPickerProvider>.value(
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
          body: Column(children: [
            if (context
                .watch<DefaultAssetPickerProvider>()
                .selectedAssets
                .isNotEmpty)
              _pickedAssets(context, provider.selectedAssets),
            Expanded(
              child: _buildGrid(context),
            ),
          ]),
        ),
      );

  Widget _pickedAssets(BuildContext context, List<AssetEntity> assets) {
    removeAsset(AssetEntity asset) {
      final index = provider.currentAssets.indexOf(asset);
      if (index == -1) return;
      selectAsset(context, asset, index, true);
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 10),
          ...assets.map(
            (e) => _cachedFileMap[e.id] == null
                ? FutureBuilder(
                    key: Key(e.id),
                    builder: (_, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.data != null) {
                        _cachedFileMap[e.id] = snapshot.data!;
                        return _imageWidget(
                            snapshot.data!, () => removeAsset(e));
                      }
                      return const SizedBox();
                    },
                    future: e.file,
                  )
                : _imageWidget(_cachedFileMap[e.id]!, () => removeAsset(e)),
          )
        ],
      ),
    );
  }

  Widget _imageWidget(File file, Function() closeAction) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(10),
        child: Stack(children: [
          Image.file(
            file,
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => closeAction(),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black38,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ]),
      );

  /// Returns most of the widgets of the layout, the app bar, the crop view and the grid view
  @override
  Widget androidLayout(BuildContext context) => _pickerLayout(context);

  @override
  Widget appleOSLayout(BuildContext context) => _pickerLayout(context);

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
                    onTap: () => selectAsset(
                      context,
                      asset,
                      index,
                      selectedAssets.contains(asset),
                    ),
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
