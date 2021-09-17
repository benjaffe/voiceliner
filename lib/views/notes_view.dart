import 'package:binder/binder.dart';
import 'package:flutter/material.dart';
import 'package:voice_outliner/data/note.dart';
import 'package:voice_outliner/state/notes_state.dart';
import 'package:voice_outliner/state/outline_state.dart';
import 'package:voice_outliner/state/player_state.dart';
import 'package:voice_outliner/widgets/note_item.dart';
import 'package:voice_outliner/widgets/record_button.dart';

class NotesViewArgs {
  final String outlineId;
  NotesViewArgs(this.outlineId);
}

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  final _renameController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    _renameController.dispose();
    _scrollController.dispose();
  }

  bool _onAddNote<T>(StateRef<T> ref, T oldState, T newState, Object? action) {
    if (ref.key.name == "notes" &&
        oldState is List<Note> &&
        newState is List<Note>) {
      if (oldState.length < newState.length) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn);
      }
    }
    return false;
  }

  List<PopupMenuItem<String>> _menuBuilder(BuildContext context) {
    return [
      const PopupMenuItem(
          value: "rename",
          child: ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text("rename outline"))),
      const PopupMenuItem(
          value: "delete",
          child: ListTile(
              leading: Icon(Icons.delete_forever),
              title: Text("delete outline"))),
    ];
  }

  void _handleMenu(String item, String outlineId) {
    final outline = context
        .read(outlinesRef)
        .firstWhere((element) => element.id == outlineId);
    if (item == "delete") {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text("Delete outline?"),
                content: const Text("It cannot be restored"),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: const Text("cancel")),
                  TextButton(
                      onPressed: () async {
                        ctx.use(outlinesLogicRef).deleteOutline(outline);
                        await Navigator.pushNamedAndRemoveUntil(
                            ctx, "/", (route) => false);
                      },
                      child: const Text("delete"))
                ],
              ));
    } else if (item == "rename") {
      Future<void> _onSubmitted(BuildContext ctx) async {
        if (_renameController.value.text.isNotEmpty) {
          await context
              .use(outlinesLogicRef)
              .renameOutline(outline, _renameController.value.text);
          Navigator.of(ctx, rootNavigator: true).pop();
        }
      }

      _renameController.text = outline.name;
      _renameController.selection = TextSelection(
          baseOffset: 0, extentOffset: _renameController.value.text.length);
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (dialogCtx) => AlertDialog(
                  title: Text("Rename Outline '${outline.name}'"),
                  content: TextField(
                      decoration:
                          const InputDecoration(hintText: "Outline Title"),
                      controller: _renameController,
                      autofocus: true,
                      autocorrect: false,
                      onSubmitted: (_) => _onSubmitted(dialogCtx),
                      textCapitalization: TextCapitalization.words),
                  actions: [
                    TextButton(
                        child: const Text("cancel"),
                        onPressed: () {
                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                        }),
                    TextButton(
                        child: const Text("rename"),
                        onPressed: () => _onSubmitted(dialogCtx))
                  ]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlineId =
        (ModalRoute.of(context)!.settings.arguments as NotesViewArgs).outlineId;
    return BinderScope(
        observers: [
          DelegatingStateObserver(_onAddNote)
        ],
        overrides: [
          notesLogicRef.overrideWith((scope) => NotesLogic(scope, outlineId))
        ],
        child: LogicLoader(
          refs: [notesLogicRef],
          builder: (ctx, loading, child) {
            if (loading) {
              // TODO: black screen
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return buildChild(ctx);
          },
        ));
  }

  Widget buildChild(BuildContext context) {
    final outlineId =
        (ModalRoute.of(context)!.settings.arguments as NotesViewArgs).outlineId;
    final currentOutlineName = context.watch(outlinesRef.select((state) => state
        .firstWhere((element) => element.id == outlineId,
            orElse: () => defaultOutline)
        .name));
    final noteCount = context.watch(notesRef.select((state) => state.length));
    final isNotReady = context
        .watch(playerStateRef.select((state) => state == PlayerState.notReady));
    if (isNotReady) {
      return const Scaffold(
          body: Center(
              child: Text(
                  "Please relaunch the app, the recorder isn't ready. Does it have permission?")));
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(currentOutlineName),
        leading: IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, "/", (_) => false);
            },
            icon: const Icon(Icons.view_list_rounded)),
        actions: [
          PopupMenuButton(
              itemBuilder: _menuBuilder,
              onSelected: (String item) => _handleMenu(item, outlineId))
        ],
      ),
      body: Column(children: [
        if (noteCount == 0)
          const Center(
              child: Text(
            "no notes yet!",
            style:
                TextStyle(fontSize: 40.0, color: Color.fromRGBO(0, 0, 0, 0.5)),
          )),
        Expanded(
            child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 150),
          shrinkWrap: true,
          itemBuilder: (_, int idx) =>
              NoteItem(key: Key("note-$idx"), num: idx),
          itemCount: noteCount,
        )),
      ]),
      floatingActionButton: const RecordButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
