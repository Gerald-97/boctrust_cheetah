part of '../app_flow/app_flow_navigator.dart';

class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    required this.amount,
    required this.subtitle,
    super.key,
  });

  final String amount;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '₦  NGN',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class MoneyKeypad extends StatelessWidget {
  const MoneyKeypad({
    required this.onKey,
    required this.onBackspace,
    this.showDecimal = true,
    super.key,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final bool showDecimal;

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      showDecimal ? '.00' : '',
      '0',
      '⌫',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(20) + 40,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final keyValue = keys[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: keyValue.isEmpty
              ? null
              : keyValue == '⌫'
              ? onBackspace
              : () => onKey(keyValue),
          child: Center(
            child: Text(
              keyValue,
              style: TextStyle(
                fontSize: keyValue == '.00' ? 14 : 20,
                fontWeight: FontWeight.w700,
                color: keyValue.isEmpty
                    ? Colors.transparent
                    : Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ),
        );
      },
    );
  }
}
