global class TestBatchTwo implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // You can modify this query if needed
        return Database.getQueryLocator('SELECT Id FROM Account LIMIT 100');
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        try {
            // Attempt to query an Account with a name that does not exist
            Account a = [SELECT Name FROM Account WHERE Name = 'NonExistentAccountName' LIMIT 1];
            System.debug('Account found: ' + a.Name);
        } catch (QueryException e) {
            // This will catch the exception and log the error message
            System.debug('Exception is: ' + e.getMessage());
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Batch processing finished.');
    }
}