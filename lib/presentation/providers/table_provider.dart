import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/table_model.dart';
import '../../services/table_service.dart';
import 'active_branch_provider.dart';

// Provider for TableService
final tableServiceProvider = Provider((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) throw Exception('No active branch selected');
  return TableService(branchId: branchId);
});

// StreamProvider for Tables
final tablesStreamProvider = StreamProvider<List<TableModel>>((ref) {
  final service = ref.watch(tableServiceProvider);
  return service.watchTables();
});

// StreamProvider for a single Table by tableId
final singleTableStreamProvider = StreamProvider.family<TableModel, String>((ref, tableId) {
  final service = ref.watch(tableServiceProvider);
  return service.watchTable(tableId);
});
