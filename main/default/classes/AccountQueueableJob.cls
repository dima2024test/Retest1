public class AccountQueueableJob implements Queueable, Database.AllowsCallouts {
    private List<Id> accountIds;

    // Constructor to pass the account IDs to process
    public AccountQueueableJob(List<Id> accountIds) {
        this.accountIds = accountIds;
    }

    // The execute method where the job logic is defined
    public void execute(QueueableContext context) {
        System.debug('Starting the Queueable job for account IDs: ' + accountIds);

        List<Account> accountsToUpdate = [SELECT Id, Name FROM Account WHERE Id IN :accountIds];

        System.debug(2/0);

        for (Account acc : accountsToUpdate) {
            // Sample logic: Update the Status__c field
            acc.Name = 'Processed';
            System.debug('Updating account: ' + acc.Id + ', Name: ' + acc.Name);
        }

        // Update the accounts in the database
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
            System.debug(2/0);
        } else {
            System.debug('No accounts to update.');
        }
    }
}