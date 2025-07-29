global class ErrorHandlingBatchNew implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id FROM Account LIMIT 1]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        for (Integer k = 0; k < 1; k++) {
            executeLogic();
        }
    }

    private void executeLogic() {
        try {
            Integer i = 2 / 0;
        } catch (Exception e) {
            for (Integer j = 0; j < 60; j++) {
                Triton.instance.addError(TritonTypes.Area.Accounts, e);
            }
            Triton.instance.flush();
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Test');
    }
}
//test