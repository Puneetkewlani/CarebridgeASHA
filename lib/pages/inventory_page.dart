import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryPage extends StatefulWidget {
  final String ashaId;

  const InventoryPage({super.key, required this.ashaId});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, int> localStock = {};
  bool isRefreshing = false;
  bool isLoading = true;

  static const int maxStock = 50;
  final List<String> vaccines = [
    'BCG', 'OPV-0', 'Hep B-0',
    'OPV-1', 'Pentavalent-1', 'Rotavirus-1', 'PCV-1',
    'OPV-2', 'Pentavalent-2', 'Rotavirus-2', 'PCV-2',
    'OPV-3', 'Pentavalent-3', 'Rotavirus-3', 'PCV-3', 'IPV-1',
    'Measles-1', 'JE-1',
    'DPT Booster-1', 'OPV Booster', 'Measles-2', 'JE-2',
  ];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => isLoading = true);
    try {
      final doc =
          await _firestore.collection('inventory').doc(widget.ashaId).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data() ?? {});
        setState(() {
          localStock = {};
          for (var vaccine in vaccines) {
            final stock =
                (data[vaccine] as int? ?? 0).clamp(0, maxStock);
            localStock[vaccine] = stock;
          }
          isLoading = false;
        });
      } else {
        await _firestore
            .collection('inventory')
            .doc(widget.ashaId)
            .set({for (var v in vaccines) v: maxStock}, SetOptions(merge: true));
        await _loadInventory();
      }
    } catch (e) {
      print('Inventory error: $e');
      setState(() {
        localStock = {for (var v in vaccines) v: 25};
        isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    await _loadInventory();
    setState(() => isRefreshing = false);
  }

  // ✅ NEW: Reset Inventory Method
  Future<void> _resetInventory() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset Inventory'),
      content: const Text(
        'Are you sure you want to reset all vaccines to 50 units?\n\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Reset', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      // Create update map with all vaccines set to 50
      Map<String, dynamic> resetData = {};
      for (var vaccine in vaccines) {
        resetData[vaccine] = maxStock;
      }

      // Use widget.ashaId (the document ID for this inventory)
      await _firestore.collection('inventory').doc(widget.ashaId).update(resetData);

      // Refresh local state
      await _loadInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Inventory reset to 50 units for all vaccines'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


  Future<void> _editStock(String vaccine, int current) async {
    final controller = TextEditingController(text: current.toString());
    final newStock = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $vaccine Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'New Stock (Max $maxStock)',
                helperText: 'Enter 0-$maxStock doses',
                helperStyle:
                    const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text ?? '');
              if (value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Invalid number'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              if (value > maxStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Max $maxStock doses per vaccine'),
                      backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(context, value.clamp(0, maxStock));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newStock != null) {
      final clampedStock = newStock.clamp(0, maxStock);
      setState(() => localStock[vaccine] = clampedStock);
      try {
        await _firestore
            .collection('inventory')
            .doc(widget.ashaId)
            .update({vaccine: clampedStock});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Stock updated'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Updated locally'),
                backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  

  @override
  Widget build(BuildContext context) {
    int totalStock = localStock.values
        .map((s) => s.clamp(0, maxStock))
        .fold(0, (sum, stock) => sum + stock);
    final totalPercent =
        (totalStock / (vaccines.length * maxStock) * 100).clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Vaccine Inventory'),
        backgroundColor: Colors.green,
      ),
      // ✅ NEW: Added FloatingActionButton for Reset
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _resetInventory,
        backgroundColor: Colors.orange,
        label: const Text('Reset to 50'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green[50],
                  child: Column(
                    children: [
                      const Text(
                        'Overall Inventory Level',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (totalPercent / 100),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                        backgroundColor: Colors.grey[300],
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                          '${totalPercent.toStringAsFixed(1)}% ($totalStock/${vaccines.length * maxStock} doses)'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: vaccines.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final vaccine = vaccines[index];
                      final stock =
                          (localStock[vaccine] ?? 0).clamp(0, maxStock);
                      final percent =
                          (stock / maxStock * 100).clamp(0.0, 100.0);
                      Color barColor = stock == 0
                          ? Colors.red
                          : stock >= maxStock
                              ? Colors.green
                              : stock < 20
                                  ? Colors.orange
                                  : Colors.lightGreen;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: barColor,
                          child: Text('$stock',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(vaccine,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '$stock/$maxStock doses\n${percent.toStringAsFixed(0)}% available'),
                        trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(
      width: 80,
      child: LinearProgressIndicator(
        value: (percent / 100),
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    ),
    IconButton(
      icon: const Icon(Icons.edit, color: Colors.blue),
      onPressed: () => _editStock(vaccine, stock),
    ),
  ],
),

                        onTap: () => _editStock(vaccine, stock),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
