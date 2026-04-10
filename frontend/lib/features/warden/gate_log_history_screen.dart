import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/api/api_client.dart';

class GateLogHistoryScreen extends StatefulWidget {
  const GateLogHistoryScreen({super.key});

  @override
  State<GateLogHistoryScreen> createState() => _GateLogHistoryScreenState();
}

class _GateLogHistoryScreenState extends State<GateLogHistoryScreen> {
  bool _isToday = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedGender = "All";
  String _selectedDept = "All";
  
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      String path = "/warden/gate-logs";
      String queryParams = "";
      
      if (!_isToday) {
        queryParams += "date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}&";
      } else {
         queryParams += "date=${DateFormat('yyyy-MM-dd').format(DateTime.now())}&";
      }
      
      if (_selectedGender != "All") queryParams += "gender=$_selectedGender&";
      if (_selectedDept != "All") queryParams += "dept=$_selectedDept&";
      
      final res = await ApiClient.get("$path?$queryParams");
      if (mounted) {
        setState(() {
          _logs = (res as List? ) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int entries = _logs.where((e) => e['Action'] == 'entry').length;
    int exits = _logs.where((e) => e['Action'] == 'exit').length;
    int uniqueStudents = _logs.map((e) => e['stu_id']).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Gate Log History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2D5AF0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildFilters(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(entries, exits, uniqueStudents),
                  const SizedBox(height: 32),
                  _buildHeaderRow(),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_logs.isEmpty)
                    const Center(child: Text("No records found for the selected filters."))
                  else
                    ..._logs.map((log) => _buildLogItem(log)).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton("Today's History", _isToday, () {
              setState(() {
                _isToday = true;
                _fetchLogs();
              });
            }),
          ),
          Expanded(
            child: _tabButton("Custom History", !_isToday, () {
              setState(() {
                _isToday = false;
                _fetchLogs();
              });
            }),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text("Filters", style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _dropdownFilter("Gender", _selectedGender, ["All", "Male", "Female"], (v) {
                  setState(() => _selectedGender = v!);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _dropdownFilter("Department", _selectedDept, ["All", "CS", "BTech", "BCA", "MTech"], (v) {
                  setState(() => _selectedDept = v!);
                }),
              ),
            ],
          ),
          if (!_isToday) ...[
            const SizedBox(height: 16),
            _datePickerFilter(),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _fetchLogs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Apply Filters"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownFilter(String label, String value, List<String> items, ValueChanged<String?>? onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _datePickerFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Date", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(DateFormat('dd-MM-yyyy').format(_selectedDate)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(int entries, int exits, int unique) {
    return Row(
      children: [
        _sumCard("Total Entries", entries.toString(), Colors.green, Icons.check_circle_outline),
        const SizedBox(width: 12),
        _sumCard("Total Exits", exits.toString(), Colors.orange, Icons.cancel_outlined),
        const SizedBox(width: 12),
        _sumCard("Total Records", _logs.length.toString(), Colors.blue, Icons.assignment_outlined),
        const SizedBox(width: 12),
        _sumCard("Unique Students", unique.toString(), Colors.purple, Icons.person_outline),
      ],
    );
  }

  Widget _sumCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        const Icon(Icons.assignment_rounded, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Text(_isToday ? "Today's Records" : "Custom Date Records", style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          child: Text("${_logs.length} Records", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildLogItem(dynamic log) {
    final bool isEntry = log['Action'] == 'entry';
    final student = log['Student'] ?? {};
    final DateTime? ts = log['Timestamp'] != null ? DateTime.parse(log['Timestamp']) : null;
    final String time = ts != null ? DateFormat('hh:mm a').format(ts.toLocal())! : "N/A";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEntry ? Colors.green.withOpacity(0.03) : Colors.orange.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEntry ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isEntry ? Colors.green : Colors.orange).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isEntry ? Icons.check_circle_outline : Icons.cancel_outlined, color: isEntry ? Colors.green : Colors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(student['Name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text(student['AU_id'] ?? "N/A", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 12),
                    const Icon(Icons.meeting_room_outlined, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("Main Gate", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEntry ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isEntry ? "Entry" : "Exit",
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
