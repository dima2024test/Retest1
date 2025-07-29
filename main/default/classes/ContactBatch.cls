global class ContactBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, FirstName FROM Contact]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        for (SObject obj : scope) {
            Contact con = (Contact) obj;
            // This could throw a NullPointerException if con.FirstName is null
            String firstName = con.FirstName.toUpperCase();
            // Process the contact
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Finish logic
    }
}