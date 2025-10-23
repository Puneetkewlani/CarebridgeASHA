import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PHCInventoryOverview extends StatefulWidget {
  final String location;

  const PHCInventoryOverview({super.key, required this.location});

  @override
  State<PHCInventoryOverview> createState() => _PHCInventoryOverviewState();
}

class _PHCInventoryOverviewState extends State<PHCInventoryOverview> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, Map<String, int>> inventoryData = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  Future<void> _loadInventoryData() async {
    setState(() => isLoading = true);

    try {
      // Get all ASHA workers in this location
      final ashaSnapshot = await _firestore
          .collection('users')
          .where('location', isEqualTo: widget.location)
          .where('role', isEqualTo: 'ASHA')
          .get();

      Map<String, Map<String, int>> data = {};

      for (var doc in ashaSnapshot.docs) {
        final ashaId = doc.data()['ashaId'];
        final ashaName = doc.data()['fullName'];

        final invDoc = await _firestore.collection('inventory').doc(ashaId).get();
        
        if (invDoc.exists) {
          final stock = Map<String, int>.from(
            invDoc.data()!.map((k, v) => MapEntry(k, v is int ? v : 0))
          );
          data[ashaName] = stock;
        }
      }

      setState(() {
        inventoryData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading inventory: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Inventory Overview'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
       
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : inventoryData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No inventory data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: inventoryData.length,
                  itemBuilder: (context, index) {
                    final ashaName = inventoryData.keys.elementAt(index);
                    final stock = inventoryData[ashaName]!;
                    final totalStock = stock.values.fold(0, (sum, val) => sum + val);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: totalStock > 20 ? Colors.green : Colors.orange,
                          child: Text(
                            ashaName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          ashaName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Total: $totalStock units'),
                        children: stock.entries.map((entry) {
                          final color = entry.value > 10
                              ? Colors.green
                              : entry.value > 5
                                  ? Colors.orange
                                  : Colors.red;

                          return ListTile(
                            leading: Icon(Icons.vaccines, color: color, size: 20),
                            title: Text(entry.key),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color),
                              ),
                              child: Text(
                                '${entry.value}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
    );
  }
}
