import 'dart:convert';
import '../assistant/ai/llm_provider.dart';
import '../../models/personal_style.dart';

class StyleEnrichmentService {
  final LlmProvider provider;
  const StyleEnrichmentService(this.provider);
  Future<PersonalStyle> propose(PersonalStyle current) async {
    final response = await provider.generate('''Propose un enrichissement éditorial du style suivant. Réponds uniquement en JSON avec description, notes, examples, characteristics, colors, materials, occasions et typicalPieces (listes de chaînes). Ne change ni id ni nom. Style: ${jsonEncode(current.toMap())}''');
    final clean = response.replaceAll(RegExp(r'^```(?:json)?|```$', multiLine: true), '').trim();
    final map = Map<String, Object?>.from(jsonDecode(clean) as Map);
    List<String> list(String key) => (map[key] as List? ?? const []).map((e) => '$e').toList();
    return current.copyWith(description: '${map['description'] ?? current.description}',
      notes: '${map['notes'] ?? current.notes}', examples: list('examples'),
      characteristics: list('characteristics'), colors: list('colors'),
      materials: list('materials'), occasions: list('occasions'),
      typicalPieces: list('typicalPieces'));
  }
}
