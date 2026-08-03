/// The interest catalogue, grouped so the picker reads like a menu instead of
/// a wall of 18 chips. Shared interests are the single strongest term in the
/// matching scorer, so breadth here directly improves who you meet.
class InterestGroup {
  const InterestGroup(this.emoji, this.name, this.items);
  final String emoji;
  final String name;
  final List<String> items;
}

const List<InterestGroup> kInterestGroups = [
  InterestGroup('🎮', 'Gaming', [
    'Console', 'PC', 'Mobile games', 'Esports', 'Minecraft', 'Roblox',
    'Fortnite', 'FIFA', 'Call of Duty', 'Retro games',
  ]),
  InterestGroup('🎵', 'Music', [
    'Hip hop', 'Afrobeats', 'Pop', 'Rock', 'R&B', 'Drill', 'EDM', 'Indie',
    'Latin', 'K-pop', 'Making music', 'Concerts',
  ]),
  InterestGroup('⚽', 'Sport', [
    'Football', 'Basketball', 'Formula 1', 'MMA', 'Boxing', 'Tennis',
    'Cricket', 'Skating', 'Surfing', 'Running',
  ]),
  InterestGroup('💪', 'Health', [
    'Gym', 'Lifting', 'Yoga', 'Nutrition', 'Mental health', 'Cycling',
    'Hiking', 'Football fitness',
  ]),
  InterestGroup('🍿', 'Watching', [
    'Anime', 'Movies', 'Netflix', 'Horror', 'Comedy', 'Documentaries',
    'Reality TV', 'YouTube', 'Marvel', 'True crime',
  ]),
  InterestGroup('🎨', 'Creative', [
    'Art', 'Photography', 'Design', 'Writing', 'Dancing', 'Acting',
    'Content creation', 'Fashion', 'Makeup', 'Tattoos',
  ]),
  InterestGroup('💼', 'Business', [
    'Startups', 'Investing', 'Crypto', 'Marketing', 'Real estate',
    'Side hustles', 'Tech', 'Trading',
  ]),
  InterestGroup('✈️', 'Travel', [
    'Backpacking', 'Road trips', 'Beaches', 'Cities', 'Festivals',
    'Languages', 'Living abroad',
  ]),
  InterestGroup('🍕', 'Food', [
    'Cooking', 'Baking', 'Street food', 'Coffee', 'Vegan', 'Takeaway debates',
  ]),
  InterestGroup('🌀', 'Chaos', [
    'Memes', 'Pranks', 'Debating', 'Storytelling', 'Conspiracies',
    'Astrology', 'Deep talks', 'Bad jokes',
  ]),
];

/// Flat list — used to validate stored values and by the profile editor.
List<String> get kAllInterests =>
    [for (final g in kInterestGroups) ...g.items];

/// The languages we match on. Ordered by rough global reach; the picker
/// pre-selects from the device locale so most people just tap Next.
const List<({String code, String label, String native})> kLanguages = [
  (code: 'en', label: 'English', native: 'English'),
  (code: 'es', label: 'Spanish', native: 'Español'),
  (code: 'pt', label: 'Portuguese', native: 'Português'),
  (code: 'ar', label: 'Arabic', native: 'العربية'),
  (code: 'fr', label: 'French', native: 'Français'),
  (code: 'de', label: 'German', native: 'Deutsch'),
  (code: 'it', label: 'Italian', native: 'Italiano'),
  (code: 'tr', label: 'Turkish', native: 'Türkçe'),
  (code: 'hi', label: 'Hindi', native: 'हिन्दी'),
  (code: 'ru', label: 'Russian', native: 'Русский'),
  (code: 'pl', label: 'Polish', native: 'Polski'),
  (code: 'nl', label: 'Dutch', native: 'Nederlands'),
  (code: 'ja', label: 'Japanese', native: '日本語'),
  (code: 'ko', label: 'Korean', native: '한국어'),
  (code: 'zh', label: 'Chinese', native: '中文'),
];
