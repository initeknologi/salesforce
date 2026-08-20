trigger OrderSyncEventTrigger on Order_Sync_Event__e (after insert) {
    OrderSyncEventHandler.handleEvents(Trigger.new);
}
