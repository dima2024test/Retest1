global class CreateAccountsBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Возвращаем пустой QueryLocator, чтобы начать выполнение
        return Database.getQueryLocator([SELECT Id FROM Account LIMIT 1]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<Account> newAccounts = new List<Account>();

        // Создаем 2000 аккаунтов
        for (Integer i = 0; i < 10000; i++) {
            Account newAccount = new Account();
            newAccount.Name = 'Account ' + (i + 1); // Название аккаунта
            newAccounts.add(newAccount);
        }

        // Выполнение DML операции для создания аккаунтов
        if (!newAccounts.isEmpty()) {
            insert newAccounts;
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Аккаунты успешно созданы.');
    }
}