part of '../app_flow/app_flow_navigator.dart';

class SavingsHeroCard extends StatelessWidget {
  const SavingsHeroCard({
    required this.rate,
    required this.amount,
    required this.growth,
    super.key,
  });

  final String rate;
  final String amount;
  final String growth;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            BocColors.gold.withValues(alpha: 0.15),
            Theme.of(context).cardColor,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: BocColors.navy,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              rate,
              style: const TextStyle(
                color: BocColors.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            amount,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 29),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: BocColors.green,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                growth,
                style: const TextStyle(
                  color: BocColors.green,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({required this.text, required this.value, super.key});
  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.bocColors.goldPale,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF8A6A08),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              value,
              style: const TextStyle(
                color: BocColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GridViewInfo extends StatelessWidget {
  const GridViewInfo({required this.items, super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: items
          .map(
            (item) => SurfaceCard(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.$1.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({
    required this.progress,
    required this.name,
    required this.frequency,
    required this.amount,
    super.key,
  });

  final double progress;
  final String name;
  final String frequency;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: const AlwaysStoppedAnimation(BocColors.purple),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  frequency.toUpperCase(),
                  style: const TextStyle(
                    color: BocColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  amount,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FrequencySelector extends StatelessWidget {
  const FrequencySelector({super.key});

  @override
  Widget build(BuildContext context) {
    const values = ['Daily', 'Weekly', 'Monthly'];
    return Row(
      children: List.generate(
        values.length,
        (index) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == values.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 1 ? BocColors.navy : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: index == 1
                    ? BocColors.navy
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Text(
              values[index],
              style: TextStyle(
                color: index == 1
                    ? BocColors.goldLight
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key});

  @override
  Widget build(BuildContext context) {
    const initials = ['AO', 'IN', 'CO', '+3'];
    return SizedBox(
      width: 122,
      height: 34,
      child: Stack(
        children: List.generate(
          initials.length,
          (index) => Positioned(
            left: index * 28,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: index == initials.length - 1
                  ? context.bocColors.goldPale
                  : BocColors.navy,
              foregroundColor: index == initials.length - 1
                  ? BocColors.gold
                  : BocColors.goldLight,
              child: Text(
                initials[index],
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MemberRow extends StatelessWidget {
  const MemberRow({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.amount,
    super.key,
  });

  final String initials;
  final String name;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: BocColors.navy,
            foregroundColor: BocColors.goldLight,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
