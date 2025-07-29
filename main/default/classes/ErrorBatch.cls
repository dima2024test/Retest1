public with sharing class ErrorBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, Database.RaisesPlatformEvents {

    private static final Integer QUERY_LIMIT = 200;

    public Database.QueryLocator start(Database.BatchableContext BC) {
       return Database.getQueryLocator([SELECT Id, pharos__Type__c, pharos__Organization_Id__c FROM Pharos__Log__c LIMIT 1]);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
       System.debug(1/0);
    }

    public void finish(Database.BatchableContext BC) {
    }

}