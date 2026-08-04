import '../../../data/database_service.dart';
import '../../../models/garment.dart';
import 'garment_reanalysis_service.dart';

class DatabaseGarmentReanalysisRepository implements GarmentReanalysisRepository {
  final DatabaseService database;

  const DatabaseGarmentReanalysisRepository(this.database);

  @override
  Future<Garment?> findById(String id) => database.getGarmentById(id);

  @override
  Future<List<Garment>> findAll() => database.getGarments();

  @override
  Future<void> save(Garment garment) => database.updateGarment(garment);
}
