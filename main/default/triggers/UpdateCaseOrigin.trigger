trigger UpdateCaseOrigin on Case (before insert, before update) {
    for (Case caseRecord : Trigger.new) {
       
        caseRecord.Origin = 'Email';
    }
}