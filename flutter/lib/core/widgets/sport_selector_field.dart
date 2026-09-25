import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/sports_service.dart';

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
    _selectedSport = widget.initialSport;
    if (_selectedSport != null && _selectedSport!.isNotEmpty) {
      if (!SportsService.supportedSports.contains(_selectedSport)) {
        _isOtherSelected = true;
        _otherController.text = _selectedSport!;
        _selectedSport = 'Other';
      }
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
        selectedSport: _selectedSport,
        onSelected: (sport) {
          setState(() {
            _selectedSport = sport;
            if (sport == 'Other') {
              _isOtherSelected = true;
              widget.onSportChanged(_otherController.text.trim());
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _showSportSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.show_chart, color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (_selectedSport == null || _selectedSport!.isEmpty) 
                        ? widget.hintText 
                        : _selectedSport!,
                    style: GoogleFonts.inter(
                      color: (_selectedSport == null || _selectedSport!.isEmpty) ? Colors.white38 : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54),
              ],
            ),
          ),
        ),
        if (_isOtherSelected) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _otherController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type your custom sport...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.edit, color: AppTheme.primaryColor, size: 16),
              filled: true,
              fillColor: const Color(0xFF121212),
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
  final ValueChanged<String> onSelected;

  const _SportBottomSheet({
    this.selectedSport,
    required this.onSelected,
  });

  @override
  State<_SportBottomSheet> createState() => _SportBottomSheetState();
}

class _SportBottomSheetState extends State<_SportBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredSports = [];

  @override
  void initState() {
    super.initState();
    _filteredSports = SportsService.supportedSports;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSports = SportsService.supportedSports;
      } else {
        _filteredSports = SportsService.supportedSports
            .where((s) => s.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search sport...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
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
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSports.length + 1, // +1 for Other
              itemBuilder: (context, index) {
                if (index == _filteredSports.length) {
                  final isSelected = widget.selectedSport == 'Other';
                  return ListTile(
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: isSelected ? AppTheme.primaryColor : Colors.white54,
                    ),
                    title: Text(
                      'Other (Type custom)',
                      style: GoogleFonts.inter(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                    onTap: () {
                      widget.onSelected('Other');
                      Navigator.pop(context);
                    },
                  );
                }

                final sport = _filteredSports[index];
                final isSelected = sport == widget.selectedSport;

                return ListTile(
                  leading: Icon(
                    Icons.sports,
                    color: isSelected ? AppTheme.primaryColor : Colors.white54,
                  ),
                  title: Text(
                    sport,
                    style: GoogleFonts.inter(
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
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
