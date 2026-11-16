import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/core/di/injection_container.dart';
import '../common/core/router/app_routes.dart';
import '../common/core/error/exceptions.dart';
import '../common/core/services/photo_picker.dart';
import '../common/presentation/theme/app_colors.dart';
import '../common/presentation/theme/app_text_styles.dart';
import '../common/presentation/widgets/app_button.dart';
import '../common/presentation/widgets/app_snack.dart';
import 'feedback_repository.dart';

/// Profile › Send feedback: opens the feedback screen, then thanks the
/// user back on Profile.
Future<void> openFeedback(BuildContext context) async {
  // null = back without sending; true = all sent; false = sent without
  // the photos.
  // The app's routes are untyped (MaterialPageRoute<dynamic>).
  final result = await Navigator.of(context).pushNamed(AppRoutes.feedback);
  final sent = result is bool ? result : null;
  if (sent == null || !context.mounted) return;
  showAppSnack(
    context,
    sent
        ? 'Thanks! Your feedback was sent to the KidsPool team.'
        : 'Thanks! Your feedback was sent, but the attachments couldn’t be '
              'uploaded.',
  );
}

/// "Send feedback": a problem or an idea, saved for the team (with
/// optional screenshots).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  FeedbackKind _kind = FeedbackKind.problem;
  FeedbackArea? _area;
  int? _rating;
  bool _sending = false;

  /// Local paths of the screenshots / photos to attach.
  final List<String> _attachments = [];

  Future<void> _addAttachment() async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.screen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  'Choose a screenshot or photo',
                  style: AppTextStyles.title,
                ),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Take a photo', style: AppTextStyles.title),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (fromCamera == null || !mounted) return;
    try {
      final path = await sl<PhotoPicker>().pick(fromCamera: fromCamera);
      if (path == null || !mounted) return;
      setState(() {
        _error = null;
        _attachments.add(path);
      });
    } on DeviceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String? _error;

  bool get _canSend => !_sending && _message.text.trim().length >= 3;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await sl<FeedbackRepository>().send(
      kind: _kind,
      message: _message.text,
      area: _area,
      rating: _rating,
      attachments: _attachments,
    );
    if (!mounted) return;
    final error = result.match((f) => f.message, (_) => null);
    if (error == null) {
      Navigator.pop(context, result.getOrElse((_) => true));
      return;
    }
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  String get _hint => switch (_kind) {
    FeedbackKind.problem =>
      'What happened, and what did you expect? Steps help us fix it.',
    FeedbackKind.idea => 'What would make KidsPool better for you?',
    FeedbackKind.praise => 'What do you like?',
    FeedbackKind.other => 'Tell us more',
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: SafeArea(
          child: Column(
            children: [
              // "← Send feedback", like the other Profile pages.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 26),
                      color: AppColors.textPrimary,
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        'Send feedback',
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Problems, ideas and anything that would make rides easier. '
                        'The KidsPool team reads every message.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final k in FeedbackKind.values)
                            ChoiceChip(
                              label: Text(k.label),
                              selected: _kind == k,
                              onSelected: _sending
                                  ? null
                                  : (_) => setState(() => _kind = k),
                              selectedColor: AppColors.lime,
                              backgroundColor: AppColors.surface,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              showCheckmark: false,
                              labelStyle: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<FeedbackArea>(
                        initialValue: _area,
                        isExpanded: true,
                        decoration: _decoration(
                          'Which part of the app? (optional)',
                        ),
                        items: [
                          for (final a in FeedbackArea.values)
                            DropdownMenuItem(value: a, child: Text(a.label)),
                        ],
                        onChanged: _sending
                            ? null
                            : (a) => setState(() => _area = a),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _message,
                        enabled: !_sending,
                        maxLength: 2000,
                        minLines: 4,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: _decoration(_hint),
                      ),
                      Text(
                        'Attachments (optional)',
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add up to ${FeedbackRepository.maxAttachments} screenshots '
                        'or photos that show the problem.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final (i, path) in _attachments.indexed)
                            _AttachmentThumb(
                              path: path,
                              onRemove: _sending
                                  ? null
                                  : () => setState(
                                      () => _attachments.removeAt(i),
                                    ),
                            ),
                          if (_attachments.length <
                              FeedbackRepository.maxAttachments)
                            _AddAttachmentTile(
                              onTap: _sending ? null : _addAttachment,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'How is KidsPool so far? (optional)',
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            IconButton(
                              tooltip: '$i of 5',
                              onPressed: _sending
                                  ? null
                                  : () => setState(
                                      () => _rating = _rating == i ? null : i,
                                    ),
                              icon: Icon(
                                (_rating ?? 0) >= i
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: (_rating ?? 0) >= i
                                    ? AppColors.ink
                                    : AppColors.textSecondary,
                                size: 30,
                              ),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _error!,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Send feedback',
                        isLoading: _sending,
                        onPressed: _canSend ? _send : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We include the app version and your phone’s system version '
                        'so we can fix problems faster. To report a person, use '
                        'Report in their chat or family card.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}

/// A picked screenshot with a remove (×) button.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 240,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.surface,
                  child: Icon(Icons.image_outlined),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Remove attachment',
              excludeSemantics: true,
              child: Material(
                color: AppColors.ink,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "+ Add" tile for another attachment.
class _AddAttachmentTile extends StatelessWidget {
  const _AddAttachmentTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: 'Add attachment',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined),
                const SizedBox(height: 4),
                Text('Add', style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
