import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String userName = 'User'; // Fallback
  String userId = 'ID Not Loaded'; // ASHA ID fallback
  String? ashaId; // From Firestore

  // Placeholder data for stats (fetch from Firestore later)
  final int todayVisits = 8;
  final int todayTarget = 12;
  final int weeklyChildren = 23;
  final int pending = 4;
  final double inventoryStock = 85.0;
  final int lowStock = 1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            userName = doc.data()?['username'] ?? user.displayName ?? 'User';
            ashaId = doc.data()?['ashaId'] ?? 'ID Not Set';
            userId = ashaId!; // Use ashaId as government ID
          });
        } else {
          // Fallback to displayName if no doc
          setState(() {
            userName = user.displayName ?? 'User';
            userId = 'ID Not Set';
          });
        }
      } catch (e) {
        // Handle fetch error (e.g., offline)
        setState(() {
          userName = user.displayName ?? 'User';
          userId = 'ID Error: $e';
        });
      }
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    double progressToday = (todayVisits / todayTarget) * 100;
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = screenHeight > 700 ? 1.0 : (screenHeight > 500 ? 0.7 : 0.5); // Tighter scale for tiny screens

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(90 * scale), // Further reduced
        child: AppBar(
          backgroundColor: Colors.teal[700],
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[700]!, Colors.teal[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale), // Minimal
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ASHA Worker Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: Icon(Icons.notifications, color: Colors.white, size: 24 * scale),
                              onPressed: () {},
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '2',
                                  style: TextStyle(color: Colors.white, fontSize: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4 * scale), // Minimal
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12 * scale, // Smaller avatar
                          backgroundColor: Colors.white,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                            style: TextStyle(color: Colors.teal, fontSize: 12 * scale),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName, // Logged-in user's name
                                style: TextStyle(color: Colors.white, fontSize: 14 * scale),
                              ),
                              Text(
                                'ID: $userId', // Government registered ASHA ID from Firestore
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12 * scale),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4 * scale), // Ultra-minimal
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards - Compact
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 2, // Reduced shadow
                      child: Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: Column(
                          children: [
                            Text('Today\'s Visits', style: TextStyle(fontSize: 10 * scale, color: Colors.grey[600])),
                            SizedBox(height: 2 * scale),
                            Text('$todayVisits of $todayTarget', style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4 * scale),
                            LinearProgressIndicator(
                              value: progressToday / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[400]!),
                            ),
                            Text('${progressToday.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10 * scale, color: Colors.teal[600])),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: Column(
                          children: [
                            Icon(Icons.child_care, size: 32 * scale, color: Colors.orange),
                            Text('This Week', style: TextStyle(fontSize: 10 * scale, color: Colors.grey[600])),
                            Text('$weeklyChildren Children', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: Column(
                          children: [
                            Icon(Icons.local_hospital, size: 32 * scale, color: Colors.red),
                            Text('Vaccinations', style: TextStyle(fontSize: 10 * scale, color: Colors.grey[600])),
                            Text('1 Low', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4 * scale),
              // Secondary Cards - Compact
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: Colors.orange[50],
                      child: Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: Column(
                          children: [
                            Icon(Icons.pending_actions, size: 32 * scale, color: Colors.orange),
                            SizedBox(height: 2 * scale),
                            Text('$pending Pending', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: Colors.green[50],
                      child: Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2, size: 32 * scale, color: Colors.green),
                            SizedBox(height: 2 * scale),
                            Text('Inventory Stock', style: TextStyle(fontSize: 10 * scale, color: Colors.grey[600])),
                            Text('${inventoryStock.toStringAsFixed(0)}%', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4 * scale),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      color: Colors.red[50],
                      child: Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: Column(
                          children: [
                            Icon(Icons.warning, size: 32 * scale, color: Colors.red),
                            SizedBox(height: 2 * scale),
                            Text('$lowStock Low Stock', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * scale), // Minimal before actions
              // Quick Actions - Use Wrap for ultimate compactness (no fixed rows)
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4 * scale),
              Wrap(
                spacing: 6 * scale, // Horizontal space
                runSpacing: 4 * scale, // Vertical space between lines (tighter than GridView)
                alignment: WrapAlignment.start,
                children: [
                  _buildCompactActionCard(Icons.add, 'Add Visit', Colors.teal, scale),
                  _buildCompactActionCard(Icons.history, 'Visit Log', Colors.blue, scale),
                  _buildCompactActionCard(Icons.inventory, 'Inventory', Colors.green, scale),
                  _buildCompactActionCard(Icons.bar_chart, 'Reports', Colors.purple, scale),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logout,
        mini: screenHeight < 600, // Smaller FAB on tiny screens
        backgroundColor: Colors.red,
        child: Icon(Icons.logout, color: Colors.white, size: 20 * scale),
      ),
    );
  }

  Widget _buildCompactActionCard(IconData icon, String title, Color color, double scale) { // Added scale parameter
    return Card(
      elevation: 1, // Minimal shadow
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          // Handle tap
        },
        child: Container(
          width: 70 * scale, // Now accessible via parameter
          padding: EdgeInsets.all(4 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20 * scale, color: color),
              SizedBox(height: 2 * scale),
              Text(
                title,
                style: TextStyle(fontSize: 10 * scale, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
