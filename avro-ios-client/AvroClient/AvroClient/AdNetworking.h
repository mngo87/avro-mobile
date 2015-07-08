//
//  AdRequest.h
//  FlurryAnalytics
//
//  Created by Anthony Watkins on 2/13/12.
//  Copyright (c) 2012 Flurry Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "avro.h"
#include <inttypes.h>
#import <UIKit/UIKit.h>
#import "AdDelegate.h"

#define AD_REQUEST_SCHEMA \
"{\"type\":\"record\",\"name\":\"AdRequest\",\"namespace\":\"com.flurry.avroserver.protocol.v1\",\"fields\":[{\"name\":\"adSpaceName\",\"type\":\"string\"},{\"name\":\"location\",\"type\":{\"type\":\"record\",\"name\":\"Location\",\"fields\":[{\"name\":\"lat\",\"type\":\"float\",\"default\":0.0},{\"name\":\"lon\",\"type\":\"float\",\"default\":0.0}]},\"default\":\"null\"}]}"

#define LOCATION_SCHEMA \
"{\"type\":\"record\",\"name\":\"Location\",\"namespace\":\"com.flurry.avroserver.protocol.v1\",\"fields\":[{\"name\":\"lat\",\"type\":\"float\",\"default\":0.0},{\"name\":\"lon\",\"type\":\"float\",\"default\":0.0}]}"

#define AD_RESPONSE_SCHEMA \
"{\"type\":\"record\",\"name\":\"AdResponse\",\"namespace\":\"com.flurry.avroserver.protocol.v1\",\"fields\":[{\"name\":\"ads\",\"type\":{\"type\":\"array\",\"items\":{\"type\":\"record\",\"name\":\"Ad\",\"fields\":[{\"name\":\"adSpace\",\"type\":\"string\"},{\"name\":\"adName\",\"type\":\"string\"}]}}},{\"name\":\"errors\",\"type\":{\"type\":\"array\",\"items\":\"string\"},\"default\":[]}]}"

@interface AdNetworking : NSObject {
    avro_schema_t _adRequestSchema;
    avro_schema_t _locationSchema;
    avro_schema_t _adResponseSchema;
    
    //POC schemas
    avro_schema_t _userPrefSchema;
    avro_schema_t _userPref2Schema;
    avro_schema_t _metricSchema;
    avro_schema_t _metric2Schema;
    
    NSURLConnection *_connection;
    NSMutableData *_body;
	NSURLResponse *_response;
    id<AdDelegate> _delegate;
}

@property(nonatomic, retain) NSURLConnection *connection;
@property(nonatomic, retain) NSURLResponse *response;
@property(nonatomic, retain) NSMutableData *body;
@property(nonatomic, assign) id<AdDelegate> delegate;

- (void) initSchema;
- (void) sendAdRequest:(NSString *) adSpaceName lat:(float)lat lon:(float)lon;
- (void) sendRequest:(avro_datum_t)adRequest
            schemaName:(NSString*)schemaName
       schemaVersion:(int)schemaVersion;
- (void) parseAdResponse:(NSData *)adResponse size:(NSUInteger)size;

+ (NSString *) adServerUrl;

- (void) updateUserPrefRequest:(long)userId
                checkInEnabled:(BOOL)enabled
                       tempVar:(int)tempVar
                    brakeAudio:(BOOL)brakeAudio;
- (void) updateUserPref2Request:(long)userId
                checkInEnabled:(BOOL)enabled
                    brakeAudio:(BOOL)brakeAudio
                    accelAudio:(BOOL)accelAudio;

- (void) sendMetricsRequest:(long)userId
                    tempVar:(int)tempVar
                  btCrashes:(int)btCrashes;
- (void) sendMetrics2Request:(long)userId
                    vin:(NSString*)vin
                  btCrashes:(int)btCrashes;

@end
