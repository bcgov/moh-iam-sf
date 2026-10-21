/**
 * Handles BCeID User-update Platform Events in a separate transaction.
 * This avoids chaining another Queueable from the Contact update transaction.
 */
public without sharing class BceidUserUpdateRequestHandler {
    public static void handle(List<Bceid_User_Update_Request__e> events) {
        if (events == null || events.isEmpty()) return;

        Map<Id, BceidPersonData> dataByUserId = new Map<Id, BceidPersonData>();
        for (Bceid_User_Update_Request__e eventRecord : events) {
            if (eventRecord == null || String.isBlank(eventRecord.UserId__c)) continue;
            try {
                Id userId = (Id) eventRecord.UserId__c;
                dataByUserId.put(userId, new BceidPersonData(
                    eventRecord.FirstName__c,
                    eventRecord.LastName__c,
                    eventRecord.Email__c,
                    eventRecord.MobilePhone__c
                ));
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    'Skipping BCeID User update event with invalid User Id.');
            }
        }
        if (dataByUserId.isEmpty()) return;

        Map<Id, User> currentById = new Map<Id, User>([
            SELECT Id, FirstName, LastName, Email, MobilePhone
            FROM User
            WHERE Id IN :dataByUserId.keySet()
        ]);

        List<User> proposedUpdates = new List<User>();
        for (Id userId : dataByUserId.keySet()) {
            User currentUser = currentById.get(userId);
            if (currentUser == null) continue;
            if (BceidUserMapper.apply(currentUser, dataByUserId.get(userId))) {
                proposedUpdates.add(currentUser);
            }
        }
        if (proposedUpdates.isEmpty()) return;

        SObjectAccessDecision accessDecision = Security.stripInaccessible(
            AccessType.UPDATABLE, proposedUpdates);
        List<SObject> safeRecords = new List<SObject>();
        for (SObject record : accessDecision.getRecords()) {
            if (record.getPopulatedFieldsAsMap().size() > 1) safeRecords.add(record);
        }
        if (safeRecords.isEmpty()) return;

        Database.SaveResult[] results = Database.update(safeRecords, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error dmlError : results[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'BCeID User update event failed. Status=' + dmlError.getStatusCode());
                }
            }
        }
    }
}
