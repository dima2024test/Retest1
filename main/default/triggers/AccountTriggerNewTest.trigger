trigger AccountTriggerNewTest on Account (before insert) {
if (Trigger.isAfter && Trigger.isUpdate) {
        List<Id> accountIds = new List<Id>();
        for (Account acc : Trigger.new) {
            accountIds.add(acc.Id);
        }
        AccountQueueableJob job = new AccountQueueableJob(accountIds);
        System.enqueueJob(job);
    }
}