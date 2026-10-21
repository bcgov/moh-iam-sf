trigger BceidUserUpdateRequestTrigger on Bceid_User_Update_Request__e (after insert) {
    BceidUserUpdateRequestHandler.handle(Trigger.new);
}
