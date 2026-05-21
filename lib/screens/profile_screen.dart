import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/log_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text('Hesabınızı kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await LogService.addLog('Hesap Silme', 'Kullanıcı hesabını kalıcı olarak sildi.');
              Navigator.pop(context);
              Navigator.pop(context);
              await AuthService().deleteAccount();
            },
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
  }

  void _showUpdateStockDialog(BuildContext context, String fuelType, int currentStock) {
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
                    
                await LogService.addLog('Stok Ekleme', '$fuelType için profil ekranından $addedStock Ton stok eklendi.');
                
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        backgroundColor: Colors.blueGrey,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          String role = 'Bilinmiyor';
          if (snapshot.hasData && snapshot.data!.exists) {
            role = snapshot.data!.get('role');
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('E-posta'),
                    subtitle: Text(user?.email ?? ''),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Hesap Türü (Rol)'),
                    subtitle: Text(role),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Toplam Stok Miktarları',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('stocks').snapshots(),
                    builder: (context, stockSnapshot) {
                      if (stockSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final stockDocs = stockSnapshot.data?.docs ?? [];
                      Map<String, int> tempStockMap = {
                        'Linyit Kömür': 0,
                        'İthal Kömür': 0,
                        'Odun': 0,
                        'Briket': 0,
                      };

                      for (var doc in stockDocs) {
                        tempStockMap[doc.id] = doc['quantity'] ?? 0;
                      }

                      return ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: tempStockMap.keys.map((fuelType) {
                          int currentStock = tempStockMap[fuelType] ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(fuelType),
                              subtitle: Text('Mevcut Stok: $currentStock Ton'),
                              trailing: role == 'Toptancı'
                                  ? IconButton(
                                      icon: const Icon(Icons.add_box, color: Colors.orange),
                                      onPressed: () => _showUpdateStockDialog(context, fuelType, currentStock),
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      AuthService().signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Hesaptan Çıkış Yap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirmation(context),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('Hesabımı Kalıcı Olarak Sil', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}