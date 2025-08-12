// bot_responder.dart

class BotResponder {
  static String getReply(String input) {
    final msg = input.toLowerCase();

    if (msg.contains("hello") ||
        msg.contains("Hello") ||
        msg.contains("Hello!") ||
        msg.contains("hello!") ||
        msg.contains("hi") ||
        msg.contains("Hi") ||
        msg.contains("hi!") ||
        msg.contains("Hi!") ||
        msg.contains("Hii") ||
        msg.contains("hii") ||
        msg.contains("Hii!") ||
        msg.contains("hii!") ||
        msg.contains("Heyy") ||
        msg.contains("Hey") ||
        msg.contains("hey") ||
        msg.contains("Hey!") ||
        msg.contains("hey!")) {
      return "hello";
    } else if (msg.contains("how are you")) {
      return "Good. You?";
    } else if (msg.contains("where u from") ||
        msg.contains("where u from?") ||
        msg.contains("Where you from") ||
        msg.contains("Where you from?") ||
        msg.contains("u from") ||
        msg.contains("u from?") ||
        msg.contains("U from") ||
        msg.contains("U from?")) {
      return "delhi. You?";
    } else if (msg.contains("age") ||
        msg.contains("age?") ||
        msg.contains("Age") ||
        msg.contains("Age?") ||
        msg.contains("ur age") ||
        msg.contains("Whats your age") ||
        msg.contains("whats your age") ||
        msg.contains("Whats your age?") ||
        msg.contains("whats your age?") ||
        msg.contains("Whats ur age") ||
        msg.contains("whats ur age") ||
        msg.contains("Whats ur age?") ||
        msg.contains("whats ur age?")) {
      return "28";
    } else if (msg.contains("What's ur name?") ||
        msg.contains("What is your name?") ||
        msg.contains("Name?") ||
        msg.contains("name?") ||
        msg.contains("name") ||
        msg.contains("Name") ||
        msg.contains("Ur name?") ||
        msg.contains("Ur name") ||
        msg.contains("ur name") ||
        msg.contains("ur name?")) {
      return "Gunjan";
    } else if (msg.contains("Nice") || msg.contains("nice")) {
      return "thanks";
    } else if (msg.contains("ohh") || msg.contains("Ohh")) {
      return "yup";
    } else {
      return "__END__"; // special signal to end chat
    }
  }
}
