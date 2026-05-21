import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _selectedFuelType = 'Linyit Kömür';

  void _showOrderDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Sipariş Oluştur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedFuelType,
                items: ['Linyit Kömür', 'İthal Kömür', 'Odun', 'Briket']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedFuelType = val!),
                decoration: const InputDecoration(labelText: 'Yakıt Türü'),
              ),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Miktar (Ton)'),
              ),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Teslimat Adresi'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: _submitOrder,
              child: const Text('Sipariş Ver'),
            ),
          ],
        );
      },
    );
  }

  void _submitOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final int requestedQty = int.tryParse(_quantityController.text) ?? 0;

    final stockDoc = await FirebaseFirestore.instance.collection('stocks').doc(_selectedFuelType).get();
    int currentStock = 0;
    if (stockDoc.exists) {
      currentStock = stockDoc.data()?['quantity'] ?? 0;
    }

    if (requestedQty > currentStock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hata: Yetersiz stok! Stok miktarından fazla sipariş verilemez.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    await FirebaseFirestore.instance.collection('orders').add({
      'customerId': user.uid,
      'customerEmail': user.email,
      'fuelType': _selectedFuelType,
      'quantity': requestedQty,
      'address': _addressController.text,
      'status': 'Bekliyor',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _quantityController.clear();
    _addressController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _cancelOrder(String orderId) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({'status': 'İptal Edildi'});
  }

  void _showReviewDialog(String orderId) {
    int selectedRating = 5;
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Siparişi Değerlendir'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedRating,
                    items: [1, 2, 3, 4, 5]
                        .map((rating) => DropdownMenuItem(value: rating, child: Text('$rating Yıldız')))
                        .toList(),
                    onChanged: (val) => setState(() => selectedRating = val!),
                    decoration: const InputDecoration(labelText: 'Puanınız'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Yorumunuz',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                      'rating': selectedRating,
                      'comment': commentController.text.trim(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDeliveryDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri Paneli'),
        backgroundColor: Colors.orange,
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
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz siparişiniz bulunmuyor.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderDoc = orders[index];
              final order = orderDoc.data() as Map<String, dynamic>;
              final orderId = orderDoc.id;

              Color statusColor = Colors.grey.shade200;
              if (order['status'] == 'Bekliyor') statusColor = Colors.amber.shade200;
              if (order['status'] == 'Onaylandı') statusColor = Colors.blue.shade200;
              if (order['status'] == 'Yola Çıktı') statusColor = Colors.purple.shade200;
              if (order['status'] == 'Teslim Edildi') statusColor = Colors.green.shade200;
              if (order['status'] == 'Reddedildi' || order['status'] == 'İptal Edildi') statusColor = Colors.red.shade200;

              String subtitleText = 'Adres: ${order['address']}';
              if (order['status'] == 'Yola Çıktı' && order['estimatedDelivery'] != null) {
                subtitleText += '\nTahmini Teslimat (2 Gün İçinde): ${_formatDeliveryDate(order['estimatedDelivery'])}';
              }

              bool hasReview = order.containsKey('rating');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.local_shipping, color: Colors.orange),
                      title: Text('${order['fuelType']} - ${order['quantity']} Ton'),
                      subtitle: Text(subtitleText),
                      trailing: Chip(
                        label: Text(order['status'] ?? ''),
                        backgroundColor: statusColor,
                      ),
                    ),
                    if (order['status'] == 'Bekliyor')
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _cancelOrder(orderId),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Siparişi İptal Et'),
                          ),
                        ),
                      ),
                    if (order['status'] == 'Teslim Edildi' && !hasReview)
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReviewDialog(orderId),
                            icon: const Icon(Icons.star, color: Colors.orange),
                            label: const Text('Siparişi Değerlendir', style: TextStyle(color: Colors.orange)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                          ),
                        ),
                      ),
                    if (hasReview)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${order['rating']}/5 - ${order['comment']}',
                                  style: TextStyle(color: Colors.orange.shade900, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: _showOrderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}