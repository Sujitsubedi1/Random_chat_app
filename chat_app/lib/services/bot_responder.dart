// bot_responder.dart

class BotResponder {
  static String getReply(String input) {
    final msg = input.toLowerCase();

    if (msg.contains("hello") || msg.contains("hi")) {
      return "Hey there! 😊";
    } else if (msg.contains("how are you")) {
      return "I'm just code, but I'm doing great! What about you?";
    } else if (msg.contains("where are you from")) {
      return "I'm from the cloud ☁️";
    } else if (msg.contains("bye")) {
      return "Goodbye! It was nice chatting. 👋";
    } else {
      return "That's interesting! Tell me more.";
    }
  }
}
