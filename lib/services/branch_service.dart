import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/branch_model.dart';

final branchServiceProvider = Provider((ref) => BranchService());

class BranchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateBranchDetails(BranchModel branch) async {
    try {
      await _firestore
          .doc('businesses/coffee_katta/branches/${branch.branchId}')
          .update(branch.toJson());
    } catch (e) {
      throw 'Failed to update branch details: $e';
    }
  }

  Future<void> createBranch(BranchModel branch) async {
    try {
      await _firestore
          .doc('businesses/coffee_katta/branches/${branch.branchId}')
          .set(branch.toJson());
    } catch (e) {
      throw 'Failed to create branch: $e';
    }
  }
}
