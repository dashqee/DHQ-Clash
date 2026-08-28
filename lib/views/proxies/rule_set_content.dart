import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// The rules inside one rule-set, with a filter over them.
///
/// The core decodes the set and caps what it returns, so this only ever holds a
/// window of a large geosite set — [RuleSetContent.total] is what says how much
/// was really there.
class RuleSetContentPage extends StatefulWidget {
  final String providerName;

  const RuleSetContentPage({super.key, required this.providerName});

  @override
  State<RuleSetContentPage> createState() => _RuleSetContentPageState();
}

class _RuleSetContentPageState extends State<RuleSetContentPage> {
  late final Future<RuleSetContent> _content;
  final _queryNotifier = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _content = coreController.getRuleSetContent(widget.providerName);
  }

  @override
  void dispose() {
    _queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: widget.providerName,
      body: FutureBuilder<RuleSetContent>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = snapshot.data;
          if (content == null || content.error.isNotEmpty) {
            return NullStatus(label: appLocalizations.ruleSetLoadFailed);
          }
          if (content.lines.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.rule),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (value) => _queryNotifier.value = value,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    hintText: appLocalizations.search,
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _queryNotifier,
                  builder: (_, query, _) =>
                      _RuleList(content: content, query: query),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lines of a rule set matching [query], case-insensitively.
///
/// Substring, not prefix: a set stores 'DOMAIN-SUFFIX,vk.com', '+.vk.com' and a
/// bare host, so anchoring the match would miss most of the real formats.
List<String> filterRuleLines(List<String> lines, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return lines;
  return lines.where((line) => line.toLowerCase().contains(needle)).toList();
}

class _RuleList extends StatelessWidget {
  final RuleSetContent content;
  final String query;

  const _RuleList({required this.content, required this.query});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final lines = filterRuleLines(content.lines, query);

    if (lines.isEmpty) {
      return NullStatus(label: appLocalizations.nullTip(appLocalizations.rule));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              appLocalizations.ruleSetShownCount(lines.length, content.total),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: lines.length,
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SelectableText(
                lines[index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
