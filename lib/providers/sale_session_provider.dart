import 'package:flutter/foundation.dart';
import '../models/sale_session_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';
import '../repositories/sale_session_repository.dart';

class SaleSessionProvider extends ChangeNotifier {
  final SaleSessionRepository _repository = SaleSessionRepository();

  SaleSessionModel? _activeSession;
  List<SaleSessionModel> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  SaleSessionModel? get activeSession => _activeSession;
  bool get isSessionActive => _activeSession != null;
  List<SaleSessionModel> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SaleSessionProvider() {
    loadSessions();
  }

  /// Loads both the currently active shift session and historical shifts
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeSession = await _repository.getActiveSession();
      _sessions = await _repository.getAllSessions();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load sale sessions: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Starts a new sale shift session with opening counter cash float
  Future<SaleSessionModel> startSaleSession(
    double openingCash, {
    String? notes,
    DateTime? startTime,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newSession = await _repository.startSession(
        openingCash: openingCash,
        notes: notes,
        startTime: startTime,
      );
      _activeSession = newSession;
      await loadSessions();
      return newSession;
    } catch (e) {
      _errorMessage = 'Failed to start sale session: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Ends and finalizes the active sale shift session
  Future<SaleSessionModel> endSaleSession({
    double? closingCash,
    String? notes,
  }) async {
    if (_activeSession == null || _activeSession!.id == null) {
      throw Exception('No active sale session to close.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final closedSession = await _repository.endSession(
        sessionId: _activeSession!.id!,
        closingCash: closingCash,
        notes: notes,
      );
      _activeSession = null;
      await loadSessions();
      return closedSession;
    } catch (e) {
      _errorMessage = 'Failed to end sale session: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Refreshes running totals (sales, cash, expenses) for the active session
  Future<void> refreshActiveSessionFinancials() async {
    if (_activeSession == null || _activeSession!.id == null) return;

    try {
      final updated = await _repository.recalculateSessionFinancials(_activeSession!.id!);
      if (updated != null) {
        _activeSession = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Fetches all sales/invoices for a given shift session
  Future<List<SaleModel>> getSessionInvoices(int sessionId) async {
    return await _repository.getSessionInvoices(sessionId);
  }

  /// Fetches all expenses for a given shift session
  Future<List<ExpenseModel>> getSessionExpenses(int sessionId) async {
    return await _repository.getSessionExpenses(sessionId);
  }

  /// Fetches aggregated selling items breakdown for a shift session
  Future<List<SessionSoldItem>> getSessionSoldItems(int sessionId) async {
    return await _repository.getSessionSoldItems(sessionId);
  }

  /// Fetches stock intake, consumption, and products breakdown for a shift session
  Future<List<SessionStockReportItem>> getSessionStockReport(int sessionId) async {
    return await _repository.getSessionStockReport(sessionId);
  }
}
