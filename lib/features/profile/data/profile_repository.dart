import 'models/profile.dart';
import 'profile_api.dart';

class ProfileRepository {
  ProfileRepository(this._profileApi);

  final ProfileApi _profileApi;

  Future<Profile> getProfile() => _profileApi.getProfile();
}
