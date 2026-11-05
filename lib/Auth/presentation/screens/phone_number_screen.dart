import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_labeled_field.dart';
import '../providers/auth_flow_provider.dart';
import '../widgets/phone_number_formatter.dart';
import '../widgets/phone_number_view.dart';

/// S03 · Phone number — Figma node 1018:7865.
class PhoneNumberScreen extends StatelessWidget {
  const PhoneNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthFlowProvider>.value(
      value: sl<AuthFlowProvider>(),
      child: const _PhoneNumberBody(),
    );
  }
}

class _PhoneNumberBody extends StatefulWidget {
  const _PhoneNumberBody();

  @override
  State<_PhoneNumberBody> createState() => _PhoneNumberBodyState();
}

class _PhoneNumberBodyState extends State<_PhoneNumberBody> {
  late final TextEditingController _controller = TextEditingController(
    text: UsPhoneNumberFormatter.format(
      context.read<AuthFlowProvider>().phoneDigits,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendOtp() {
    FocusScope.of(context).unfocus();
    Navigator.pushNamed(context, AppRoutes.otp);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AuthFlowProvider>();

    return PhoneNumberView(
      onSendOtp: flow.isPhoneValid ? _sendOtp : null,
      field: AppLabeledField(
        label: 'Mobile number',
        hint: '${UsPhoneNumberFormatter.countryPrefix}(555) 000-0000',
        controller: _controller,
        large: true,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        leading: const AppIcon(AppAssets.iconPhone, size: 20),
        inputFormatters: const [UsPhoneNumberFormatter()],
        onChanged: (text) => context.read<AuthFlowProvider>().setPhoneDigits(
          UsPhoneNumberFormatter.digitsOf(text),
        ),
      ),
    );
  }
}
