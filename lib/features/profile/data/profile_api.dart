import '../../../core/network/graphql_client.dart';
import 'models/profile.dart';

class ProfileApi {
  ProfileApi(this._client);

  final GraphQLClient _client;

  Future<Profile> getProfile() async {
    final data = await _client.query('''
      query { profile { id email phone fullName gender dateOfBirth address avatarUrl school { id name } roles { name code } } }
    ''');
    return Profile.fromJson(data['profile'] as Map<String, dynamic>);
  }
}
