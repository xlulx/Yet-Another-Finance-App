import 'package:flutter/material.dart';

/// ☰ button for the main pages' app bars. The side menu belongs to the
/// app's outer scaffold (so it covers the bottom navigation too), not to the
/// page's own scaffold.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: () {
        // The nearest scaffold is the page's own; open the first one up the
        // tree that has a drawer.
        context.visitAncestorElements((element) {
          if (element is StatefulElement && element.state is ScaffoldState) {
            final scaffold = element.state as ScaffoldState;
            if (scaffold.hasDrawer) {
              scaffold.openDrawer();
              return false;
            }
          }
          return true;
        });
      },
    );
  }
}
