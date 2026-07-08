import 'package:drift/drift.dart';
import 'package:gramx/infrastructure/database/database.dart';

class DemoDataSeeder {
  final AppDatabase db;

  DemoDataSeeder(this.db);

  Future<void> seed() async {
    // Check if already seeded
    final existingAccounts = await db.select(db.accounts).get();
    if (existingAccounts.isNotEmpty) return;

    await db.transaction(() async {
      // Create demo account
      final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          telegramUserId: 'demo_user',
          displayName: const Value('Demo User'),
          username: const Value('demo_user'),
        ),
      );

      final now = DateTime.now();

      // Create channels
      final techCrunchId = await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          accountId: accountId,
          chatId: -1001234567890,
          title: 'TechCrunch',
          username: const Value('techcrunch'),
          description: const Value('Breaking technology news and analysis. Startup coverage, product reviews, and the latest in tech.'),
          avatarColor: const Value('#FF6154'),
          subscriberCount: const Value(5200000),
          isVerified: const Value(true),
          lastPostAt: Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      final flutterDevId = await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          accountId: accountId,
          chatId: -1001234567891,
          title: 'Flutter Dev',
          username: const Value('flutterdev'),
          description: const Value('Official Flutter development updates, tips, tutorials, and community highlights.'),
          avatarColor: const Value('#027DFD'),
          subscriberCount: const Value(245000),
          isVerified: const Value(true),
          lastPostAt: Value(now.subtract(const Duration(minutes: 30))),
        ),
      );

      final cryptoDailyId = await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          accountId: accountId,
          chatId: -1001234567892,
          title: 'Crypto Daily',
          username: const Value('cryptodaily'),
          description: const Value('Daily cryptocurrency market analysis, DeFi updates, and blockchain technology news.'),
          avatarColor: const Value('#F7931A'),
          subscriberCount: const Value(1200000),
          lastPostAt: Value(now.subtract(const Duration(hours: 1))),
        ),
      );

      final designInspoId = await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          accountId: accountId,
          chatId: -1001234567893,
          title: 'Design Inspiration',
          username: const Value('designinspo'),
          description: const Value('Curated design inspiration, UI/UX trends, and creative resources for designers.'),
          avatarColor: const Value('#FF3366'),
          subscriberCount: const Value(820000),
          lastPostAt: Value(now.subtract(const Duration(hours: 3))),
        ),
      );

      final worldNewsId = await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          accountId: accountId,
          chatId: -1001234567894,
          title: 'World News 24/7',
          username: const Value('worldnews247'),
          description: const Value('Breaking news from around the globe. Politics, economy, science, and culture. Updated 24/7.'),
          avatarColor: const Value('#1DA1F2'),
          subscriberCount: const Value(3100000),
          isVerified: const Value(true),
          lastPostAt: Value(now.subtract(const Duration(minutes: 15))),
        ),
      );

      // --- Posts ---

      // TechCrunch posts
      final tc1 = await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: techCrunchId, messageId: 1001,
        body: const Value('Apple is reportedly working on a foldable iPhone prototype that could launch as early as 2027. Sources say the device features a 7.9-inch flexible OLED display and runs a new adaptive UI framework built on top of SwiftUI.'),
        publishedAt: now.subtract(const Duration(minutes: 5)),
        viewCount: const Value(482000), replyCount: const Value(234), forwardCount: const Value(1893),
        reactionsJson: const Value('{"🔥": 342, "👍": 156, "❤️": 89}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: techCrunchId, messageId: 1002,
        body: const Value('OpenAI announces GPT-5 Turbo with native multimodal reasoning. The new model can process video, audio, and code simultaneously with 2M token context. Enterprise pricing starts at \$0.002 per 1K tokens.'),
        publishedAt: now.subtract(const Duration(hours: 2)),
        viewCount: const Value(315000), replyCount: const Value(567), forwardCount: const Value(2341),
        reactionsJson: const Value('{"🤯": 521, "🚀": 234, "👍": 178}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: techCrunchId, messageId: 1003,
        body: const Value('Exclusive: Stripe is in talks to acquire a major European fintech startup for \$4.2B. The deal would expand Stripe\'s presence in embedded finance and BNPL services across the EU market.'),
        publishedAt: now.subtract(const Duration(hours: 8)),
        viewCount: const Value(198000), replyCount: const Value(89), forwardCount: const Value(445),
        reactionsJson: const Value('{"💰": 156, "👀": 234}'),
      ));

      // Flutter Dev posts
      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: flutterDevId, messageId: 2001,
        body: const Value('🎉 Flutter 3.42 stable is here! Highlights:\n\n• Impeller is now the default renderer on all platforms\n• Hot reload 3x faster with incremental compilation\n• New Material 3 adaptive components\n• Dart 3.12 with enhanced pattern matching\n\nUpgrade now: flutter upgrade'),
        publishedAt: now.subtract(const Duration(minutes: 30)),
        viewCount: const Value(89000), replyCount: const Value(423), forwardCount: const Value(1256),
        reactionsJson: const Value('{"🎉": 678, "❤️": 345, "🚀": 234, "👍": 156}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: flutterDevId, messageId: 2002,
        body: const Value('Pro tip: Use Riverpod\'s new keepAlive with timeout for caching API responses. This gives you automatic cache invalidation without manual timer management.\n\n```dart\n@riverpod\nFuture<User> user(ref) async {\n  ref.keepAlive(timeout: Duration(minutes: 5));\n  return api.fetchUser();\n}\n```'),
        publishedAt: now.subtract(const Duration(hours: 4)),
        viewCount: const Value(34000), replyCount: const Value(67), forwardCount: const Value(234),
        reactionsJson: const Value('{"👍": 234, "❤️": 89}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: flutterDevId, messageId: 2003,
        body: const Value('We\'re thrilled to see the Flutter community growing! Over 1 million apps have been published to the Play Store using Flutter. Thank you to every developer who builds with Flutter. 💙'),
        publishedAt: now.subtract(const Duration(days: 1)),
        viewCount: const Value(156000), replyCount: const Value(234), forwardCount: const Value(567),
        reactionsJson: const Value('{"❤️": 1234, "🎉": 567, "🚀": 234}'),
      ));

      // Crypto Daily posts
      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: cryptoDailyId, messageId: 3001,
        body: const Value('📊 Market Update:\n\nBTC: \$108,420 (+3.2%)\nETH: \$4,856 (+5.1%)\nSOL: \$312 (+8.7%)\n\nTotal market cap surpasses \$4.5T for the first time. Institutional inflows continue to accelerate with BlackRock\'s spot ETF seeing \$2.1B in weekly volume.'),
        publishedAt: now.subtract(const Duration(hours: 1)),
        viewCount: const Value(267000), replyCount: const Value(345), forwardCount: const Value(1567),
        reactionsJson: const Value('{"🚀": 456, "💰": 234, "🔥": 178}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: cryptoDailyId, messageId: 3002,
        body: const Value('Ethereum\'s Pectra upgrade goes live on mainnet. Key improvements include account abstraction (EIP-7702), blob throughput increase, and validator consolidation. Gas fees expected to drop by 40% on L2s.'),
        publishedAt: now.subtract(const Duration(hours: 6)),
        viewCount: const Value(189000), replyCount: const Value(123), forwardCount: const Value(890),
        reactionsJson: const Value('{"👍": 345, "🤯": 156}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: cryptoDailyId, messageId: 3003,
        body: const Value('⚠️ Breaking: SEC approves first spot Solana ETF applications from VanEck and 21Shares. Trading expected to begin within 30 days. SOL surges 12% on the news.'),
        publishedAt: now.subtract(const Duration(days: 1, hours: 2)),
        viewCount: const Value(445000), replyCount: const Value(567), forwardCount: const Value(3421),
        reactionsJson: const Value('{"🚀": 890, "🔥": 567, "💰": 345}'),
        isBookmarked: const Value(true),
      ));

      // Design Inspiration posts
      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: designInspoId, messageId: 4001,
        body: const Value('The 2026 design trend everyone is talking about: "Dimensional Minimalism" — clean interfaces with subtle 3D elements, soft shadows, and micro-interactions that make flat design feel alive without the clutter.'),
        publishedAt: now.subtract(const Duration(hours: 3)),
        viewCount: const Value(78000), replyCount: const Value(45), forwardCount: const Value(234),
        reactionsJson: const Value('{"❤️": 456, "👍": 123}'),
      ));

      final di2 = await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: designInspoId, messageId: 4002,
        body: const Value('Color palette of the week:\n\n🎨 "Arctic Dusk"\n• #0B1426 (Deep Navy)\n• #1B3A5C (Fjord Blue)\n• #E8DFD0 (Warm Sand)\n• #F7931A (Amber Glow)\n• #FF6B6B (Coral)\n\nPerfect for fintech and premium dashboard designs.'),
        publishedAt: now.subtract(const Duration(hours: 12)),
        viewCount: const Value(56000), replyCount: const Value(34), forwardCount: const Value(567),
        reactionsJson: const Value('{"❤️": 789, "🎨": 345, "🔥": 123}'),
        isBookmarked: const Value(true),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: designInspoId, messageId: 4003,
        body: const Value('Typography tip: Stop using font-size alone to create hierarchy. Combine weight, color, and spacing. A 14px bold title with tight letter-spacing can feel larger than a 18px regular text with loose spacing.'),
        publishedAt: now.subtract(const Duration(days: 2)),
        viewCount: const Value(34000), replyCount: const Value(23), forwardCount: const Value(189),
        reactionsJson: const Value('{"👍": 234, "❤️": 67}'),
      ));

      // World News posts
      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: worldNewsId, messageId: 5001,
        body: const Value('🌍 BREAKING: The European Union reaches landmark agreement on global AI governance framework. The accord, signed by 47 nations, establishes binding safety standards for foundation models and mandates transparency in AI-generated content.'),
        publishedAt: now.subtract(const Duration(minutes: 15)),
        viewCount: const Value(523000), replyCount: const Value(890), forwardCount: const Value(4567),
        reactionsJson: const Value('{"👍": 890, "🤔": 345, "🌏": 234}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: worldNewsId, messageId: 5002,
        body: const Value('Japan\'s space agency JAXA successfully lands its second autonomous rover on the lunar south pole. The rover will search for water ice deposits and test in-situ resource utilization technology for future human missions.'),
        publishedAt: now.subtract(const Duration(hours: 5)),
        viewCount: const Value(312000), replyCount: const Value(234), forwardCount: const Value(1890),
        reactionsJson: const Value('{"🚀": 567, "🌟": 345, "👍": 234}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: worldNewsId, messageId: 5003,
        body: const Value('G20 summit concludes with historic climate finance deal: developed nations pledge \$500B annually for clean energy transition in developing countries. Implementation begins 2027.'),
        publishedAt: now.subtract(const Duration(days: 1, hours: 8)),
        viewCount: const Value(278000), replyCount: const Value(567), forwardCount: const Value(2345),
        reactionsJson: const Value('{"🌏": 567, "👍": 345}'),
      ));

      await db.into(db.posts).insert(PostsCompanion.insert(
        accountId: accountId, channelId: worldNewsId, messageId: 5004,
        body: const Value('📊 Global Economy Report: World GDP growth revised upward to 3.8% for 2026. Major factors include accelerating AI productivity gains, stabilized energy markets, and strong consumer spending in emerging economies.'),
        publishedAt: now.subtract(const Duration(days: 2, hours: 4)),
        viewCount: const Value(198000), replyCount: const Value(156), forwardCount: const Value(890),
        reactionsJson: const Value('{"📊": 234, "👍": 167}'),
        isBookmarked: const Value(true),
      ));

      // Add some media items to posts
      await db.into(db.mediaItems).insert(MediaItemsCompanion.insert(
        postId: tc1, type: 'photo', width: const Value(1200), height: const Value(675),
      ));

      await db.into(db.mediaItems).insert(MediaItemsCompanion.insert(
        postId: di2, type: 'photo', width: const Value(800), height: const Value(800),
      ));
      await db.into(db.mediaItems).insert(MediaItemsCompanion.insert(
        postId: di2, type: 'photo', width: const Value(800), height: const Value(800), sortOrder: const Value(1),
      ));
    });
  }
}
