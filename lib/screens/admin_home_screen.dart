import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  void _updateOrderStatus(String orderId, String newStatus) async {
    if (newStatus == 'Yola Çıktı') {
      DateTime deliveryDate = DateTime.now().add(const Duration(days: 2));
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'estimatedDelivery': Timestamp.fromDate(deliveryDate),
      });
    } else {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': newStatus});
    }
  }

  void _approveOrder(String orderId, String fuelType, int orderQty, int currentStock) async {
    await FirebaseFirestore.instance
        .collection('stocks')
        .doc(fuelType)
        .set({'quantity': currentStock - orderQty});

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({'status': 'Onaylandı'});
  }

  void _showUpdateStockDialog(String fuelType, int currentStock) {
    final TextEditingController stockController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$fuelType Stoğunu Güncelle'),
          content: TextField(
            controller: stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Eklenecek Miktar (Ton)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                int addedStock = int.tryParse(stockController.text) ?? 0;
                await FirebaseFirestore.instance
                    .collection('stocks')
                    .doc(fuelType)
                    .set({'quantity': currentStock + addedStock});
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toptancı Paneli (Admin)'),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stocks').snapshots(),
        builder: (context, stockSnapshot) {
          if (stockSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, int> stockMap = {};
          if (stockSnapshot.hasData) {
            for (var doc in stockSnapshot.data!.docs) {
              stockMap[doc.id] = (doc.data() as Map<String, dynamic>)['quantity'] ?? 0;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Henüz gelen sipariş yok.'));
              }

              final orders = snapshot.data!.docs;

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final orderDoc = orders[index];
                  final order = orderDoc.data() as Map<String, dynamic>;
                  final orderId = orderDoc.id;
                  final fuelType = order['fuelType'] ?? '';
                  final orderQty = order['quantity'] ?? 0;
                  final currentStock = stockMap[fuelType] ?? 0;
                  
                  bool hasReview = order.containsKey('rating');

                  Color statusColor = Colors.grey.shade200;
                  if (order['status'] == 'Bekliyor') statusColor = Colors.amber.shade200;
                  if (order['status'] == 'Onaylandı') statusColor = Colors.blue.shade200;
                  if (order['status'] == 'Yola Çıktı') statusColor = Colors.purple.shade200;
                  if (order['status'] == 'Teslim Edildi') statusColor = Colors.green.shade200;
                  if (order['status'] == 'Reddedildi' || order['status'] == 'İptal Edildi') statusColor = Colors.red.shade200;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.analytics, color: Colors.redAccent),
                            title: Text('$fuelType - $orderQty Ton'),
                            subtitle: Text('Müşteri: ${order['customerEmail']}\nAdres: ${order['address']}\nMevcut Stok: $currentStock Ton'),
                            trailing: Chip(
                              label: Text(order['status'] ?? ''),
                              backgroundColor: statusColor,
                            ),
                          ),
                          if (hasReview)
                            Container(
                              margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Müşteri Puanı: ${order['rating']}/5\nYorum: "${order['comment']}"',
                                      style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (order['status'] == 'Bekliyor')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _updateOrderStatus(orderId, 'Reddedildi'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reddet'),
                                ),
                                const SizedBox(width: 8),
                                if (currentStock >= orderQty)
                                  ElevatedButton(
                                    onPressed: () => _approveOrder(orderId, fuelType, orderQty, currentStock),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Onayla'),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () => _showUpdateStockDialog(fuelType, currentStock),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Stoğu Güncelle'),
                                  ),
                              ],
                            ),
                          if (order['status'] == 'Onaylandı')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _updateOrderStatus(orderId, 'Yola Çıktı'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Yola Çıkar'),
                                ),
                              ],
                            ),
                          if (order['status'] == 'Yola Çıktı')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _updateOrderStatus(orderId, 'Teslim Edildi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Teslim Edildi İşaretle'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}