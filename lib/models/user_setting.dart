class UserSetting {
  final String key;
  final String value;

  UserSetting({required this.key, required this.value});

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }

  factory UserSetting.fromMap(Map<String, dynamic> map) {
    return UserSetting(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }
}