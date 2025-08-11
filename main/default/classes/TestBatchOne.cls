public class TestBatchOne implements Queueable {
    public void execute(QueueableContext context) {
        // Intentionally causing a NullPointerException
        String testString = null;
        // This line will throw a NullPointerException
        String result = testString.toUpperCase();
    }
}