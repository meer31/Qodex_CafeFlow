import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:cafe_flow/models/sale_session_model.dart';

void main() {
  group('Daily Sale Shift Date Search & Filtering Tests', () {
    final session1 = SaleSessionModel(
      id: 1,
      sessionName: 'Shift 2026-09-25 (Morning)',
      startTime: '2026-09-25T08:00:00',
      endTime: '2026-09-25T16:00:00',
      businessDate: '2026-09-25',
      openingCash: 3000.0,
      cashSales: 15000.0,
      totalSales: 18000.0,
      status: 'CLOSED',
      notes: 'Morning shift with John',
    );

    final session2 = SaleSessionModel(
      id: 2,
      sessionName: 'Shift 2026-09-26 (Evening Cross-Midnight)',
      startTime: '2026-09-26T17:00:00',
      endTime: '2026-09-27T02:30:00',
      businessDate: '2026-09-26',
      openingCash: 5000.0,
      cashSales: 32000.0,
      totalSales: 40000.0,
      status: 'CLOSED',
      notes: 'Busy Friday night',
    );

    final session3 = SaleSessionModel(
      id: 3,
      sessionName: 'Shift 2026-09-27 (Current Live Shift)',
      startTime: '2026-09-27T17:00:00',
      businessDate: '2026-09-27',
      openingCash: 5000.0,
      cashSales: 12000.0,
      totalSales: 15000.0,
      status: 'ACTIVE',
      notes: 'Weekend evening shift',
    );

    final allSessions = [session1, session2, session3];

    // Helper implementing the same search/filtering logic as InvoiceHistoryScreen
    List<SaleSessionModel> filterShifts({
      required List<SaleSessionModel> sessions,
      DateTime? selectedDate,
      String searchQuery = '',
      String statusFilter = 'ALL',
    }) {
      return sessions.where((s) {
        if (statusFilter == 'ACTIVE' && !s.isActive) return false;
        if (statusFilter == 'CLOSED' && !s.isClosed) return false;

        if (selectedDate != null) {
          final targetYmd = DateFormat('yyyy-MM-dd').format(selectedDate);
          final busDateMatches = s.businessDate.trim() == targetYmd;
          final startMatches = s.startTime.startsWith(targetYmd);
          bool parsedMatches = false;
          final parsed = DateTime.tryParse(s.businessDate) ?? DateTime.tryParse(s.startTime);
          if (parsed != null) {
            parsedMatches = parsed.year == selectedDate.year &&
                parsed.month == selectedDate.month &&
                parsed.day == selectedDate.day;
          }
          if (!busDateMatches && !startMatches && !parsedMatches) {
            return false;
          }
        }

        final q = searchQuery.trim().toLowerCase();
        if (q.isNotEmpty) {
          final nameMatch = s.sessionName.toLowerCase().contains(q);
          final dateMatch = s.businessDate.toLowerCase().contains(q);
          final notesMatch = (s.notes ?? '').toLowerCase().contains(q);
          final startMatch = s.startTimeFormatted.toLowerCase().contains(q);
          final endMatch = s.endTimeFormatted.toLowerCase().contains(q);

          bool humanDateMatch = false;
          final parsed = DateTime.tryParse(s.businessDate) ?? DateTime.tryParse(s.startTime);
          if (parsed != null) {
            try {
              final d1 = DateFormat('dd-MM-yyyy').format(parsed).toLowerCase();
              final d2 = DateFormat('dd/MM/yyyy').format(parsed).toLowerCase();
              final d3 = DateFormat('MM/dd/yyyy').format(parsed).toLowerCase();
              final d4 = DateFormat('d MMM yyyy').format(parsed).toLowerCase();
              final d5 = DateFormat('d MMMM yyyy').format(parsed).toLowerCase();
              final d6 = DateFormat('MMMM yyyy').format(parsed).toLowerCase();
              final d7 = DateFormat('EEEE').format(parsed).toLowerCase();
              final d8 = DateFormat('yyyy/MM/dd').format(parsed).toLowerCase();
              if (d1.contains(q) ||
                  d2.contains(q) ||
                  d3.contains(q) ||
                  d4.contains(q) ||
                  d5.contains(q) ||
                  d6.contains(q) ||
                  d7.contains(q) ||
                  d8.contains(q)) {
                humanDateMatch = true;
              }
            } catch (_) {}
          }

          if (!nameMatch && !dateMatch && !notesMatch && !startMatch && !endMatch && !humanDateMatch) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    test('Filter by selected date finds the exact matching shift', () {
      final results = filterShifts(
        sessions: allSessions,
        selectedDate: DateTime(2026, 9, 26),
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals(2));
      expect(results.first.businessDate, equals('2026-09-26'));
    });

    test('Search by date string "2026-09-27" matches the shift on that date', () {
      final results = filterShifts(
        sessions: allSessions,
        searchQuery: '2026-09-27',
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals(3));
    });

    test('Search by human date format "26 Sep" or "September" matches shifts in September', () {
      final resultsSep26 = filterShifts(
        sessions: allSessions,
        searchQuery: '26 Sep',
      );
      expect(resultsSep26.length, equals(1));
      expect(resultsSep26.first.id, equals(2));

      final resultsSepAll = filterShifts(
        sessions: allSessions,
        searchQuery: 'September',
      );
      expect(resultsSepAll.length, equals(3));
    });

    test('Search by slash date format "25/09/2026" matches correctly', () {
      final results = filterShifts(
        sessions: allSessions,
        searchQuery: '25/09/2026',
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals(1));
    });

    test('Search by shift notes or cashier name works seamlessly', () {
      final resultsJohn = filterShifts(
        sessions: allSessions,
        searchQuery: 'John',
      );
      expect(resultsJohn.length, equals(1));
      expect(resultsJohn.first.id, equals(1));

      // 'Friday' matches Session 1 (since 2026-09-25 is Friday) and Session 2 (notes has 'Friday')
      final resultsFriday = filterShifts(
        sessions: allSessions,
        searchQuery: 'Friday',
      );
      expect(resultsFriday.length, equals(2));

      // 'Busy' is only in Session 2 notes
      final resultsBusy = filterShifts(
        sessions: allSessions,
        searchQuery: 'Busy',
      );
      expect(resultsBusy.length, equals(1));
      expect(resultsBusy.first.id, equals(2));
    });

    test('Combined filter: Date and Status filters narrow down correctly', () {
      // 2026-09-27 is ACTIVE
      final activeOn27th = filterShifts(
        sessions: allSessions,
        selectedDate: DateTime(2026, 9, 27),
        statusFilter: 'ACTIVE',
      );
      expect(activeOn27th.length, equals(1));

      // CLOSED on 2026-09-27 returns empty
      final closedOn27th = filterShifts(
        sessions: allSessions,
        selectedDate: DateTime(2026, 9, 27),
        statusFilter: 'CLOSED',
      );
      expect(closedOn27th.isEmpty, isTrue);
    });

    test('Resetting date and search returns all shifts', () {
      final all = filterShifts(
        sessions: allSessions,
        selectedDate: null,
        searchQuery: '',
        statusFilter: 'ALL',
      );
      expect(all.length, equals(3));
    });
  });
}
