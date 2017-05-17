#import "SatoriRtmConnection.h"

@interface SatoriRtmConnection ()

@property (nonnull, nonatomic, strong) NSString* url;
@property (nonnull, nonatomic, strong) NSString* appKey;
@property (nonnull, nonatomic, strong) PduHandler pduHandler;
@property (nonnull, nonatomic, strong) MessageHandler messageHandler;
@property (nonnull, nonatomic, assign, readonly) rtm_client_t *rtm;

@end

@implementation SatoriRtmConnection
@synthesize enableVerboseLogging = _enableVerboseLogging;

static PduHandler _defaultPduHandler = nil;

#pragma mark - class properties

+ (nonnull PduHandler)defaultPduHandler {
    if (_defaultPduHandler == nil) {
        _defaultPduHandler = ^(SatoriPdu * pdu) {
            NSLog(@"Received pdu: action=%@, id=%u, body=%@\n", pdu.action, pdu.requestId, pdu.body);
        };
    }
    return _defaultPduHandler;
}

#pragma mark - initializer
- (nullable instancetype)initWithUrl:(nonnull NSString*)url andAppkey:(nonnull NSString*)appKey {
    if (url == nil || appKey == nil) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        self.url = url;
        self.appKey = appKey;
        _rtm = (rtm_client_t*) malloc (rtm_client_size);
    }
    return self;
}

#pragma mark - C functions
void on_pdu(rtm_client_t *rtm, const rtm_pdu_t *pdu) {
    SatoriRtmConnection* self = (__bridge SatoriRtmConnection *)(rtm_get_user_context(rtm));
    if (self.pduHandler) {
        SatoriPdu* convertedPdu = [[SatoriPdu alloc] initWithAction:[NSString stringWithUTF8String:(pdu->action)] body:[NSString stringWithUTF8String:(pdu->body)] andRequestId:pdu->request_id];
        self.pduHandler(convertedPdu);
    }
}

void on_message(rtm_client_t *rtm, const char* subscriptionId, const char* message) {
    SatoriRtmConnection* self = (__bridge SatoriRtmConnection *)(rtm_get_user_context(rtm));
    if (self.messageHandler) {
        id jsonObj = nil;
        if (message != nil) {
            NSError *err = nil;
            jsonObj = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:message length:strlen(message)] options:NSJSONReadingAllowFragments error:&err];
            if (err != nil) {
                NSLog(@"Error deserializing message %s: %@", message, err);
            }
        }
        self.messageHandler([NSString stringWithUTF8String:subscriptionId], jsonObj);
    }
}

#pragma mark - API methods

- (rtm_status)connect {
    self.pduHandler = [[self class] defaultPduHandler];
    return rtm_connect(self.rtm, self.url.UTF8String, self.appKey.UTF8String, &on_pdu, (__bridge void *)(self));
}

- (rtm_status)connectWithPduHandler:(nonnull PduHandler)pduHandler {
    if (pduHandler == nil) {
        return RTM_ERR_CONNECT;
    }
    self.pduHandler = pduHandler;
    return rtm_connect(self.rtm, self.url.UTF8String, self.appKey.UTF8String, &on_pdu, (__bridge void *)(self));
}

- (void)disconnect {
    rtm_close(self.rtm);
    _rtm = nil;
}

- (BOOL)enableVerboseLogging {
    return _enableVerboseLogging;
}

- (void)setEnableVerboseLogging:(BOOL)enableVerboseLogging {
    if (_enableVerboseLogging != enableVerboseLogging) {
        _enableVerboseLogging = enableVerboseLogging;
        if (_enableVerboseLogging) {
            rtm_enable_verbose_logging(self.rtm);
        } else {
            rtm_disable_verbose_logging(self.rtm);
        }
    }
}

+ (SatoriPdu *)parsePdu:(NSString *)json {
    rtm_pdu_t pdu = {};
    char *dup = strdup(json.UTF8String);
    rtm_parse_pdu(dup, &pdu);
    NSString* action = nil;
    NSString* body = nil;
    
    if (pdu.action != NULL) {
        action = [NSString stringWithUTF8String:pdu.action];
    }
    if (pdu.body != NULL) {
        body = [NSString stringWithUTF8String:pdu.body];
    }
    
    SatoriPdu* newPdu = [[SatoriPdu alloc] initWithAction:action body:body andRequestId:pdu.request_id];
    free(dup);
    return newPdu;
}

- (rtm_status)handshakeWithRole:(NSString*)role andRequestId:(unsigned *)requestId {
    return rtm_handshake(self.rtm, role.UTF8String, requestId);
}

- (rtm_status)authenticate:(NSString *)roleSecret nonce:(NSString*)nonce andRequestId:(unsigned *)requestId {
    return rtm_authenticate(self.rtm, roleSecret.UTF8String, nonce.UTF8String, requestId);
}

- (rtm_status)publishJson:(NSString *)json toChannel:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_publish_json(self.rtm, channel.UTF8String, json.UTF8String, requestId);
}

- (rtm_status)publishString:(NSString *)string toChannel:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_publish_string(self.rtm, channel.UTF8String, string.UTF8String, requestId);
}

- (rtm_status)subscribe:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_subscribe(self.rtm, channel.UTF8String, requestId);
}

- (rtm_status)subscribeWithBody:(NSString *)body andRequestId:(unsigned *)requestId {
    return rtm_subscribe_with_body(self.rtm, body.UTF8String, requestId);
}

- (rtm_status)unsubscribe:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_unsubscribe(self.rtm, channel.UTF8String, requestId);
}

- (rtm_status)read:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_read(self.rtm, channel.UTF8String, requestId);
}

- (rtm_status)readWithBody:(NSString *)body andRequestId:(unsigned *)requestId {
    return rtm_read_with_body(self.rtm, body.UTF8String, requestId);
}

- (rtm_status)writeString:(NSString *)string channel:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_write_string(self.rtm, channel.UTF8String, string.UTF8String, requestId);
}

- (rtm_status)writeJson:(NSString *)json channel:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_write_json(self.rtm, channel.UTF8String, json.UTF8String, requestId);
}

- (rtm_status)deleteFromChannel:(NSString *)channel andRequestId:(unsigned *)requestId {
    return rtm_delete(self.rtm, channel.UTF8String, requestId);
}

- (rtm_status)search:(NSString *)prefix andRequestId:(unsigned *)requestId {
    return rtm_search(self.rtm, prefix.UTF8String, requestId);
}

- (rtm_status)sendPdu:(NSString *)json {
    return rtm_send_pdu(self.rtm, json.UTF8String);
}

- (rtm_status)wait {
    return rtm_wait(self.rtm);
}

- (rtm_status)waitWithTimeout:(int)timeoutInSeconds {
    return rtm_wait_timeout(self.rtm, timeoutInSeconds);
}

- (rtm_status)poll {
    return rtm_poll(self.rtm);
}

- (int)getFileDescriptor {
    return rtm_get_fd(self.rtm);
}

@end
