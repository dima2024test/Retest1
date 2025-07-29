trigger ContactTrigger on Contact (before insert, before update) {
    for (Contact con : Trigger.new) {
        // This could throw a NullPointerException if con.FirstName is null
        String firstName = con.FirstName.toUpperCase();
    }
}