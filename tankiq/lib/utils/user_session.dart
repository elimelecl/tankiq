class UserSession {
  // Temporary hardcoded superuser state until a full auth system is implemented
  static bool isSuperUser = true;

  // Function to toggle superuser status for testing
  static void toggleSuperUser() {
    isSuperUser = !isSuperUser;
  }
}
