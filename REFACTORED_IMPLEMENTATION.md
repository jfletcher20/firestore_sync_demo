# SWAN Sync Framework - Refactored Implementation

## Overview
SWAN Sync - Synchronization with async negotiation.

### Core Components

1. **ISyncable Interface** (`lib/data/i_syncable.dart`)
   - Dynamic contract for all syncable models
   - Supports unlimited table types
   - Built-in conflict resolution methods
   - Declares server endpoints which need to be defined for each model

2. **TodoModel (example)** (`lib/data/models/todo_model.dart`)
   - Reference implementation of ISyncable
   - Hive-backed local storage
   - Dynamic server endpoints

3. **Communications**
   - `ApiService` - Makes server requests and manages responses
   - `LocalDatabaseService` - ISyncable-aware storage, monitors fallback system
   - `SyncController` - Orchestrates sync operations and FCM handling
   - `Communications` - Manages all commmunications with server
   - `Fallback` - Manages fallback communication logic and


## Key Features

### Dynamic Type System
- **Any table viable**: Any tables are viable by implementing ISyncable

### Robust Sync System
- **Async**: Implements asynchronous synchronization with server
- **Negotiation**: Timestamp-based client-to-client conflict resolution negotiation
- **Free**: Real-time updates via Firebase Cloud Messaging
- **Offline Support**: Local-first with server synchronization

## Benefits

1. **Type Safety**: Compile-time type checking for all models
2. **Scalability**: Add new model types easily
3. **Maintainability**: Clean separation of concerns
4. **Performance**: Efficient conflict resolution and caching via Hive
5. **Developer Experience**: Clear APIs and comprehensive error handling