public class AccountPhoneUpdaterExample {
    @InvocableMethod
    public static void updateAccountPhones(List<Id> accountIds) {
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Id accountId : accountIds) {
            Account acc = new Account(Id = accountId);
            acc.Phone = '12345'; // Установка номера телефона
            accountsToUpdate.add(acc);
        }
        
        // Обновление аккаунтов
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
            } catch (DmlException e) {
                System.debug('Error updating accounts: ' + e.getMessage());
            }
        }
    }
}