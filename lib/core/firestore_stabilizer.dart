import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

extension FirestoreStableSnapshot on Query {
  /// Provides a stable stream of snapshots.
  /// On Windows, it uses polling (periodic get()) to avoid native threading crashes
  /// inherent in the Firestore C++ SDK snapshot listeners.
  /// On other platforms, it uses the standard snapshots() listener.
  Stream<QuerySnapshot> snapshotsStable({
    bool includeMetadataChanges = false,
    Duration pollingInterval = const Duration(seconds: 10),
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return snapshots(includeMetadataChanges: includeMetadataChanges);
    }

    // Windows Stability Path: Use Polling
    debugPrint('Using Stable Firestore Polling for Windows Query');
    
    // Create a controller to manage the periodic fetches
    late StreamController<QuerySnapshot> controller;
    Timer? timer;

    Future<void> fetchData() async {
      try {
        final snapshot = await get();
        if (!controller.isClosed) {
          controller.add(snapshot);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
        debugPrint('Stable Polling Error: $e');
      }
    }

    controller = StreamController<QuerySnapshot>(
      onListen: () {
        // Initial fetch
        fetchData();
        // Setup periodic timer
        timer = Timer.periodic(pollingInterval, (_) => fetchData());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}

extension FirestoreStableDocumentSnapshot on DocumentReference {
  /// Provides a stable stream of snapshots for a document.
  Stream<DocumentSnapshot> snapshotsStable({
    bool includeMetadataChanges = false,
    Duration pollingInterval = const Duration(seconds: 10),
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return snapshots(includeMetadataChanges: includeMetadataChanges);
    }

    // Windows Stability Path: Use Polling
    debugPrint('Using Stable Firestore Polling for Windows Doc: $path');
    
    late StreamController<DocumentSnapshot> controller;
    Timer? timer;

    Future<void> fetchData() async {
      try {
        final snapshot = await get();
        if (!controller.isClosed) {
          controller.add(snapshot);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<DocumentSnapshot>(
      onListen: () {
        fetchData();
        timer = Timer.periodic(pollingInterval, (_) => fetchData());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}
