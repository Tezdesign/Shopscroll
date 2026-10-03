import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_text_field.dart';

/// One country's international dialling prefix, behind the flag + caret
/// [PhoneField] draws (Figma component set 5290:7177 shows the caret but no
/// picker frame, so the sheet below is this app's own design).
///
/// [flag] is derived from [isoCode] rather than stored: a two letter code
/// maps to its flag emoji by shifting each letter into the Unicode regional
/// indicator block, which is exactly how every flag emoji is composed.
class CountryDialCode {
  const CountryDialCode(this.isoCode, this.dialCode, this.name);

  /// ISO 3166-1 alpha-2, e.g. `US`.
  final String isoCode;

  /// E.164 prefix including the leading `+`, e.g. `+1`.
  final String dialCode;
  final String name;

  String get flag => String.fromCharCodes([
    for (final unit in isoCode.codeUnits) 0x1F1E6 + unit - 0x41,
  ]);

  /// The most digits a national number can have here: E.164 caps a whole
  /// number at [_maxE164Digits], country code included, so a long prefix
  /// leaves room for fewer.
  int get maxNationalDigits => _maxE164Digits - (dialCode.length - 1);

  /// Whether [digits] could be a national number for this country. This is
  /// a length check against the E.164 range, not a per country numbering
  /// plan: Clerk does the real validation when it tries to text the number,
  /// and this only catches an obviously incomplete entry before the round
  /// trip.
  bool isPlausibleNationalNumber(String digits) =>
      digits.length >= _minNationalDigits && digits.length <= maxNationalDigits;

  /// Whether this country matches a picker search for [query], by name, ISO
  /// code or dial code (with or without the `+` the user may not type).
  bool matches(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return true;
    return name.toLowerCase().contains(term) ||
        isoCode.toLowerCase().startsWith(term) ||
        dialCode.contains(term) ||
        dialCode.substring(1).startsWith(term);
  }

  @override
  bool operator ==(Object other) =>
      other is CountryDialCode &&
      other.isoCode == isoCode &&
      other.dialCode == dialCode;

  @override
  int get hashCode => Object.hash(isoCode, dialCode);
}

/// E.164 allows at most 15 digits in a full number, country code included.
const _maxE164Digits = 15;

/// The shortest national numbers in use anywhere (Niue, St. Helena and a few
/// other small plans) are 4 digits, so nothing shorter is worth sending.
const _minNationalDigits = 4;

/// What [PhoneField] starts on, matching the "+1" the Figma frames show.
const defaultCountryDialCode = CountryDialCode('US', '+1', 'United States');

/// Opens the country picker and resolves to the chosen country, or null if
/// it is dismissed.
Future<CountryDialCode?> showCountryDialCodePicker(
  BuildContext context, {
  CountryDialCode? selected,
}) {
  return showModalBottomSheet<CountryDialCode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
    ),
    builder: (context) => _CountryDialCodeSheet(selected: selected),
  );
}

class _CountryDialCodeSheet extends StatefulWidget {
  const _CountryDialCodeSheet({this.selected});

  final CountryDialCode? selected;

  @override
  State<_CountryDialCodeSheet> createState() => _CountryDialCodeSheetState();
}

class _CountryDialCodeSheetState extends State<_CountryDialCodeSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = countryDialCodes
        .where((country) => country.matches(_query))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Country',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.neutral1100,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _searchController,
                    hintText: 'Search',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No country matches "${_query.trim()}".',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final country = matches[index];
                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: AppSpacing.xl),
                          ),
                          title: Text(
                            country.name,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.neutral1100,
                            ),
                          ),
                          trailing: Text(
                            country.dialCode,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.neutral500,
                            ),
                          ),
                          selected: country == widget.selected,
                          selectedTileColor: AppColors.neutral200,
                          onTap: () => Navigator.of(context).pop(country),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ISO 3166-1 countries with their E.164 prefixes, sorted by name so the
