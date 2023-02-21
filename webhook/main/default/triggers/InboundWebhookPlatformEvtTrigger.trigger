trigger InboundWebhookPlatformEvtTrigger on Inbound_Webhook__e (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        InboundWebhook inboundWebhook = InboundWebhook.fromNewList(Trigger.new);
        InboundWebhook.startEventHandlers();
    }
}