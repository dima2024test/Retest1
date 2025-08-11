public class TestBatchThree implements Queueable {
    
    public void execute(QueueableContext context) {
        try {
            // Simulating a scenario that might lead to an AsyncException
            // For example, creating a very large number of records that exceeds limits
            List<Account> accountsToInsert = new List<Account>();
            for (Integer i = 0; i < 200000; i++) { // Trying to insert too many records
                accountsToInsert.add(new Account(Name = 'Test Account ' + i));
            }
            insert accountsToInsert; // This will likely exceed governor limits
        } catch (Exception ex) {
            System.debug('Caught an exception: ' + ex.getMessage());
            // Optionally, rethrow to fail the job
            throw ex;
        }
    }
}