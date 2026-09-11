import 'package:flutter/material.dart';

import 'src/app/dnd_table_app.dart';
import 'src/features/characters/domain/dnd5e_rules.dart';
import 'src/features/rules/data/rule_profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Dnd5eRules.configure(await RuleProfileStore.loadBuiltin());
  runApp(const OhMyDungeonApp());
}
