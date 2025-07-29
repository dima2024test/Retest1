global class ErrorBatchRandom implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id FROM Account LIMIT 1]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        for (Integer k = 0; k <2; k++) {
            executeLogic();
        }
    }

    private void executeLogic() {
        try {
            // Генерация случайного числа от 0 до 1
            Double randomValue = Math.random();
            
            // Условие для выброса ошибки с 50% вероятностью
            if (randomValue < 0.5) {
                Integer i = 2 / 0; // Искусственное деление на ноль
            }
        } catch (Exception e) {
            for (Integer j = 0; j < 200; j++) {
                Triton.instance.addError(TritonTypes.Area.Accounts, e);
            }
            Triton.instance.flush();
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Test');
    }
}