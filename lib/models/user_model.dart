// ─────────────────────────────────────────────────────────────────
// UserModel
//
// What this file does:
//   Represents a user in your app. Converts data between your app
//   and Firestore. Every user saved in Firebase looks like this.
//
// Why we need it:
//   Instead of passing raw Map<String,dynamic> data everywhere,
//   we use a clean typed object. Safer, easier to read, less bugs.
// ─────────────────────────────────────────────────────────────────

class UserModel {
  final String uid;       // Unique ID from Firebase Auth
  final String name;      // Display name
  final String email;     // Email address
  final String photoUrl;  // Profile picture URL (empty if email signup)
  final String provider;  // How they signed in: 'email' or 'google'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.provider,
  });

  // Firestore data (Map) → UserModel object
  // Used when reading user data from Firestore
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid:      map['uid']      ?? '',
      name:     map['name']     ?? '',
      email:    map['email']    ?? '',
      photoUrl: map['photoUrl'] ?? '',
      provider: map['provider'] ?? '',
    );
  }

  // UserModel object → Map
  // Used when saving user data to Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid':      uid,
      'name':     name,
      'email':    email,
      'photoUrl': photoUrl,
      'provider': provider,
    };
  }

  // Creates a copy with some fields changed
  // Used when you want to update just one field without changing others
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? provider,
  }) {
    return UserModel(
      uid:      uid      ?? this.uid,
      name:     name     ?? this.name,
      email:    email    ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
    );
  }

  // Useful for debugging — print(user) shows readable info
  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, provider: $provider)';
  }
}