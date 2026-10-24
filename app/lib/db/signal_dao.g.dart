// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signal_dao.dart';

// ignore_for_file: type=lint
mixin _$SignalDaoMixin on DatabaseAccessor<AppDatabase> {
  $SignalIdentityTable get signalIdentity => attachedDatabase.signalIdentity;
  $SignalPreKeysTable get signalPreKeys => attachedDatabase.signalPreKeys;
  $SignalSignedPreKeysTable get signalSignedPreKeys =>
      attachedDatabase.signalSignedPreKeys;
  $SignalSessionsTable get signalSessions => attachedDatabase.signalSessions;
  $SignalSenderKeysTable get signalSenderKeys =>
      attachedDatabase.signalSenderKeys;
  $SignalTrustedKeysTable get signalTrustedKeys =>
      attachedDatabase.signalTrustedKeys;
  SignalDaoManager get managers => SignalDaoManager(this);
}

class SignalDaoManager {
  final _$SignalDaoMixin _db;
  SignalDaoManager(this._db);
  $$SignalIdentityTableTableManager get signalIdentity =>
      $$SignalIdentityTableTableManager(
        _db.attachedDatabase,
        _db.signalIdentity,
      );
  $$SignalPreKeysTableTableManager get signalPreKeys =>
      $$SignalPreKeysTableTableManager(_db.attachedDatabase, _db.signalPreKeys);
  $$SignalSignedPreKeysTableTableManager get signalSignedPreKeys =>
      $$SignalSignedPreKeysTableTableManager(
        _db.attachedDatabase,
        _db.signalSignedPreKeys,
      );
  $$SignalSessionsTableTableManager get signalSessions =>
      $$SignalSessionsTableTableManager(
        _db.attachedDatabase,
        _db.signalSessions,
      );
  $$SignalSenderKeysTableTableManager get signalSenderKeys =>
      $$SignalSenderKeysTableTableManager(
        _db.attachedDatabase,
        _db.signalSenderKeys,
      );
  $$SignalTrustedKeysTableTableManager get signalTrustedKeys =>
      $$SignalTrustedKeysTableTableManager(
        _db.attachedDatabase,
        _db.signalTrustedKeys,
      );
}
