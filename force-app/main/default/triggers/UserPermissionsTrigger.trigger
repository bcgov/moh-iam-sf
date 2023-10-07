trigger UserPermissionsTrigger on User (after insert, after update) { 
    if (trigger.isAfter ){
        if( trigger.isInsert || trigger.isUpdate) 
        {
            UserRegistrationPermission.processPermissions(trigger.new);
        }
    }   
}