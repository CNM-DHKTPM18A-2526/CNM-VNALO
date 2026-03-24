class ApiResponse<T> {
  final bool success;
  final String? code;
  final String message;
  final T? data;

  ApiResponse({
    required this.success,
    this.code,
    required this.message,
    this.data,
  });

  // Factory constructor to create an ApiResponse from JSON,
  // with an optional fromData function to parse the data field.
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      code: json['code'],
      message: json['message'] ?? '',
      data:
          json['data'] != null && fromData != null
              ? fromData(json['data'])
              : null,
    );
  }
}
