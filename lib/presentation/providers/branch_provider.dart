import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/branch_model.dart';

import './active_branch_provider.dart';

final branchProvider = StreamProvider<BranchModel>((ref) {
  final activeBranchId = ref.watch(activeBranchIdProvider);
  if (activeBranchId == null) {
     throw Exception('No active branch selected');
  }
  final branchPath = 'businesses/coffee_katta/branches/$activeBranchId';
  
  return FirebaseFirestore.instance
      .doc(branchPath)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) {
      throw Exception('Branch data not found for ID: $activeBranchId');
    }
    return BranchModel.fromJson(snapshot.data()!);
  });
});

final allBranchesProvider = StreamProvider<List<BranchModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('businesses/coffee_katta/branches')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data['branchId'] == null || data['branchId'].toString().isEmpty) {
              data['branchId'] = doc.id;
            }
            if (data['branchName'] == null || data['branchName'].toString().isEmpty) {
              data['branchName'] = doc.id.toUpperCase();
            }
            return BranchModel.fromJson(data);
          })
          .toList());
});
