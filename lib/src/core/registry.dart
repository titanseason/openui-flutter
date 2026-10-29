import 'package:flutter/widgets.dart';

import 'lang.dart';

/// Builds a component node. [renderChild] renders a child node through the
/// renderer's own node builder, so theme, form state and Query data flow
/// through a custom component exactly as they do through a built-in one.
typedef OpenUIComponentBuilder = Widget Function(BuildContext context, ElementNode node, Widget Function(ElementNode) renderChild);

/// Immutable registry of custom component builders, keyed by component name.
class ComponentRegistry {
  const ComponentRegistry({Map<String, OpenUIComponentBuilder> builders = const {}}) : _builders = builders;
  final Map<String, OpenUIComponentBuilder> _builders;

  OpenUIComponentBuilder? lookup(String name) => _builders[name];

  ComponentRegistry withBuilder(String name, OpenUIComponentBuilder builder) {
    return ComponentRegistry(builders: {..._builders, name: builder});
  }
}
