import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/activity_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import 'manage_categories_screen.dart';
import 'manage_labels_screen.dart';
import 'manage_excluded_days_screen.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _exportBackupFile(BuildContext context) async {
    try {
      final provider = Provider.of<ActivityProvider>(context, listen: false);
      final file = await provider.exportBackupToFile();

      if (!context.mounted) return;

      final fileName = file.path.split('/').last.split('\\').last;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved to: $fileName'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () {
              Share.shareXFiles(
                [XFile(file.path)],
                text: 'Life Tracker Backup File',
              );
            },
          ),
          backgroundColor: const Color(0xFF188038),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _importBackupFromFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (!context.mounted) return;

        final provider = Provider.of<ActivityProvider>(context, listen: false);
        final count = await provider.importBackupFromFilePath(filePath);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully restored $count records from file!'),
              backgroundColor: const Color(0xFF188038),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore from file failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGoogleConsentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_circle, color: Color(0xFF4285F4), size: 24),
            SizedBox(width: 8),
            Text('Google Privacy & Terms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By signing in with Google, you authorize Life Tracker to access your Google account name, email address, and profile photo for cloud data synchronization.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            SizedBox(height: 12),
            Text(
              'By continuing, you agree to Life Tracker\'s Terms of Service and Google\'s Privacy Policy.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final user = await AuthService.instance.signInWithGoogle();
                if (user != null && context.mounted) {
                  final provider =
                      Provider.of<ActivityProvider>(context, listen: false);
                  await FirebaseService.instance
                      .pullCloudFirestoreToLocal(isAccountSwitch: true);
                  await provider.fetchCategories();
                  await provider.fetchActivities();
                  setState(() {});
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Welcome, ${user.displayName}! Google Cloud Sync active.'),
                      backgroundColor: const Color(0xFF188038),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Google Play Services unavailable on this device. Switching to Account Sign In.'),
                      backgroundColor: Colors.orange.shade800,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _showEmailSignInDialog(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
            ),
            child: const Text('Agree & Continue'),
          ),
        ],
      ),
    );
  }

  void _showEmailSignInDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isSignUp ? 'Create New Account' : 'Account Sign In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignUp
                    ? 'Register a new account with your email and password (minimum 6 characters):'
                    : 'Enter your registered email and password to sign in:',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: '••••••••',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        isSignUp = !isSignUp;
                      });
                    },
                    child: Text(
                      isSignUp
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Sign Up",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text;

                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter both email and password'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final user = isSignUp
                      ? await AuthService.instance.signUp(email, password)
                      : await AuthService.instance.signIn(email, password);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    final provider =
                        Provider.of<ActivityProvider>(context, listen: false);
                    await FirebaseService.instance
                        .pullCloudFirestoreToLocal(isAccountSwitch: true);
                    await provider.fetchCategories();
                    await provider.fetchActivities();
                    setState(() {});
                    if (!context.mounted) return;
                    final snackMsg = isSignUp
                        ? 'Account created! Firebase verification email sent to $email.'
                        : 'Welcome, ${user.displayName}! Cloud sync enabled.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(snackMsg),
                        backgroundColor: const Color(0xFF188038),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  final errorMsg = e.toString().replaceAll('Exception: ', '');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(errorMsg),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
              ),
              child: Text(isSignUp ? 'Sign Up' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              'ACCOUNT & CLOUD SYNC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: AuthService.instance.isSignedIn
                ? ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F0FE),
                      backgroundImage:
                          AuthService.instance.currentUser?.photoUrl != null
                              ? NetworkImage(
                                  AuthService.instance.currentUser!.photoUrl!)
                              : null,
                      child: AuthService.instance.currentUser?.photoUrl == null
                          ? const Icon(Icons.account_circle,
                              color: Color(0xFF1A73E8), size: 24)
                          : null,
                    ),
                    title: Text(
                      AuthService.instance.currentUser!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      AuthService.instance.currentUser!.email,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        await AuthService.instance.signOut();
                        if (context.mounted) {
                          final provider = Provider.of<ActivityProvider>(context, listen: false);
                          await provider.fetchCategories();
                          await provider.fetchActivities();
                        }
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child:
                          const Text('Sign Out', style: TextStyle(fontSize: 12)),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_sync_outlined,
                                color: Color(0xFF1A73E8), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Account Authentication',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose an option to sign in and enable unified Cloud Sync across devices:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showGoogleConsentDialog(context),
                                icon: const Icon(Icons.g_mobiledata, size: 22),
                                label: const Text('Sign in with Google',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4285F4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showEmailSignInDialog(context),
                                icon: const Icon(Icons.email_outlined,
                                    size: 16),
                                label: const Text('Sign in with Email',
                                    style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1A73E8),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '* By signing in, you agree to Life Tracker\'s Terms of Service and Google\'s Privacy Policy.',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              'DATA BACKUP & RESTORE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE6F4EA),
                child: Icon(Icons.drive_folder_upload,
                    color: Color(0xFF188038), size: 22),
              ),
              title: const Text('Export Backup File',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Save .json backup file directly to Downloads',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => _exportBackupFile(context),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF7E0),
                child: Icon(Icons.file_open,
                    color: Color(0xFFF9AB00), size: 22),
              ),
              title: const Text('Restore From File',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Pick a .json backup file from phone storage to restore',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => _importBackupFromFile(context),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Text(
              'APP CONFIGURATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F0FE),
                    child: Icon(Icons.category_outlined,
                        color: Color(0xFF1A73E8), size: 22),
                  ),
                  title: const Text('Manage Categories',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Add, edit icons, or change category colors',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageCategoriesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F0FE),
                    child: Icon(Icons.label_outlined,
                        color: Color(0xFF1A73E8), size: 22),
                  ),
                  title: const Text('Manage Labels',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Create Spendee-style tags with emojis & colors',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageLabelsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFCE8E6),
                    child: Icon(Icons.event_busy_outlined,
                        color: Color(0xFFD93025), size: 22),
                  ),
                  title: const Text('Excluded Days (Untracked)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Exclude forgotten days from daily average calculations',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageExcludedDaysScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}