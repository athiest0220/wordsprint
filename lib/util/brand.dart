/// Public-facing bits used in shares so recipients can find/download the app.
///
/// One stable landing page (`prism-bi.com/wordsprint`) routes to the App Store
/// or Google Play. It's printed on the shared card images (so it survives
/// image-only shares like Instagram, which drop text captions) and appended to
/// text-based shares.
const String kWordSprintUrl = 'prism-bi.com/wordsprint';
const String kWordSprintShareTag = 'Play Word Sprint · $kWordSprintUrl';
