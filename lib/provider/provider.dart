abstract class Provider {
  Future<Stream<String>> request({
    required String messages,
    required String model,
  });

  Future<Stream<String>> generateTitle({
    required String value,
    required String model,
  });
}
