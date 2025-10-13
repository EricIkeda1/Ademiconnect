import 'package:cloud_firestore/cloud_firestore.dart';

class Consultor {
  final String uid;
  final String nome;

  Consultor({required this.uid, required this.nome});
}

class ConsultorService {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Consultor>> getConsultoresByGestor(String gestorUid) async {
    final snapshot = await _firestore
        .collection('consultores')
        .where('gestorId', isEqualTo: gestorUid)
        .get();

    return snapshot.docs
        .map((doc) => Consultor(
              uid: doc.id,
              nome: doc.get('nome') ?? 'Sem nome',
            ))
        .toList();
  }
}
