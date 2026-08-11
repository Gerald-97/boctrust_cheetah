part of '../app_flow/app_flow_navigator.dart';

class PaymentActionCard extends StatelessWidget {
  const PaymentActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoundedIcon(icon: icon, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class BillGridItem extends StatelessWidget {
  const BillGridItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RoundedIcon(icon: icon, color: color, size: 48),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkSelector extends StatelessWidget {
  const NetworkSelector({required this.selected, super.key});
  final int selected;

  @override
  Widget build(BuildContext context) {
    const networks = ['MTN', 'Airtel', 'Glo', '9mobile'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NETWORK',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            networks.length,
            (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index == networks.length - 1 ? 0 : 8,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == selected
                      ? BocColors.navy
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: index == selected
                        ? BocColors.navy
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Text(
                  networks[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: index == selected ? BocColors.goldLight : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DataPlanCard extends StatelessWidget {
  const DataPlanCard({
    required this.name,
    required this.price,
    required this.selected,
    super.key,
  });

  final String name;
  final String price;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: selected
            ? context.bocColors.bluePale
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? BocColors.navy : Theme.of(context).dividerColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: BocColors.navy,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? BocColors.navy : Theme.of(context).dividerColor,
          ),
        ],
      ),
    );
  }
}
