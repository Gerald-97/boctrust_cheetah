part of '../app_flow/app_flow_navigator.dart';

class BillerCategory {
  const BillerCategory({
    required this.title,
    required this.fieldLabel,
    required this.icon,
    required this.tint,
    required this.items,
  });

  final String title;
  final String fieldLabel;
  final IconData icon;
  final Color tint;
  final List<BillerItem> items;
}

class BillerItem {
  const BillerItem(this.name, this.subtitle);
  final String name;
  final String subtitle;
}

const billerCategories = <String, BillerCategory>{
  'electricity': BillerCategory(
    title: 'Electricity — choose your DisCo',
    fieldLabel: 'Meter number',
    icon: Icons.bolt_outlined,
    tint: BocColors.purple,
    items: [
      BillerItem('Ikeja Electric (IKEDC)', 'Lagos — Ikeja & environs'),
      BillerItem('Eko Electricity (EKEDC)', 'Lagos — Eko & environs'),
      BillerItem('Abuja Electricity (AEDC)', 'FCT, Niger, Kogi, Nasarawa'),
      BillerItem('Ibadan Electricity (IBEDC)', 'Oyo, Ogun, Osun, Kwara'),
      BillerItem('Kano Electricity (KEDCO)', 'Kano, Jigawa, Katsina'),
      BillerItem(
        'Port Harcourt Electricity (PHED)',
        'Rivers, Bayelsa, Akwa Ibom, Cross River',
      ),
      BillerItem(
        'Enugu Electricity (EEDC)',
        'Enugu, Anambra, Imo, Abia, Ebonyi',
      ),
      BillerItem('Benin Electricity (BEDC)', 'Edo, Delta, Ondo, Ekiti'),
    ],
  ),
  'water': BillerCategory(
    title: 'Water — choose your provider',
    fieldLabel: 'Account / meter number',
    icon: Icons.water_drop_outlined,
    tint: BocColors.green,
    items: [
      BillerItem('Lagos Water Corporation', 'Lagos State'),
      BillerItem('FCT Water Board', 'Abuja'),
      BillerItem('Rivers State Water Board', 'Port Harcourt'),
      BillerItem('Ogun State Water Corporation', 'Ogun State'),
    ],
  ),
  'cable': BillerCategory(
    title: 'Cable TV — choose provider',
    fieldLabel: 'Smart card / IUC number',
    icon: Icons.tv_outlined,
    tint: BocColors.gold,
    items: [
      BillerItem('DStv', 'MultiChoice satellite TV'),
      BillerItem('GOtv', 'MultiChoice digital terrestrial TV'),
      BillerItem('StarTimes', 'Satellite & digital terrestrial TV'),
      BillerItem('Showmax', 'Streaming subscription'),
    ],
  ),
  'internet': BillerCategory(
    title: 'Internet — choose provider',
    fieldLabel: 'Account / device number',
    icon: Icons.wifi,
    tint: BocColors.blue,
    items: [
      BillerItem('Spectranet', '4G/5G broadband'),
      BillerItem('Smile Communications', '4G LTE broadband'),
      BillerItem('Swift Networks', 'Fixed wireless & fibre'),
      BillerItem('ipNX', 'Fibre broadband'),
      BillerItem('Tizeti (WiFi.com.ng)', 'Solar-powered WiFi'),
      BillerItem('MTN 5G / Home WiFi', 'Mobile broadband router'),
    ],
  ),
  'education': BillerCategory(
    title: 'Education — choose biller',
    fieldLabel: 'Registration / profile number',
    icon: Icons.school_outlined,
    tint: BocColors.purple,
    items: [
      BillerItem('WAEC Result Checker', 'Result checker PIN'),
      BillerItem('NECO', 'Result checker PIN'),
      BillerItem('JAMB (UTME)', 'ePIN & registration'),
      BillerItem('NABTEB', 'Result checker PIN'),
    ],
  ),
  'more': BillerCategory(
    title: 'More services',
    fieldLabel: 'Account / customer ID',
    icon: Icons.receipt_long_outlined,
    tint: BocColors.green,
    items: [
      BillerItem('FRSC', 'Vehicle particulars & fines'),
      BillerItem('NHIS', 'Health insurance premium'),
      BillerItem('Ride-hailing wallet', 'Top up your ride wallet'),
    ],
  ),
};
