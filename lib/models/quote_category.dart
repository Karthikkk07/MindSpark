/// The topics quotes are grouped by. The ids match the onboarding interests.
enum QuoteCategory {
  study('study', 'Study'),
  productivity('productivity', 'Productivity'),
  coding('coding', 'Coding'),
  career('career', 'Career'),
  internships('internships', 'Internships'),
  fitness('fitness', 'Fitness'),
  business('business', 'Business'),
  finance('finance', 'Finance'),
  relationships('relationships', 'Relationships'),
  growth('growth', 'Personal growth');

  const QuoteCategory(this.id, this.label);

  final String id;
  final String label;

  static QuoteCategory? fromId(String id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return null;
  }
}
