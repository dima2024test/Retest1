public class ErrorQueueable implements Queueable {
    private Exception error;

    public ErrorQueueable(Exception error) {
        this.error = error;
    }

    public void execute(QueueableContext context) {
        // Здесь добавляем ошибку в новую транзакцию
        Triton.instance.addError(TritonTypes.Area.Accounts, error);
        Triton.instance.flush();
    }
}