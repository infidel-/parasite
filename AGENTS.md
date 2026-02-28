# Repository Guidelines

- NEVER detach HEAD! NEVER!
- ALWAYS respond in English!
- ALWAYS run tests at the end of each task: cd src/ && make
- When changing persisted game data structures, ALWAYS verify Saver/Loader savegame compatibility (both serialization and load behavior, including old saves when relevant).
- Use two-space indentation, brace-on-newline, and avoid trailing whitespace. in general, follow the existing code style of the file and repository.
- Lines without text should NEVER have whitespace.
- When adding new functions, always add short comment with summary of what it does on top, first letter should be lowercase
- When generating code, comment each large block with a short summary, first letter should be lowercase
- NEVER write var x = new Array<...>(), just write var x = []
- When writing if statements with multiple conditions, format each condition on a new line for better readability
- Method comments should ALWAYS start from the line start (no indentation)
- When creating variables or method names that have "id" in their name, use ID (e.g., memberID instead of memberId, getMemberID() instead of getMemberId()). Note: This applies to variable and method names only, not object properties like <object>.id which remain lowercase.
- When updating most of the code, keep changes compact: avoid introducing unnecessary temporary variables, redundant conditionals, or extra formatting helpers unless the existing code already requires them. Temporary variables are fine if they shorten the code or are reused.
- All enum values should be in ALL_CAPS_SNAKE_CASE (e.g., `enum ActionType { ATTACK, DEFEND, HEAL }`).
- stop unnecessary defensive checks. Prefer invariant-driven code for internal data structures and hot paths; only add extra null/bounds/type guards at real trust boundaries (user input, save/load migration, external APIs) or when existing local code already uses that guard pattern.
