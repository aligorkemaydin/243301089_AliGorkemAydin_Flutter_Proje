import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

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

    await FirebaseFirestore.instance.collection('orders').add({
      'customerId': user.uid,
      'customerEmail': user.email,
      'fuelType': _selectedFuelType,
      'quantity': int.tryParse(_quantityController.text) ?? 0,
      'address': _addressController.text,
      'status': 'Bekliyor',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _quantityController.clear();
    _addressController.clear();
    if (mounted) Navigator.pop(context);
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
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
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
              final order = orders[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.local_shipping, color: Colors.orange),
                  title: Text('${order['fuelType']} - ${order['quantity']} Ton'),
                  subtitle: Text('Adres: ${order['address']}'),
                  trailing: Chip(
                    label: Text(order['status'] ?? ''),
                    backgroundColor: order['status'] == 'Bekliyor' 
                        ? Colors.amber.shade200 
                        : Colors.green.shade200,
                  ),
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