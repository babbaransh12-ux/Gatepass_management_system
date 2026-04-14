import 'package:e_gatepass/core/utils/responsive.dart';
import 'package:flutter/material.dart';

class ModernScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final bool showAppBar;
  final bool scrollable;
  final double maxWidth;

  const ModernScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.showAppBar = true,
    this.scrollable = true,
    this.maxWidth = 600, // Optimal reading/interaction width for tablets/desktop
  });

  @override
  Widget build(BuildContext context) {
    bool isDesktop = Responsive.isDesktop(context);
    bool isTablet = Responsive.isTablet(context);

    Widget content = scrollable
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: body,
          )
        : body;

    // Constrain width on large screens to keep it "native window" style
    if (isDesktop || isTablet) {
      content = Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: isDesktop || isTablet ? BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              actions: actions,
              leading: isDesktop && drawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    )
                  : null,
            )
          : null,
      drawer: drawer,
      body: SafeArea(child: content),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
