//
//  AdRequest.m
//  FlurryAnalytics
//
//  Created by Anthony Watkins on 2/13/12.
//  Copyright (c) 2012 Flurry Inc. All rights reserved.
//

#import "AdNetworking.h"

@interface AdNetworking()

- (NSString *) getContentsOfFile:(NSString*) fileName
                         ext:(NSString*) ext;

@end

@implementation AdNetworking

@synthesize connection=_connection;
@synthesize response=_response;
@synthesize body=_body;
@synthesize delegate=_delegate;

static NSString *gAdServerUrl = @"http://localhost:8080";

+ (NSString *) adServerUrl {
    return gAdServerUrl;
}

- (id) init {
    [self initSchema];
    return self;
}

- (void) dealloc {
    self.connection = nil;
	self.body = nil;
	self.response = nil;
    
    avro_schema_decref(_adRequestSchema);
    avro_schema_decref(_locationSchema);
    avro_schema_decref(_adResponseSchema);
    
    avro_schema_decref(_userPrefSchema);
    avro_schema_decref(_userPref2Schema);
    avro_schema_decref(_metricSchema);
    avro_schema_decref(_metric2Schema);
	
    [super dealloc];
}

-(void) initSchema {
    if(_adRequestSchema != nil)
    {
        return;
    }
    
    _body = [[NSMutableData alloc] init];
    
    avro_schema_error_t error;
	if (avro_schema_from_json(AD_REQUEST_SCHEMA, sizeof(AD_REQUEST_SCHEMA),
                              &_adRequestSchema, &error)) {
		NSLog(@"Unable to parse ad request schema");
        
        // This would be a compile time error
		return;
	}
    
    if (avro_schema_from_json(LOCATION_SCHEMA, sizeof(LOCATION_SCHEMA),
                              &_locationSchema, &error)) {
		NSLog(@"Unable to parse location schema");
        
        // This would be a compile time error
		return;
	}
    
    if (avro_schema_from_json(AD_RESPONSE_SCHEMA, sizeof(AD_RESPONSE_SCHEMA),
                              &_adResponseSchema, &error)) {
		NSLog(@"Unable to parse ad response schema");
        
        // This would be a compile time error
		return;
	}

    //POC schemas
    NSString* contentStr = [self getContentsOfFile:@"protocol/UserPref" ext:@"avsc"];
    if (avro_schema_from_json([contentStr cStringUsingEncoding:NSUTF8StringEncoding],
                              [contentStr length],
                              &_userPrefSchema, &error)) {
        NSLog(@"Unable to parse user preference schema");
    }

    contentStr = [self getContentsOfFile:@"protocol/UserPref2" ext:@"avsc"];
    if (avro_schema_from_json([contentStr cStringUsingEncoding:NSUTF8StringEncoding],
                              [contentStr length],
                              &_userPref2Schema, &error)) {
        NSLog(@"Unable to parse user preference schema");
    }

    contentStr = [self getContentsOfFile:@"protocol/Metrics" ext:@"avsc"];
    if (avro_schema_from_json([contentStr cStringUsingEncoding:NSUTF8StringEncoding],
                              [contentStr length],
                              &_metricSchema, &error)) {
        NSLog(@"Unable to parse metrics schema");
    }

    contentStr = [self getContentsOfFile:@"protocol/Metrics2" ext:@"avsc"];
    if (avro_schema_from_json([contentStr cStringUsingEncoding:NSUTF8StringEncoding],
                              [contentStr length],
                              &_metric2Schema, &error)) {
        NSLog(@"Unable to parse metrics 2 schema");
    }

    
    
    NSLog(@"Successfully parsed ad request schema");
}

- (NSString *) getContentsOfFile:(NSString*) fileName
                         ext:(NSString*) ext {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:ext];
    NSString *fileContents = [NSString stringWithContentsOfFile:filePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
    
    return fileContents;
}

