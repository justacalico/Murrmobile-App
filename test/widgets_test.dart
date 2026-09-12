import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murrmobile/models/announcement.dart';
import 'package:murrmobile/models/tag.dart';
import 'package:murrmobile/widgets/video_card.dart';
import 'package:murrmobile/widgets/linkify_text.dart';
import 'package:murrmobile/widgets/announcement_banner.dart';
import 'package:murrmobile/widgets/tag_edit_sheet.dart';
import 'package:murrmobile/widgets/responsive_shell.dart';
import 'package:murrmobile/services/murrtube_api.dart';

import 'support/fake_http.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;

  setUp(() {
    env = installTestEnv();
    MurrtubeApi.clearCookies();
  });

  tearDown(() {
    MurrtubeApi.clearCookies();
  });

  group('VideoCard', () {
    testWidgets('renders title, user, formatted counts', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 300,
            child: VideoCard(media: testMedia(), onTap: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Test Video'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('3.9K'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('formats millions and small counts', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 300,
            child: VideoCard(
              media: testMedia(viewsCount: 2500000, likesCount: 999),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('2.5M'), findsOneWidget);
      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('shows avatar image when avatarUrl set', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 300,
            child: VideoCard(
              media: testMedia(user: userJson(avatarUrl: 'https://x/a.png')),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      // Avatar is a ClipOval wrapping CachedNetworkImage.
      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('tap fires callback', (tester) async {
      var tapped = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: VideoCard(media: testMedia(), onTap: () => tapped++),
        ),
      );
      await tester.tap(find.byType(VideoCard));
      expect(tapped, 1);
    });

    testWidgets('uses heroTag when provided', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: VideoCard(
            media: testMedia(),
            onTap: () {},
            heroTag: 'custom-hero',
          ),
        ),
      );
      await tester.pump();
      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'custom-hero');
    });

    testWidgets('image errors fall back to error widgets', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SizedBox(
            width: 300,
            child: VideoCard(
              media: testMedia(
                thumbnailUrl: 'https://x/t.png',
                user: userJson(avatarUrl: 'https://x/a.png'),
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      await settleAsync(tester);
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person), findsWidgets);
    });
  });

  group('LinkifyText', () {
    testWidgets('renders plain text without links', (tester) async {
      await pumpApp(tester, const Scaffold(body: LinkifyText(text: 'hello')));
      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.text.toPlainText(), 'hello');
    });

    testWidgets('renders url with link style', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: LinkifyText(text: 'visit https://example.com now'),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.text.toPlainText(), 'visit https://example.com now');
      // Two children spans: plain + link + trailing.
      final span = rich.text as TextSpan;
      expect(span.children!.length, 3);
    });

    testWidgets('tapping a link launches the url', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: LinkifyText(text: 'go https://x.io/y')),
      );
      final rich = tester.widget<RichText>(find.byType(RichText));
      final span = (rich.text as TextSpan).children![1] as TextSpan;
      (span.recognizer as dynamic).onTap();
      await tester.pump();
      await settleAsync(tester);
      expect(env.urlLauncher.launchedUrls, contains('https://x.io/y'));
    });

    testWidgets('does not launch when canLaunch fails', (tester) async {
      env.urlLauncher.canLaunchResult = false;
      await pumpApp(
        tester,
        const Scaffold(body: LinkifyText(text: 'go https://x.io')),
      );
      final rich = tester.widget<RichText>(find.byType(RichText));
      final span = (rich.text as TextSpan).children![1] as TextSpan;
      (span.recognizer as dynamic).onTap();
      await tester.pump();
      await settleAsync(tester);
      expect(env.urlLauncher.launchedUrls, isEmpty);
    });
  });

  group('AnnouncementBanner', () {
    testWidgets('renders title and body', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AnnouncementBanner(
            announcement: Announcement.fromJson(announcementJson()),
          ),
        ),
      );
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('Something happened'), findsOneWidget);
      expect(find.text('Go'), findsNothing);
    });

    testWidgets('renders cta and launches it', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AnnouncementBanner(
            announcement: Announcement.fromJson(
              announcementJson(
                ctaUrl: 'https://murrtube.net/whats-new',
                ctaLabel: 'Read more',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Read more'), findsOneWidget);
      await tester.tap(find.text('Read more'));
      await settleAsync(tester);
      expect(
        env.urlLauncher.launchedUrls,
        contains('https://murrtube.net/whats-new'),
      );
    });

    testWidgets('cta without url label pair renders nothing', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AnnouncementBanner(
            announcement: Announcement.fromJson(
              announcementJson(ctaUrl: 'https://x.io'),
            ),
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('TagEditSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      List<Tag>? tags,
      void Function(List<Tag>)? onSaved,
    }) async {
      await pumpApp(
        tester,
        Scaffold(
          body: TagEditSheet(
            shortCode: 'ABC1',
            initialTags: tags ?? const [],
            onSaved: onSaved,
          ),
        ),
      );
    }

    testWidgets('shows existing tags as chips', (tester) async {
      await pumpSheet(
        tester,
        tags: [Tag(name: 'cat', category: 'general', count: 1)],
      );
      expect(find.text('#cat'), findsOneWidget);
      expect(find.text('Edit Tags'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('adds a tag via text submit', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'newtag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('#newtag'), findsOneWidget);
    });

    testWidgets('adds a tag via + button', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'plustag');
      // The + icon only renders once the suggest debounce resolves.
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(find.text('#plustag'), findsOneWidget);
    });

    testWidgets('ignores duplicate tag names', (tester) async {
      await pumpSheet(
        tester,
        tags: [Tag(name: 'cat', category: 'general', count: 1)],
      );
      await tester.enterText(find.byType(TextField), 'CAT');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('removes a tag via chip delete', (tester) async {
      await pumpSheet(
        tester,
        tags: [Tag(name: 'cat', category: 'general', count: 1)],
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Chip),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      expect(find.text('#cat'), findsNothing);
    });

    testWidgets('save with no changes pops without api call', (tester) async {
      var popped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  builder: (_) =>
                      const TagEditSheet(shortCode: 'ABC1', initialTags: []),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(env.server.requestsTo('/tag_edits'), isEmpty);
    });

    testWidgets('save calls editTags and onSaved', (tester) async {
      List<Tag>? saved;
      env.server.onGet('/', (req) => FakeResponse.htmlPage());
      env.server.onPost(
        '/tag_edits',
        (req) => FakeResponse.json({
          'tags': [
            {'name': 'added', 'category': 'general', 'count': 1},
          ],
        }),
      );
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => TagEditSheet(
                  shortCode: 'ABC1',
                  initialTags: const [],
                  onSaved: (tags) => saved = tags,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'added');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settleAsync(tester);
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.single.name, 'added');
    });

    testWidgets('save failure shows error text', (tester) async {
      env.server.onGet('/', (req) => FakeResponse.htmlPage());
      env.server.onPost('/tag_edits', (req) => const FakeResponse(500, 'err'));
      await pumpSheet(
        tester,
        tags: [Tag(name: 'cat', category: 'general', count: 1)],
      );
      // Remove the tag to produce a diff.
      await tester.tap(
        find.descendant(
          of: find.byType(Chip),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settleAsync(tester);
      await tester.pump();
      expect(find.textContaining('Failed to save tags'), findsOneWidget);
    });

    testWidgets('suggestions appear and can be tapped', (tester) async {
      env.server.onGet(
        '/search/suggest',
        (req) => FakeResponse.json({
          'query': 'ca',
          'users': [],
          'tags': [
            {'name': 'cat', 'category': 'general', 'count': 5},
            {'name': 'car', 'category': 'general', 'count': 2},
          ],
        }),
      );
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await tester.pump();
      expect(find.text('cat'), findsOneWidget);
      await tester.tap(find.text('cat'));
      await tester.pump();
      expect(find.text('#cat'), findsOneWidget);
    });

    testWidgets('suggestion fetch failure hides spinner', (tester) async {
      env.server.onGet(
        '/search/suggest',
        (req) => const FakeResponse(500, 'err'),
      );
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsync(tester);
      await tester.pump();
      // No crash, no suggestions.
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('clearing text clears suggestions', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('close button pops the sheet', (tester) async {
      var popped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  builder: (_) =>
                      const TagEditSheet(shortCode: 'ABC1', initialTags: []),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
    });

    testWidgets('suggest spinner shows while request is in flight', (
      tester,
    ) async {
      final gate = Completer<FakeResponse>();
      env.server.onGet('/search/suggest', (req) => gate.future);
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'ca');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      gate.complete(FakeResponse.json({'users': [], 'tags': []}));
      await settleAsync(tester);
      await tester.pump();
    });
  });

  group('ResponsiveShell', () {
    testWidgets('wide layout shows navigation rail', (tester) async {
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': const [],
          'pagination': paginationJson(),
          'announcements': const [],
        }),
      );
      await pumpApp(
        tester,
        const ResponsiveShell(),
        size: const Size(1200, 800),
      );
      await settleAsync(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Murrmobile'), findsOneWidget);
    });

    testWidgets('narrow layout uses collapsed rail by default', (tester) async {
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': const [],
          'pagination': paginationJson(),
          'announcements': const [],
        }),
      );
      await pumpApp(
        tester,
        const ResponsiveShell(),
        size: const Size(500, 900),
      );
      await settleAsync(tester);
      // Default navigation mode is collapsed_sidebar -> rail, no bottom nav.
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('guest shell hides upload and activity tabs', (tester) async {
      await pumpApp(
        tester,
        const ResponsiveShell(),
        size: const Size(1200, 800),
      );
      await tester.pump();
      expect(find.text('Upload'), findsNothing);
      expect(find.text('Activity'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('authed shell shows upload and activity tabs', (tester) async {
      MurrtubeApi.setCookies('session_id=abc');
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': const [],
          'pagination': paginationJson(),
          'announcements': const [],
        }),
      );
      await pumpApp(
        tester,
        const ResponsiveShell(),
        size: const Size(1200, 800),
      );
      await tester.pump();
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('tapping destination switches tab', (tester) async {
      env.server.onGet(
        '/',
        (req) => FakeResponse.inertia('Home', {
          'media': const [],
          'pagination': paginationJson(),
          'announcements': const [],
        }),
      );
      await pumpApp(
        tester,
        const ResponsiveShell(),
        size: const Size(1200, 800),
      );
      await settleAsync(tester);
      await tester.tap(find.text('Search'));
      await tester.pump();
      // Search page should be mounted in the IndexedStack.
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 1);
    });
  });
}
