part of '../app_flow/app_ui.dart';

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