- (void) updateUserPrefRequest:(long)userId
                checkInEnabled:(BOOL)enabled
                       tempVar:(int)tempVar
                    brakeAudio:(BOOL)brakeAudio {
    avro_datum_t userPrefRequest = avro_record(_userPrefSchema);

    avro_datum_t brakeAudio_datum = avro_boolean(brakeAudio);

    avro_schema_t audioSettingsSchema = avro_schema_record_field_get(_userPrefSchema, "audioSettings");
    avro_datum_t audioSettings_datum = avro_record(audioSettingsSchema);

    if (avro_record_set(audioSettings_datum, "brake", brakeAudio_datum)) {
        NSLog(@"Unable to create audioSettings %s", avro_strerror());
        return;
    }
    //mem leak if returned
    avro_datum_decref(brakeAudio_datum);
    
    avro_datum_t checkInEnabled_datum = avro_boolean(enabled);
    avro_datum_t userId_datum = avro_int32(userId);
    avro_datum_t tempVar_datum = avro_int32(tempVar);

    if (avro_record_set(userPrefRequest, "audioSettings", audioSettings_datum)
        || avro_record_set(userPrefRequest, "checkInEnabled", checkInEnabled_datum)
        || avro_record_set(userPrefRequest, "tempVar", tempVar_datum)
        || avro_record_set(userPrefRequest, "userId", userId_datum)) {
        NSLog(@"Unable to create userPrefReqeust %s", avro_strerror());
        return;
    }
    
    // Clean up
    avro_datum_decref(audioSettings_datum);
    avro_datum_decref(checkInEnabled_datum);
    avro_datum_decref(tempVar_datum);
    avro_datum_decref(userId_datum);
    
    // Do JSON Print
    char  *json = NULL;
    avro_datum_to_json(userPrefRequest, 1, &json);
    NSLog(@"UserPrefRequest in JSON\n %s", json);
    free(json);

    [self sendRequest:userPrefRequest schemaName:@"UserPref" schemaVersion:0];
}

- (void) updateUserPref2Request:(long)userId
                 checkInEnabled:(BOOL)enabled
                     brakeAudio:(BOOL)brakeAudio
                     accelAudio:(BOOL)accelAudio {
    
}

- (void) sendMetricsRequest:(long)userId
                    tempVar:(int)tempVar
                  btCrashes:(int)btCrashes {
    
}

- (void) sendMetrics2Request:(long)userId
                         vin:(NSString*)vin
                   btCrashes:(int)btCrashes {
    
}


- (void) sendAdRequest:(NSString *) adSpaceName lat:(float)lat lon:(float)lon {
   
    avro_datum_t adRequest = avro_record(_adRequestSchema);
    
    // Set Values for ad Request
    avro_datum_t adSpaceName_datum = avro_string([adSpaceName UTF8String]);
    
    // Add Location
    avro_datum_t location_datum = avro_record(_locationSchema);

    avro_datum_t lat_datum = avro_float(lat);
    avro_datum_t lon_datum = avro_float(lon);
    if (avro_record_set(location_datum, "lat", lat_datum)
        || avro_record_set(location_datum, "lon", lon_datum)
        ) {
        NSLog(@"Unable to create Location datum structure: %s", avro_strerror());
        return;
    }
    avro_datum_decref(lat_datum);
    avro_datum_decref(lon_datum);
       
    // Now put everything in AdRequest
    if (avro_record_set(adRequest, "adSpaceName", adSpaceName_datum)
        || avro_record_set(adRequest, "location", location_datum)) {
        NSLog(@"Unable to create Ad Request datum structure: %s", avro_strerror());
        return;
    }
    
    // Clean up
    avro_datum_decref(adSpaceName_datum);
    avro_datum_decref(location_datum);
    
    // Do JSON Print
    char  *json = NULL;
    avro_datum_to_json(adRequest, 1, &json);
    NSLog(@"AdRequest in JSON\n %s", json);
    free(json);
    
    [self sendRequest:adRequest schemaName:@"AdRequest" schemaVersion:0];
    
}

- (void) sendRequest:(avro_datum_t)requestDatum
          schemaName:(NSString*)schemaName
       schemaVersion:(int)schemaVersion {
                          
    // Send binary data
	NSMutableData *data = [NSMutableData data];
    NSLog(@"Sending Request....");
    
    // Get maximum size of avro msg (json will be > than binary)
    char  *json = NULL;
    avro_datum_to_json(requestDatum, 1, &json);
    
    if (json == nil) { 
        return;
    }
    
    char buf[strlen(json)];
    free(json);
    
    // Write request into buffer
    avro_writer_t writer = avro_writer_memory(buf, sizeof(buf));
    if (avro_write_data
        (writer, NULL, requestDatum)) {
        NSLog(@"Unable to validate= %s\n",
                  avro_strerror());
        return;
    }

    // Get actual size of binary data
    int64_t size = avro_writer_tell(writer);
    
    // Write bytes to NSData obj
    [data appendBytes:buf length:size];
    
    // Set headers to specify avro binary content
    NSDictionary *headerFields = [NSDictionary dictionaryWithObjectsAndKeys:@"avro/binary", @"Content-Type",
                                  @"avro/binary", @"accept",
                                  schemaName, @"X-Avro-Schema-Name",
                                  [NSString stringWithFormat:@"%d", schemaVersion], @"X-Avro-Schema-Version",
                                  nil];
    
    NSMutableURLRequest *urlRequest = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[AdNetworking adServerUrl]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:5] autorelease];
	
	[urlRequest setAllHTTPHeaderFields:headerFields];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest setHTTPBody:data];	
	[urlRequest setHTTPShouldHandleCookies:NO];
    
    _body = [[NSMutableData alloc] init];
    _connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:YES];
    
    // Finally clean up adrequest
    avro_datum_decref(requestDatum);
    avro_writer_free(writer);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSLog(@"HTTP connection delegate received response[%@]", response);
	self.response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_body appendData:data];
}

