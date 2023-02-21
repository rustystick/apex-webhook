trigger OutboundWebhookPlatformEvtTrigger on Outbound_Webhook__e (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        OutboundWebhook webhook = new OutboundWebhook(Trigger.new);
        webhook.startCallOutBatch();
    }
}