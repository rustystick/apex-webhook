
# Install
<a style="background-color: #E7E7E7;
  border: none; 
  border-radius: 12px;
  color: black;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  font-size: 12px;"
  href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04t8a000001VoYJAA0">Install to Sandbox</a>
  <br>
<a style="background-color: #4CAF50;
  border: none; 
  border-radius: 12px;
  color: white;
  padding: 10px 20px;
  text-align: center;
  text-decoration: none;
  display: inline-block;
  font-size: 12px;"
  href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04t8a000001VoYJAA0">Install to Prod</a>

# Inbound Webhook
## Motivation
Many SASS provider (e.g. Marketing Cloud, Twilio, Slack) uses webhook as a configurable pub-sub way of communicating data changes to external systems. Since there is generally a pattern in the webhook format (POST and security signature), implementing a general inbound webhook process could simplify this types of integration. 

## Process Flow
### Receiving
``` mermaid
 graph LR;
 A(Event Source) --> |POST| B(Unauthenticated Endpoint);
 B --> |verify signature| C{verified?}
 C --> |no| D[end]
 C --> |yes| E[Publish Platform Event]
```

### Event Handler
``` mermaid
 graph LR;
 A(Received Platform Event) --> |instantiate event handlers| event-handlers(Handlers);
 event-handlers --> |handle event| handle-event(Handle Event)
```
``` mermaid
 graph LR;
 subgraph handlers[Event Handlers]
 subgraph handler1[Handler 1]
 check(Check applicable) --> applicable{applicable?}
 applicable --> |no| next(next)
 applicable --> |yes| execute(handle event)
 execute --> next
 end
 handler2[Handler 2]
 ...
 end
 next --> handler2
 handler2 --> ...
```


## Components

### Community Site
Create a community site primarily to allow anonymous (unauthenticated) api request required for the webhook api to work and assign the `Inbound_Webhook_Permissions` to the `Guest User` of the community site

### Permission Set
`Inbound_Webhook_Permissions` contains apex permission to `InboundWebhookService` class which will then allow the assignee to use the REST endpoints
### Custom Metadata Configuration
`Inbound_Webhook_Setting__mdt` is used to define an inbound receiver. One should be setup for each of senders.

- `Inbound Webhook Setting Name` is used as a path to the endpoint
- `Shared Secret` is the secret that the sending source is signing the request with
- `Signature Header Name` is the name of the http header that the signature will be included with
- `Signing Algorithm` is the hashing algorithm that the sender is using to sign the event body with 
## Event Handler Base Class
`InboundWebhookEventHandler` abstract class that contains the shared logic and abstract methods that the concrete handler class should implement

# How to use
> ℹ️  Note: Inbound webhook must contain an string attribute `type` in its request json body


1. To receive event
    1. Create a Inbound_Webhook_Setting__mdt (at minimum give it a developer name)
    2. Register the endpoint ({communityBaseUrl}/webhook/v1/listener/{inboundWebhookSettingDeveloperName}) with the event source
    3. update the Inbound_Webhook_Setting__mdt record created with shared secret and signing algorithm 
2. To handle event
    1. Define a concrete class extending `InboundWebhookEventHandler`


# Outbound Webhook
## Motivation
We want to be able to connect systems via a pub-sub ([observer pattern](https://en.wikipedia.org/wiki/Observer_pattern)) model. Natively, salesforce is able to do this with the various `events` such as (Platform Event, Change Data Capture, and other streaming apis), however these all require [commetD](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_subscribe_cometd.htm) support in the listeners (clients) which is not quite ubiquitous. Alternatively, Salesforce traditionally has [Outbound Message](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_om_outboundmessaging_understanding.htm) which is a SOAP based tool to fire a SOAP event to a target, but this requires target system to deal with the SOAP envelope and WSDL which are neither convenient or modern. 

The solution implemented is an outbound webhook framework leveraging platform event and asynchronous apex with an api to register a listener. 

## Flow

### Firing an event
``` mermaid
 graph LR;
 A(event is fired) --> |eventName| B{Has listener?};
 subgraph eventListener[Apex Listener]

 B --> |yes| C{Has body processor?}
 C --> |no|D(Sign request and POST to each listener)
 C --> |yes| processBody(Process Body)
 processBody --> D

 D --> E
 B --> |no| E(End)
 end
```


## Components

### Platform Event
`Outbound_Webhook__e` is the defined platform event that will trigger the outbound webhook

- `Event_Type__c` is the event type or event name that is fired. Convention is to use all lower case without spaces or special characters.
- `Event_Body__c` is the event body string. Without body processor defined, the outbound webhook will send with this string as the data attribute.

### Body Processors
Body processor can be defined for each event type to be able to transform the outbound body's data attribute to a desired shape. Without a body processor, the resulted outbound webhook's `data` attribute will be a `string` of the `Event_Body__c` content.  

### Custom Metadata Setting
`Webhook_Event_Setting__mdt` is the custom metadata type storing settings for each event type.

### Custom Settings
`Webhook_Settings__c` is the custom setting that stores the global settings for all outbound webhook. Edit `Org Default` to update setting.

### Related Apex class
`OutboundWebhookBatch` contains the main logic loop


`OutboundWebhook` queries for all required records and orchestrates the batch job 


`OutboundWebhookWrapper` represents a single outbound webhook, contains logic of signing and calling out

## Api Class
`WebhookApiService` defines the REST Api services for registering, updating, and deleting a subscription. 


# How to use

## Registering an listener
Use the `Subscribe to Event` request
Response body should look something like below with sharedSecret, of which can be used to verify the webhook content with `HMAC-SHA256` algorithem
```json
{
    "registrationData": {
        "status": "Active",
        "id": "a507j00000099SIAAY",
        "headers": null,
        "event": "sampleevent",
        "callbackUrl": "https://webhook.site/6b13c7b4-677c-4d42-9f24-4e10c5a54f4c",
        "sharedSecret": "Xva+Q5p6B34TbNdiwwId9uemQjCbCjMd7IHOO91HSiA="
    },
    "message": "Success",
    "hasError": false
}
```

## Configuring a body processor
To define a Body Processor for a given event type, define a class implement the interface `OutboundWebhookBodyProcessor` and register it with the [Custom Metadata Setting](#"custom-Metadata-setting")

## Publishing an event
Simply publish a `Outbound_Webhook__e` via any means (apex, api, flow)

