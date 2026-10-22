// Firebase Web app "Go4Foodies Admin" (project go4foodies). These are public client identifiers;
// access is enforced by Firestore rules and the api function, not by keeping them secret.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyCG7iF3w3lfWeqst7DWHF8FeA6Spw_kxMQ',
    appId: '1:497211081386:web:302f45d6580d2936e586d3',
    messagingSenderId: '497211081386',
    projectId: 'go4foodies',
    authDomain: 'go4foodies.firebaseapp.com',
    storageBucket: 'go4foodies.firebasestorage.app',
  );
}
