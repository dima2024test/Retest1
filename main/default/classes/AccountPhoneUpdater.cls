public with sharing class AccountPhoneUpdater {
    @InvocableMethod
    public static void updateAccountPhones(List<AccountPhoneWrapper> accountUpdates) {
        List<Account> accountsToUpdate = new List<Account>();
        
        for (AccountPhoneWrapper accountUpdate : accountUpdates) {
            Account acc = new Account(Id = accountUpdate.accountId);
            acc.Phone = '12345'; // Установка номера телефона
            accountsToUpdate.add(acc);
        }
        
        // Обновление аккаунтов
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate; // Используйте 'update' здесь
            } catch (DmlException e) {
                System.debug('Error updating accounts: ' + e.getMessage());
            }
        }
    }

    // Вложенный класс для передачи данных
    public class AccountPhoneWrapper {
        @InvocableVariable
        public Id accountId; // ID аккаунта
    }
}