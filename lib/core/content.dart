/// Daily prompts. The index is derived from the shared "couple day", so both
/// partners always see the same question and note on the same day.
const dailyQuestions = <String>[
  'What small thing made you smile this week?',
  'What is one thing you are looking forward to when we are in the same place?',
  'Which memory of us do you replay the most?',
  'What did you eat today that you wish we had shared?',
  'What is a song that reminds you of me right now?',
  'What is something you learned about yourself recently?',
  'If we had a free Saturday together tomorrow, how would it go?',
  'What is the smallest thing I do that makes you feel loved?',
  'What was the best part of your day today?',
  'What is a place you want us to see together?',
  'What is something you are proud of this month?',
  'What would you tell your past self on the day we met?',
  'Which of our inside jokes still makes you laugh?',
  'What is one thing that is stressing you out, and how can I help?',
  'What is a tiny ritual you want us to start?',
  'What is the nicest thing a stranger did for you recently?',
  'What does home feel like to you?',
  'What is one thing you want to say that is hard to say over a call?',
  'What is a dream you have not told many people about?',
  'What is something I did early on that made you fall for me?',
  'What are you grateful for today?',
  'If we cooked one meal together this week, what would it be?',
  'What is something that made you feel calm today?',
  'What do you want our first morning together to look like?',
  'What is a photo of us that you love, and why?',
  'What is one thing you miss doing with me?',
  'What is a small win from today?',
  'Which film or show should we watch together next?',
  'What is something new you want to try this year?',
  'What made you think of me today?',
];

/// Small daily nudges. `{name}` is replaced with the partner's name.
const dailyNotes = <String>[
  'Notice one thing you are grateful for in {name} today, and tell them.',
  'Send {name} a photo of something ordinary from your day.',
  'Ask {name} about the one thing they are dreading this week.',
  'Record a thirty second voice note for {name}. No script.',
  'Tell {name} one thing they did recently that you admired.',
  'Plan one small thing to look forward to with {name}.',
  'Say goodnight to {name} with something specific, not just the usual.',
  'Write down a memory of you and {name} that you never want to forget.',
  'Ask {name} what would make their week easier.',
  'Share a song with {name} and say why it made you think of them.',
  'Tell {name} about a moment today when you wished they were there.',
  'Give {name} your full attention for one call. Phone down, no tabs.',
];

const moods = <MoodOption>[
  MoodOption('happy', 'Happy'),
  MoodOption('calm', 'Calm'),
  MoodOption('tired', 'Tired'),
  MoodOption('low', 'Low'),
  MoodOption('anxious', 'Anxious'),
];

class MoodOption {
  const MoodOption(this.key, this.label);
  final String key;
  final String label;
}

String moodLabel(String? key) {
  for (final m in moods) {
    if (m.key == key) return m.label;
  }
  return '';
}
