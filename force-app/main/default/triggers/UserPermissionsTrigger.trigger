trigger UserPermissionsTrigger on User (after insert, after update) { 
    if (trigger.isAfter ){
        if( trigger.isInsert || trigger.isUpdate) 
        {
            UserRegistrationCustomMetadataUtility utilityChecks = new UserRegistrationCustomMetadataUtility();
            if (!utilityChecks.isTriggerActive('UserPermissionsTrigger'))
            {
                return;
            } 
            else
            {
                UserRegistrationPermission.processPermissions(trigger.new, Trigger.oldMap, Trigger.isUpdate, Trigger.isAfter);
            }
        }
    }   
}