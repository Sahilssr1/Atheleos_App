import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/sports_service.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

class SportSelectorField extends StatefulWidget {
  final String? initialSport;
  final ValueChanged<String> onSportChanged;
  final String hintText;

  const SportSelectorField({
    super.key,
    this.initialSport,
    required this.onSportChanged,
    this.hintText = 'Select Sport',
  });

  @override
  State<SportSelectorField> createState() => _SportSelectorFieldState();
}

class _SportSelectorFieldState extends State<SportSelectorField> {
  late String? _selectedSport;
  bool _isOtherSelected = false;
  final TextEditingController _otherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSelection(widget.initialSport);
  }

  void _initSelection(String? sport) {
    _selectedSport = sport;
    if (_selectedSport != null && _selectedSport!.isNotEmpty) {
      if (!SportsService.supportedSports.contains(_selectedSport)) {
        _isOtherSelected = true;
        _otherController.text = _selectedSport!;
        _selectedSport = 'Other';
      } else {
        _isOtherSelected = false;
      }
    }
  }

  @override
  void didUpdateWidget(covariant SportSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSport != oldWidget.initialSport) {
      _initSelection(widget.initialSport);
    }
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _showSportSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626), width: 1),
      ),
      builder: (context) => _SportBottomSheet(
        selectedSport: _isOtherSelected ? 'Other' : _selectedSport,
        onSelected: (sport, [customSport]) {
          setState(() {
            _selectedSport = sport;
            if (sport == 'Other') {
              _isOtherSelected = true;
              if (customSport != null && customSport.isNotEmpty) {
                _otherController.text = customSport;
                widget.onSportChanged(customSport);
              } else {
                widget.onSportChanged(_otherController.text.trim());
              }
            } else {
              _isOtherSelected = false;
              widget.onSportChanged(sport);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _isOtherSelected
        ? (_otherController.text.trim().isNotEmpty
            ? _otherController.text.trim()
            : 'Other (Custom Sport)')
        : ((_selectedSport == null || _selectedSport!.isEmpty)
            ? widget.hintText
            : _selectedSport!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _showSportSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626), width: 1),
            ),
            child: Row(
              children: [
                const Icon(AthIcons.trophy, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: GoogleFonts.outfit(
                      color: (_selectedSport == null || _selectedSport!.isEmpty)
                          ? Colors.white38
                          : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(AthIcons.chevronDown, color: Colors.white54),
              ],
            ),
          ),
        ),
        if (_isOtherSelected) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _otherController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Custom Sport Name',
              hintText: 'e.g. Pickleball, Kho-Kho, Roller Hockey...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(AthIcons.pencilSquare, color: AppTheme.primaryColor, size: 16),
              filled: true,
              fillColor: const Color(0xFF141414),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF262626), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF262626), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {});
              widget.onSportChanged(val.trim());
            },
          ),
        ],
      ],
    );
  }
}

class _SportBottomSheet extends StatefulWidget {
  final String? selectedSport;
  final void Function(String sport, [String? customSport]) onSelected;

  const _SportBottomSheet({
    this.selectedSport,
    required this.onSelected,
  });

  @override
  State<_SportBottomSheet> createState() => _SportBottomSheetState();
}

class _SportBottomSheetState extends State<_SportBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<String> _filteredSports = [];

  @override
  void initState() {
    super.initState();
    _filteredSports = SportsService.getSports();
    // Pre-select category if selectedSport belongs to one
    if (widget.selectedSport != null && widget.selectedSport!.isNotEmpty && widget.selectedSport != 'Other') {
      for (final cat in SportsService.getCategories()) {
        final sportsInCat = SportsService.getSportsForCategory(cat);
        if (sportsInCat.contains(widget.selectedSport)) {
          _selectedCategory = cat;
          _filteredSports = sportsInCat;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    List<String> baseList;
    if (_selectedCategory == 'All') {
      baseList = SportsService.getSports();
    } else {
      baseList = SportsService.getSportsForCategory(_selectedCategory);
      if (baseList.isEmpty) {
        baseList = SportsService.getSports();
      }
    }

    setState(() {
      if (query.isEmpty) {
        _filteredSports = baseList;
      } else {
        _filteredSports = baseList
            .where((s) => s.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _onCategorySelected(String cat) {
    setState(() {
      _selectedCategory = cat;
    });
    _filter();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final showCustomPrompt = query.isNotEmpty &&
        !_filteredSports.any((s) => s.toLowerCase() == query.toLowerCase());
    final categories = ['All', ...SportsService.getCategories()];

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Sport & Category',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_filteredSports.length} sports',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filter(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search sport...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(AthIcons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF181818),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626), width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          // Category selector chips
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = categories[idx];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => _onCategorySelected(cat),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: const Color(0xFF181818),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : const Color(0xFF2E2E2E),
                    width: 1,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSports.length + (showCustomPrompt ? 2 : 1),
              itemBuilder: (context, index) {
                // If user typed a sport not in standard list, show quick-add banner at the top
                if (showCustomPrompt && index == 0) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(AthIcons.plusCircle, color: AppTheme.primaryColor),
                      title: Text(
                        'Add "$query"',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Tap to set as custom sport',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      trailing: const Icon(AthIcons.chevronRight, size: 14, color: AppTheme.primaryColor),
                      onTap: () {
                        widget.onSelected('Other', query);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }

                final effectiveIndex = showCustomPrompt ? index - 1 : index;

                // Last item is always "Other (Type custom)"
                if (effectiveIndex == _filteredSports.length) {
                  final isSelected = widget.selectedSport == 'Other';
                  return ListTile(
                    leading: Icon(
                      AthIcons.pencilSquare,
                      color: isSelected ? AppTheme.primaryColor : Colors.white54,
                    ),
                    title: Text(
                      'Other (Type custom)',
                      style: GoogleFonts.outfit(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: const Text(
                      'Enter any sport not listed above',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    trailing: isSelected ? const Icon(AthIcons.check, color: AppTheme.primaryColor) : null,
                    onTap: () {
                      widget.onSelected('Other', query.isNotEmpty ? query : null);
                      Navigator.pop(context);
                    },
                  );
                }

                final sport = _filteredSports[effectiveIndex];
                final isSelected = sport == widget.selectedSport;

                return ListTile(
                  leading: Icon(
                    AthIcons.trophy,
                    color: isSelected ? AppTheme.primaryColor : Colors.white54,
                  ),
                  title: Text(
                    sport,
                    style: GoogleFonts.outfit(
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? const Icon(AthIcons.check, color: AppTheme.primaryColor) : null,
                  onTap: () {
                    widget.onSelected(sport);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
