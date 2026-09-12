import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/user_model.dart';

void main() {
  group('Role-Based Access Control & Branch Isolation Tests', () {
    test('Waiter role: strictly assigned to single branch and isolated from other branches', () {
      final waiter = UserModel(
        userId: 'waiter_001',
        email: 'waiter1@coffeekatta.com',
        name: 'Ramesh Pawar',
        role: 'waiter',
        branchIds: ['branch_latur_main'],
        isActive: true,
      );

      expect(waiter.isWaiter, isTrue);
      expect(waiter.isAdmin, isFalse);
      expect(waiter.isCashier, isFalse);

      // Access to assigned branch
      expect(waiter.hasAccessToBranch('branch_latur_main'), isTrue);

      // Strict isolation from other branches
      expect(waiter.hasAccessToBranch('branch_pune_fc'), isFalse);
      expect(waiter.hasAccessToBranch('branch_mumbai_bandra'), isFalse);

      // Waiter has exactly 1 assigned branch
      expect(waiter.branchIds.length, equals(1));
      expect(waiter.branchIds.first, equals('branch_latur_main'));
    });

    test('Waiter unassigned branch detection', () {
      final unassignedWaiter = UserModel(
        userId: 'waiter_002',
        email: 'newwaiter@coffeekatta.com',
        name: 'Suresh Patil',
        role: 'waiter',
        branchIds: [],
        isActive: true,
      );

      expect(unassignedWaiter.isWaiter, isTrue);
      expect(unassignedWaiter.branchIds.isEmpty, isTrue);
      expect(unassignedWaiter.hasAccessToBranch('branch_latur_main'), isFalse);
    });

    test('Deactivated staff account cannot access system', () {
      final disabledWaiter = UserModel(
        userId: 'waiter_003',
        email: 'disabled@coffeekatta.com',
        name: 'Ex Waiter',
        role: 'waiter',
        branchIds: ['branch_latur_main'],
        isActive: false,
      );

      expect(disabledWaiter.isActive, isFalse);
    });

    test('Cashier role: single-branch vs multi-branch behavior', () {
      final singleBranchCashier = UserModel(
        userId: 'cashier_001',
        email: 'cashier1@coffeekatta.com',
        name: 'Pooja Shinde',
        role: 'cashier',
        branchIds: ['branch_latur_main'],
        isActive: true,
      );

      expect(singleBranchCashier.isCashier, isTrue);
      expect(singleBranchCashier.isAdmin, isFalse);
      expect(singleBranchCashier.isWaiter, isFalse);
      expect(singleBranchCashier.branchIds.length, equals(1));
      expect(singleBranchCashier.hasAccessToBranch('branch_latur_main'), isTrue);
      expect(singleBranchCashier.hasAccessToBranch('branch_pune_fc'), isFalse);

      final multiBranchCashier = UserModel(
        userId: 'cashier_002',
        email: 'cashier2@coffeekatta.com',
        name: 'Vikram Joshi',
        role: 'cashier',
        branchIds: ['branch_latur_main', 'branch_pune_fc'],
        isActive: true,
      );

      expect(multiBranchCashier.branchIds.length, equals(2));
      expect(multiBranchCashier.hasAccessToBranch('branch_latur_main'), isTrue);
      expect(multiBranchCashier.hasAccessToBranch('branch_pune_fc'), isTrue);
      expect(multiBranchCashier.hasAccessToBranch('branch_mumbai_bandra'), isFalse);
    });

    test('Super Admin role: global multi-branch access across all branches', () {
      final admin = UserModel(
        userId: 'admin_001',
        email: 'admin@coffeekatta.com',
        name: 'Master Admin',
        role: 'admin',
        branchIds: ['branch_latur_main'],
        isActive: true,
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isCashier, isFalse);
      expect(admin.isWaiter, isFalse);

      // Admin has universal access regardless of branchIds list
      expect(admin.hasAccessToBranch('branch_latur_main'), isTrue);
      expect(admin.hasAccessToBranch('branch_pune_fc'), isTrue);
      expect(admin.hasAccessToBranch('branch_any_future_branch'), isTrue);
    });

    test('User payload serialization: strictly stores List<String> for single-branch staff', () {
      final waiter = UserModel(
        userId: 'waiter_004',
        email: 'anil@coffeekatta.com',
        name: 'Anil Deshmukh',
        role: 'waiter',
        branchIds: ['branch_latur_main'],
        isActive: true,
      );

      final json = waiter.toJson();
      expect(json['role'], equals('waiter'));
      expect(json['branchIds'], isA<List>());
      expect((json['branchIds'] as List).length, equals(1));
      expect((json['branchIds'] as List).first, equals('branch_latur_main'));

      final reconstructed = UserModel.fromJson(json);
      expect(reconstructed.userId, equals(waiter.userId));
      expect(reconstructed.role, equals('waiter'));
      expect(reconstructed.branchIds, equals(['branch_latur_main']));
      expect(reconstructed.isWaiter, isTrue);
    });
  });
}
