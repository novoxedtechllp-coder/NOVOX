import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/student_profile_model.dart';

class StudentService {
  final ApiClient apiClient;

  StudentService(this.apiClient);

  Future<StudentProfileModel> getProfile() async {
    final response = await apiClient.dio.get(ApiConstants.studentProfile);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return StudentProfileModel.fromJson(data);
    }
    throw Exception('Invalid student profile response');
  }
}
