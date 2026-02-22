import 'package:url_inbox/main.dart';

void main() async {
  print('Testing Threads Metadata Fetching...');
  try {
    final meta = await Metadata.fetch('https://www.threads.net/@devfoil/post/DFa-h-jS6-w?xmt=AQGzzA7F5uYt3DqQ5w6s8YvC8h8uC2mX8E7aK_8Rz1gMtw');
    print('Title: ${meta.title}');
    print('Description: ${meta.description}');
    print('Image: ${meta.image}');
    print('Profile Image: ${meta.profileImage}');
    print('Body Media URLs: ${meta.mediaUrls}');
  } catch (e) {
    print('Error: $e');
  }
}
