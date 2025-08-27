import 'dart:math';

String generateRandomPassword({int length = 12}) {
  const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const numbers = '0123456789';
  const special = '@#%^*+\$';
  
  final allChars = letters + numbers + special;
  final random = Random.secure();
  
  // Ensure password contains at least one of each character type
  final passwordChars = [
    letters[random.nextInt(letters.length)],
    numbers[random.nextInt(numbers.length)],
    special[random.nextInt(special.length)],
  ];
  
  // Fill the rest with random characters
  for (var i = 3; i < length; i++) {
    passwordChars.add(allChars[random.nextInt(allChars.length)]);
  }
  
  // Shuffle the characters
  passwordChars.shuffle(random);
  
  return passwordChars.join();
}