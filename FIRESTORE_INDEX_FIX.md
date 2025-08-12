# Firestore Index Fix Guide

## Issue
The app is experiencing a "FAILED_PRECONDITION" error when querying messages because Firestore requires a composite index for queries that use `array-contains` with `orderBy`.

## Quick Fix (Recommended)

### Option 1: Click the Error Link
1. In the console error, click the provided link that starts with:
   ```
   https://console.firebase.google.com/v1/r/project/hellome-846e9/firestore/indexes?create_composite=...
   ```
2. This will take you directly to the Firebase Console with the index pre-configured
3. Click "Create Index"
4. Wait 2-5 minutes for the index to build

### Option 2: Manual Index Creation
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (hellome-846e9)
3. Navigate to Firestore Database → Indexes
4. Click "Create Index"
5. Configure as follows:
   - Collection ID: `messages`
   - Fields to index:
     - Field path: `participants` → Array contains
     - Field path: `timestamp` → Descending
   - Query scope: Collection
6. Click "Create"

### Option 3: Deploy via Firebase CLI
1. Install Firebase CLI if not already installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Initialize Firebase in your project:
   ```bash
   firebase init firestore
   ```

3. The `firestore.indexes.json` file has been created with the required indexes

4. Deploy the indexes:
   ```bash
   firebase deploy --only firestore:indexes
   ```

## Required Indexes

The app needs these composite indexes for the messages collection:

1. **Main Message Query Index**
   - participants (Array contains)
   - timestamp (Descending)

2. **Unread Message Count Index**
   - senderId (Ascending)
   - recipientId (Ascending)
   - read (Ascending)
   - isDeleted (Ascending)

3. **Message History Index**
   - senderId (Ascending)
   - recipientId (Ascending)
   - timestamp (Descending)

## Verification

After creating the indexes:
1. Wait 2-5 minutes for indexes to build
2. Restart the app
3. The error should be resolved and messages should load properly

## Note
- Index creation is a one-time setup
- Indexes are automatically maintained by Firestore
- No code changes are required in the app 