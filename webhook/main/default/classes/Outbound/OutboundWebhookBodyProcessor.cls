/**
 *  @description interface to be implemented to produce custom outbound body for a given event type
 *               register the interface by creating a custom metadata type Webhook_Event_Setting__mdt entry
 *  @author Andi Xie
 */
public interface OutboundWebhookBodyProcessor {
    /**
    * @description process to create a custom outbound body
    * @param  webhookToProcess input event
    * @return                  wrapped outbound message with processed body
    */ 
    List<OutboundWebhookWrapper> processBody(List<Outbound_Webhook__e> webhookToProcess);
}