enum YonkeProfileAvailability { demo, contractPending }

class YonkeProfileSnapshot {
  const YonkeProfileSnapshot({required this.availability});

  final YonkeProfileAvailability availability;
}