// No more redirects; use the last URL saved
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSLog(@"Connection finished loading");

    NSData *data = self.body;
        
    if(data != nil && [data length] > 0)
    {
        // Parse response
        [self parseAdResponse:data size:[data length]];
    } 
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
	if (self.delegate != nil && [self.delegate respondsToSelector:@selector(adRequestDidFinsih)]) {
        [self.delegate adRequestDidFinsih];
    }
}

- (void) parseAdResponse:(NSData *)adResponse size:(NSUInteger)size {
    char buf[size];
    [adResponse getBytes:&buf length:size];
    
    avro_reader_t reader = avro_reader_memory(buf, sizeof(buf));
    avro_datum_t datum_out;
    
    if (avro_read_data
        (reader, _adResponseSchema, _adResponseSchema, &datum_out)) {
        NSLog(@"Unable to read data\n %s with error\n %s", buf, avro_strerror());
        return;
    }
    
    // Do JSON Print
    char  *json = NULL;
    avro_datum_to_json(datum_out, 1, &json);
    NSLog(@"AdResponse in JSON\n %s", json);
    
    // Call Delegate
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(adResponseReceived:)]) {
        [self.delegate adResponseReceived:[NSString stringWithFormat:@"%s", json]];
    }
    free(json);
    
    avro_datum_t errorsDatum = NULL, adsDatum = NULL;
    
    // Get Errors if the exists
    if(avro_record_get(datum_out, "errors", &errorsDatum) == 0) {   
        NSMutableArray*      errorsArray = [[[NSMutableArray alloc] init ] autorelease];
        int errorsCount = avro_array_size(errorsDatum);
        
        for(int k = 0; k < errorsCount; k++) {
            
            // get the k'th error element
            char *errorContent;
            avro_datum_t errorDatum = NULL;
            
            if(avro_array_get(errorsDatum, k, &errorDatum) == 0) {
                // Get the error
                avro_string_get(errorDatum, &errorContent);
                NSLog(@"Error in AdRequest: [%s]", errorContent);
                
                [errorsArray addObject:[[[NSString alloc] initWithCString:errorContent encoding:NSUTF8StringEncoding] autorelease]];
            }
        } // End of going through errors
    }

    // get the ads array
    if(avro_record_get(datum_out, "ads", &adsDatum) == 0) {
        
        int adsCount = avro_array_size(adsDatum);
        
        NSLog(@"Number of ads %d", adsCount);
        for(int j = 0; j < adsCount; j++) {
            char *adSpace, *adName;
            
            // get the j'th ad unit element
            avro_datum_t adDatum = NULL;
            if(avro_array_get(adsDatum, j, &adDatum) == 0) {
                
                // get the ad space
                avro_datum_t adSpaceDatum = NULL;
                if(avro_record_get(adDatum, "adSpace", &adSpaceDatum) == 0) {
                    avro_string_get(adSpaceDatum, &adSpace);
                    NSLog(@"adSpaceDatum is [%s]", adSpace);
                }
                else
                {
                    NSLog(@"adSpaceDatum is not present");
                    return;
                }
                
                // get the ad name
                avro_datum_t adNameDatum = NULL;
                
                if(avro_record_get(adDatum, "adName", &adNameDatum) == 0) {
                    avro_string_get(adNameDatum, &adName);
                    NSLog(@"adName is [%s]", adName);
                }
                else
                {
                    NSLog(@"ad name is not present");
                    return;
                }
            } // end if(avro_array_get(adsDatum, j, &adDatum) == 0)
        } // end for j
    }
    
    avro_datum_decref(datum_out);
    avro_reader_free(reader);
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(adRequestDidFinsih)]) {
        [self.delegate adRequestDidFinsih];
    }
}
@end
