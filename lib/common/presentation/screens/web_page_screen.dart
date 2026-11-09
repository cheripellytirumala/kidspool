import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// In-app web page (Terms, Privacy Policy). Reads [WebPageArgs].
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key});

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  WebViewController? _controller;
  WebPageArgs? _args;
  int _progress = 0;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! WebPageArgs) return;
    _args = args;
    final uri = Uri.tryParse(args.url);
    if (uri == null) {
      _failed = true;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.screen)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onWebResourceError: (error) {
            // Only the page itself failing matters, not an image or script.
            if (error.isForMainFrame ?? true) {
              if (mounted) setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(uri);
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 26),
                      color: AppColors.textPrimary,
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        _args?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_failed && _progress < 100)
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: AppColors.ink,
                  backgroundColor: AppColors.surface,
                ),
              Expanded(
                child: _failed || controller == null
                    ? _Error(onRetry: controller == null ? null : _retry)
                    : WebViewWidget(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'This page couldn’t be loaded. Check your connection and try '
            'again.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