/// picker can show them in order without sorting at build time. Territories
/// sharing a prefix (the +1 North American plan, +7, +44 crown dependencies)
/// are listed separately so people can find their own country by name.
const countryDialCodes = <CountryDialCode>[
  CountryDialCode('AF', '+93', 'Afghanistan'),
  CountryDialCode('AL', '+355', 'Albania'),
  CountryDialCode('DZ', '+213', 'Algeria'),
  CountryDialCode('AS', '+1', 'American Samoa'),
  CountryDialCode('AD', '+376', 'Andorra'),
  CountryDialCode('AO', '+244', 'Angola'),
  CountryDialCode('AI', '+1', 'Anguilla'),
  CountryDialCode('AG', '+1', 'Antigua and Barbuda'),
  CountryDialCode('AR', '+54', 'Argentina'),
  CountryDialCode('AM', '+374', 'Armenia'),
  CountryDialCode('AW', '+297', 'Aruba'),
  CountryDialCode('AU', '+61', 'Australia'),
  CountryDialCode('AT', '+43', 'Austria'),
  CountryDialCode('AZ', '+994', 'Azerbaijan'),
  CountryDialCode('BS', '+1', 'Bahamas'),
  CountryDialCode('BH', '+973', 'Bahrain'),
  CountryDialCode('BD', '+880', 'Bangladesh'),
  CountryDialCode('BB', '+1', 'Barbados'),
  CountryDialCode('BY', '+375', 'Belarus'),
  CountryDialCode('BE', '+32', 'Belgium'),
  CountryDialCode('BZ', '+501', 'Belize'),
  CountryDialCode('BJ', '+229', 'Benin'),
  CountryDialCode('BM', '+1', 'Bermuda'),
  CountryDialCode('BT', '+975', 'Bhutan'),
  CountryDialCode('BO', '+591', 'Bolivia'),
  CountryDialCode('BA', '+387', 'Bosnia and Herzegovina'),
  CountryDialCode('BW', '+267', 'Botswana'),
  CountryDialCode('BR', '+55', 'Brazil'),
  CountryDialCode('IO', '+246', 'British Indian Ocean Territory'),
  CountryDialCode('VG', '+1', 'British Virgin Islands'),
  CountryDialCode('BN', '+673', 'Brunei'),
  CountryDialCode('BG', '+359', 'Bulgaria'),
  CountryDialCode('BF', '+226', 'Burkina Faso'),
  CountryDialCode('BI', '+257', 'Burundi'),
  CountryDialCode('KH', '+855', 'Cambodia'),
  CountryDialCode('CM', '+237', 'Cameroon'),
  CountryDialCode('CA', '+1', 'Canada'),
  CountryDialCode('CV', '+238', 'Cape Verde'),
  CountryDialCode('KY', '+1', 'Cayman Islands'),
  CountryDialCode('CF', '+236', 'Central African Republic'),
  CountryDialCode('TD', '+235', 'Chad'),
  CountryDialCode('CL', '+56', 'Chile'),
  CountryDialCode('CN', '+86', 'China'),
  CountryDialCode('CO', '+57', 'Colombia'),
  CountryDialCode('KM', '+269', 'Comoros'),
  CountryDialCode('CG', '+242', 'Congo - Brazzaville'),
  CountryDialCode('CD', '+243', 'Congo - Kinshasa'),
  CountryDialCode('CK', '+682', 'Cook Islands'),
  CountryDialCode('CR', '+506', 'Costa Rica'),
  CountryDialCode('CI', '+225', 'Côte d’Ivoire'),
  CountryDialCode('HR', '+385', 'Croatia'),
  CountryDialCode('CU', '+53', 'Cuba'),
  CountryDialCode('CW', '+599', 'Curaçao'),
  CountryDialCode('CY', '+357', 'Cyprus'),
  CountryDialCode('CZ', '+420', 'Czechia'),
  CountryDialCode('DK', '+45', 'Denmark'),
  CountryDialCode('DJ', '+253', 'Djibouti'),
  CountryDialCode('DM', '+1', 'Dominica'),
  CountryDialCode('DO', '+1', 'Dominican Republic'),
  CountryDialCode('EC', '+593', 'Ecuador'),
  CountryDialCode('EG', '+20', 'Egypt'),
  CountryDialCode('SV', '+503', 'El Salvador'),
  CountryDialCode('GQ', '+240', 'Equatorial Guinea'),
  CountryDialCode('ER', '+291', 'Eritrea'),
  CountryDialCode('EE', '+372', 'Estonia'),
  CountryDialCode('SZ', '+268', 'Eswatini'),
  CountryDialCode('ET', '+251', 'Ethiopia'),
  CountryDialCode('FK', '+500', 'Falkland Islands'),
  CountryDialCode('FO', '+298', 'Faroe Islands'),
  CountryDialCode('FJ', '+679', 'Fiji'),
  CountryDialCode('FI', '+358', 'Finland'),
  CountryDialCode('FR', '+33', 'France'),
  CountryDialCode('GF', '+594', 'French Guiana'),
  CountryDialCode('PF', '+689', 'French Polynesia'),
  CountryDialCode('GA', '+241', 'Gabon'),
  CountryDialCode('GM', '+220', 'Gambia'),
  CountryDialCode('GE', '+995', 'Georgia'),
  CountryDialCode('DE', '+49', 'Germany'),
  CountryDialCode('GH', '+233', 'Ghana'),
  CountryDialCode('GI', '+350', 'Gibraltar'),
  CountryDialCode('GR', '+30', 'Greece'),
  CountryDialCode('GL', '+299', 'Greenland'),
  CountryDialCode('GD', '+1', 'Grenada'),
  CountryDialCode('GP', '+590', 'Guadeloupe'),
  CountryDialCode('GU', '+1', 'Guam'),
  CountryDialCode('GT', '+502', 'Guatemala'),
  CountryDialCode('GG', '+44', 'Guernsey'),
  CountryDialCode('GN', '+224', 'Guinea'),
  CountryDialCode('GW', '+245', 'Guinea-Bissau'),
  CountryDialCode('GY', '+592', 'Guyana'),
  CountryDialCode('HT', '+509', 'Haiti'),
  CountryDialCode('HN', '+504', 'Honduras'),
  CountryDialCode('HK', '+852', 'Hong Kong SAR China'),
  CountryDialCode('HU', '+36', 'Hungary'),
  CountryDialCode('IS', '+354', 'Iceland'),
  CountryDialCode('IN', '+91', 'India'),
  CountryDialCode('ID', '+62', 'Indonesia'),
  CountryDialCode('IR', '+98', 'Iran'),
  CountryDialCode('IQ', '+964', 'Iraq'),
  CountryDialCode('IE', '+353', 'Ireland'),
  CountryDialCode('IM', '+44', 'Isle of Man'),
  CountryDialCode('IL', '+972', 'Israel'),
  CountryDialCode('IT', '+39', 'Italy'),
  CountryDialCode('JM', '+1', 'Jamaica'),
  CountryDialCode('JP', '+81', 'Japan'),
  CountryDialCode('JE', '+44', 'Jersey'),
  CountryDialCode('JO', '+962', 'Jordan'),
  CountryDialCode('KZ', '+7', 'Kazakhstan'),
  CountryDialCode('KE', '+254', 'Kenya'),
  CountryDialCode('KI', '+686', 'Kiribati'),
  CountryDialCode('XK', '+383', 'Kosovo'),
  CountryDialCode('KW', '+965', 'Kuwait'),
  CountryDialCode('KG', '+996', 'Kyrgyzstan'),
  CountryDialCode('LA', '+856', 'Laos'),
  CountryDialCode('LV', '+371', 'Latvia'),
  CountryDialCode('LB', '+961', 'Lebanon'),
  CountryDialCode('LS', '+266', 'Lesotho'),
  CountryDialCode('LR', '+231', 'Liberia'),
  CountryDialCode('LY', '+218', 'Libya'),
  CountryDialCode('LI', '+423', 'Liechtenstein'),
  CountryDialCode('LT', '+370', 'Lithuania'),
  CountryDialCode('LU', '+352', 'Luxembourg'),
  CountryDialCode('MO', '+853', 'Macao SAR China'),
  CountryDialCode('MG', '+261', 'Madagascar'),
  CountryDialCode('MW', '+265', 'Malawi'),
  CountryDialCode('MY', '+60', 'Malaysia'),
  CountryDialCode('MV', '+960', 'Maldives'),
  CountryDialCode('ML', '+223', 'Mali'),
  CountryDialCode('MT', '+356', 'Malta'),
  CountryDialCode('MH', '+692', 'Marshall Islands'),
  CountryDialCode('MQ', '+596', 'Martinique'),
  CountryDialCode('MR', '+222', 'Mauritania'),
  CountryDialCode('MU', '+230', 'Mauritius'),
  CountryDialCode('YT', '+262', 'Mayotte'),
  CountryDialCode('MX', '+52', 'Mexico'),
  CountryDialCode('FM', '+691', 'Micronesia'),
  CountryDialCode('MD', '+373', 'Moldova'),
  CountryDialCode('MC', '+377', 'Monaco'),
  CountryDialCode('MN', '+976', 'Mongolia'),
  CountryDialCode('ME', '+382', 'Montenegro'),
  CountryDialCode('MS', '+1', 'Montserrat'),
  CountryDialCode('MA', '+212', 'Morocco'),
  CountryDialCode('MZ', '+258', 'Mozambique'),
  CountryDialCode('MM', '+95', 'Myanmar'),
  CountryDialCode('NA', '+264', 'Namibia'),
  CountryDialCode('NR', '+674', 'Nauru'),
  CountryDialCode('NP', '+977', 'Nepal'),
  CountryDialCode('NL', '+31', 'Netherlands'),
  CountryDialCode('NC', '+687', 'New Caledonia'),
  CountryDialCode('NZ', '+64', 'New Zealand'),
  CountryDialCode('NI', '+505', 'Nicaragua'),
  CountryDialCode('NE', '+227', 'Niger'),
  CountryDialCode('NG', '+234', 'Nigeria'),
  CountryDialCode('NU', '+683', 'Niue'),
  CountryDialCode('NF', '+672', 'Norfolk Island'),
  CountryDialCode('KP', '+850', 'North Korea'),
  CountryDialCode('MK', '+389', 'North Macedonia'),
  CountryDialCode('MP', '+1', 'Northern Mariana Islands'),
  CountryDialCode('NO', '+47', 'Norway'),
  CountryDialCode('OM', '+968', 'Oman'),
  CountryDialCode('PK', '+92', 'Pakistan'),
  CountryDialCode('PW', '+680', 'Palau'),
  CountryDialCode('PS', '+970', 'Palestinian Territories'),
  CountryDialCode('PA', '+507', 'Panama'),
  CountryDialCode('PG', '+675', 'Papua New Guinea'),
  CountryDialCode('PY', '+595', 'Paraguay'),
  CountryDialCode('PE', '+51', 'Peru'),
  CountryDialCode('PH', '+63', 'Philippines'),
  CountryDialCode('PL', '+48', 'Poland'),
  CountryDialCode('PT', '+351', 'Portugal'),
  CountryDialCode('PR', '+1', 'Puerto Rico'),
  CountryDialCode('QA', '+974', 'Qatar'),
  CountryDialCode('RE', '+262', 'Réunion'),
  CountryDialCode('RO', '+40', 'Romania'),
  CountryDialCode('RU', '+7', 'Russia'),
  CountryDialCode('RW', '+250', 'Rwanda'),
  CountryDialCode('WS', '+685', 'Samoa'),
  CountryDialCode('SM', '+378', 'San Marino'),
  CountryDialCode('ST', '+239', 'São Tomé and Príncipe'),
  CountryDialCode('SA', '+966', 'Saudi Arabia'),
  CountryDialCode('SN', '+221', 'Senegal'),
  CountryDialCode('RS', '+381', 'Serbia'),
  CountryDialCode('SC', '+248', 'Seychelles'),
  CountryDialCode('SL', '+232', 'Sierra Leone'),
  CountryDialCode('SG', '+65', 'Singapore'),
  CountryDialCode('SX', '+1', 'Sint Maarten'),
  CountryDialCode('SK', '+421', 'Slovakia'),
  CountryDialCode('SI', '+386', 'Slovenia'),
  CountryDialCode('SB', '+677', 'Solomon Islands'),
  CountryDialCode('SO', '+252', 'Somalia'),
  CountryDialCode('ZA', '+27', 'South Africa'),
  CountryDialCode('KR', '+82', 'South Korea'),
  CountryDialCode('SS', '+211', 'South Sudan'),
  CountryDialCode('ES', '+34', 'Spain'),
  CountryDialCode('LK', '+94', 'Sri Lanka'),
  CountryDialCode('BL', '+590', 'St. Barthélemy'),
  CountryDialCode('SH', '+290', 'St. Helena'),
  CountryDialCode('KN', '+1', 'St. Kitts and Nevis'),
  CountryDialCode('LC', '+1', 'St. Lucia'),
  CountryDialCode('MF', '+590', 'St. Martin'),
  CountryDialCode('PM', '+508', 'St. Pierre and Miquelon'),
  CountryDialCode('VC', '+1', 'St. Vincent and Grenadines'),
  CountryDialCode('SD', '+249', 'Sudan'),
  CountryDialCode('SR', '+597', 'Suriname'),
  CountryDialCode('SE', '+46', 'Sweden'),
  CountryDialCode('CH', '+41', 'Switzerland'),
  CountryDialCode('SY', '+963', 'Syria'),
  CountryDialCode('TW', '+886', 'Taiwan'),
  CountryDialCode('TJ', '+992', 'Tajikistan'),
  CountryDialCode('TZ', '+255', 'Tanzania'),
  CountryDialCode('TH', '+66', 'Thailand'),
  CountryDialCode('TL', '+670', 'Timor-Leste'),
  CountryDialCode('TG', '+228', 'Togo'),
  CountryDialCode('TK', '+690', 'Tokelau'),
  CountryDialCode('TO', '+676', 'Tonga'),
  CountryDialCode('TT', '+1', 'Trinidad and Tobago'),
  CountryDialCode('TN', '+216', 'Tunisia'),
  CountryDialCode('TR', '+90', 'Türkiye'),
  CountryDialCode('TM', '+993', 'Turkmenistan'),
  CountryDialCode('TC', '+1', 'Turks and Caicos Islands'),
  CountryDialCode('TV', '+688', 'Tuvalu'),
  CountryDialCode('UG', '+256', 'Uganda'),
  CountryDialCode('UA', '+380', 'Ukraine'),
  CountryDialCode('AE', '+971', 'United Arab Emirates'),
  CountryDialCode('GB', '+44', 'United Kingdom'),
  defaultCountryDialCode,
  CountryDialCode('UY', '+598', 'Uruguay'),
  CountryDialCode('VI', '+1', 'US Virgin Islands'),
  CountryDialCode('UZ', '+998', 'Uzbekistan'),
  CountryDialCode('VU', '+678', 'Vanuatu'),
  CountryDialCode('VA', '+39', 'Vatican City'),
  CountryDialCode('VE', '+58', 'Venezuela'),
  CountryDialCode('VN', '+84', 'Vietnam'),
  CountryDialCode('WF', '+681', 'Wallis and Futuna'),
  CountryDialCode('EH', '+212', 'Western Sahara'),
  CountryDialCode('YE', '+967', 'Yemen'),
  CountryDialCode('ZM', '+260', 'Zambia'),
  CountryDialCode('ZW', '+263', 'Zimbabwe'),
];
