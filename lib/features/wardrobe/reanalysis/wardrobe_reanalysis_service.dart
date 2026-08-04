import 'garment_reanalysis_models.dart';
import 'garment_reanalysis_service.dart';
import '../../../models/garment.dart';

class WardrobeReanalysisEstimate {
  final int garments;
  final int aiAnalyses;
  const WardrobeReanalysisEstimate(this.garments, this.aiAnalyses);
}

class WardrobeReanalysisSummary {
  final int total;
  final List<GarmentReanalysisProposal> proposals;
  final Map<String, Object> failures;
  const WardrobeReanalysisSummary({required this.total, required this.proposals, required this.failures});
}

class WardrobeReanalysisService {
  final GarmentReanalysisRepository repository;
  final GarmentReanalysisService reanalysis;
  final ReanalysisCandidatePolicy candidatePolicy;
  final GarmentReanalysisVersions versions;
  const WardrobeReanalysisService({required this.repository, required this.reanalysis, required this.versions, this.candidatePolicy = const ReanalysisCandidatePolicy()});

  Future<WardrobeReanalysisEstimate> estimate({required GarmentReanalysisType type, bool staleOnly = false}) async {
    final selected = await _selected(staleOnly);
    return WardrobeReanalysisEstimate(selected.length, selected.length);
  }

  Future<WardrobeReanalysisSummary> run({required GarmentReanalysisType type, bool staleOnly = false}) async {
    final selected = await _selected(staleOnly);
    final proposals = <GarmentReanalysisProposal>[];
    final failures = <String, Object>{};
    for (final garment in selected) {
      try { proposals.add(await reanalysis.propose(garment.id, type)); } catch (error) { failures[garment.id] = error; }
    }
    return WardrobeReanalysisSummary(total: selected.length, proposals: List.unmodifiable(proposals), failures: Map.unmodifiable(failures));
  }

  Future<List<Garment>> _selected(bool staleOnly) async {
    final garments = await repository.findAll();
    return staleOnly ? garments.where((g) => candidatePolicy.reasons(g, versions).isNotEmpty).toList() : garments;
  }
}
