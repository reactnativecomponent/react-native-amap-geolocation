//
//  RNGeolocation.m
//  RNGeolocation
//
//  Created by Dowin on 2017/8/11.
//  Copyright © 2017年 Dowin. All rights reserved.
//

#import "RNGeolocation.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>

#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>

typedef void (^resolveBack)(NSDictionary *location);
typedef void (^resolveBackAddress)(NSDictionary *strAddress);

static NSInteger const kDefaultLocationTimeout  = 10;
static NSInteger const kDefaultReGeocodeTimeout = 5;

static NSString * const LocationChangeEvent = @"onLocationChangedEvent";

static NSString * const kErrorCodeKey = @"errorCode";
static NSString * const kErrorInfoKey = @"errorInfo";
@interface RNGeolocation () <AMapLocationManagerDelegate,AMapSearchDelegate>

@property (nonatomic, strong) AMapLocationManager         *locationManager;

@property (strong, nonatomic) AMapSearchAPI *searchManager;

@property (nonatomic, copy  ) AMapLocatingCompletionBlock completionBlock;

@property (nonatomic, strong) resolveBack resolveBack;

@property (strong, nonatomic) resolveBackAddress resolveBackAddress;

@property (nonatomic , strong) NSDictionary *souces;

@property (nonatomic, assign) BOOL isgetState;
@end
@implementation RNGeolocation
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE(RNGeolocation);

#pragma mark - Lifecycle
- (void)dealloc {
    self.locationManager = nil;
    self.completionBlock = nil;
    self.searchManager = nil;
}

RCT_EXPORT_METHOD(startLocation:(NSDictionary *)options) {
    [self startGLocation:options];
    self.isgetState = NO;
}
RCT_EXPORT_METHOD(getLocation:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
    self.isgetState = YES;
    [self startGLocation:options];
    __weak typeof(self)weakSelf = self;
    self.resolveBack = ^(NSDictionary *location) {
        NSString *str = [weakSelf dictionaryToJson:weakSelf.souces];
        NSString *str1 = [weakSelf dictionaryToJson:location];
        if (![str isEqualToString:str1]) {
            weakSelf.souces = location;
            resolve(location);
        }
    };
}
- (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
RCT_EXPORT_METHOD(stopLocation) {
    [self.locationManager stopUpdatingLocation];
}

RCT_EXPORT_METHOD(destroyLocation) {
    [self.locationManager stopUpdatingLocation];
    self.locationManager = nil;
}
//返回逆地理位置
RCT_EXPORT_METHOD(getAddress:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
    [self setupAMapReGeocodeSearch:options];
    self.resolveBackAddress  = ^(NSDictionary *strAddress) {
        resolve(strAddress);
    };
}

- (NSDictionary *)constantsToExport {
    return nil;
}

-(void)startGLocation:(NSDictionary *)options{
    _souces = [NSDictionary dictionary];
    // set default value
    CLLocationAccuracy accuracy             = kCLLocationAccuracyHundredMeters;
    CLLocationDistance distanceFilter       = kCLDistanceFilterNone;
    BOOL allowsBackgroundLocationUpdates    = NO;
    BOOL locatingWithReGeocode              = NO;
    BOOL onceLocation                       = NO;
    BOOL pausesLocationUpdatesAutomatically = YES;
    NSInteger locationTimeout               = kDefaultLocationTimeout;
    NSInteger reGeocodeTimeout              = kDefaultReGeocodeTimeout;
    
    if(options &&
       [options isKindOfClass:[NSDictionary class]]) {
        
        /**
         *  accuracy
         *  精度值设定，值类型若为字符串，则使用预设值
         *  若为数值，则使用具体数值，其他使用默认值
         */
        id accuracyValue = options[@"accuracy"];
        if ([accuracyValue isKindOfClass:[NSString class]]) {
            if ([accuracyValue isEqualToString:@"kCLLocationAccuracyBest"]) {
                accuracy = kCLLocationAccuracyBest;
            } else if ([accuracyValue isEqualToString:@"kCLLocationAccuracyNearestTenMeters"]) {
                accuracy = kCLLocationAccuracyNearestTenMeters;
            } else if ([accuracyValue isEqualToString:@"kCLLocationAccuracyHundredMeters"]) {
                accuracy = kCLLocationAccuracyHundredMeters;
            } else if ([accuracyValue isEqualToString:@"kCLLocationAccuracyKilometer"]) {
                accuracy = kCLLocationAccuracyKilometer;
            } else if ([accuracyValue isEqualToString:@"kCLLocationAccuracyThreeKilometers"]) {
                accuracy = kCLLocationAccuracyThreeKilometers;
            }
        } else if ([accuracyValue isKindOfClass:[NSNumber class]]) {
            accuracy = [accuracyValue doubleValue];
        }
        
        /**
         *  distanceFilter
         *  对于非数字，采用默认值 kCLDistanceFilterNone
         */
        id distanceFilterValue = options[@"distanceFilter"];
        if ([distanceFilterValue isKindOfClass:[NSNumber class]]) {
            distanceFilter = [distanceFilterValue doubleValue];
        }
        
        /**
         *  allowsBackgroundLocationUpdates
         *  针对 iOS 9.0+，允许后台位置更新，注意对应 background mode 配置
         */
        allowsBackgroundLocationUpdates = [options[@"allowsBackgroundLocationUpdates"] boolValue];
        
        /**
         *  locatingWithReGeocode
         *  是否逆地理位置编码
         */
        locatingWithReGeocode = [options[@"locatingWithReGeocode"] boolValue];
        
        /**
         *  locatingWithReGeocode
         *  是否逆地理位置编码
         */
        onceLocation = [options[@"onceLocation"] boolValue];
        
        /**
         *  locatingWithReGeocode
         *  是否逆地理位置编码
         */
        pausesLocationUpdatesAutomatically = [options[@"pausesLocationUpdatesAutomatically"] boolValue];
        
        /**
         *  locatingWithReGeocode
         *  是否逆地理位置编码
         */
        locationTimeout = [options[@"locationTimeout"] intValue];
        
        /**
         *  locatingWithReGeocode
         *  是否逆地理位置编码
         */
        reGeocodeTimeout = [options[@"reGeocodeTimeout"] intValue];
    }
    
    /**
     *  更新定位管理器设置
     */
    [self.locationManager setDesiredAccuracy:accuracy];
    [self.locationManager setDistanceFilter:distanceFilter];
    
    [self.locationManager setAllowsBackgroundLocationUpdates:allowsBackgroundLocationUpdates];
    [self.locationManager setLocatingWithReGeocode:YES];
    [self.locationManager setPausesLocationUpdatesAutomatically:pausesLocationUpdatesAutomatically];
    
    [self.locationManager setLocationTimeout:locationTimeout];
    [self.locationManager setReGeocodeTimeout:reGeocodeTimeout];
    
    /**
     *  是否单次定位，若多次调用当前方法
     *  且 onceLocation 更新为 true 时，若当前开启持续定位，则停止
     */
    if (onceLocation) {
        [self.locationManager stopUpdatingLocation];
        [self.locationManager requestLocationWithReGeocode:locatingWithReGeocode
                                           completionBlock:self.completionBlock];
    } else {
        [self.locationManager startUpdatingLocation];
    }
    
}
#pragma mark - Setter & Getter
- (AMapLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[AMapLocationManager alloc] init];
        _locationManager.delegate = self;
    }
    return _locationManager;
}

- (AMapLocatingCompletionBlock)completionBlock {
    
    if (!_completionBlock) {
        __weak typeof(self)weakSelf = self;
        _completionBlock = ^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            NSMutableDictionary *resultDic = [NSMutableDictionary dictionary];
            if (error) {
                resultDic[kErrorCodeKey] = @(error.code);
                resultDic[kErrorInfoKey] = error.localizedDescription;
            } else {
                if (location) {
                    resultDic[@"horizontalAccuracy"] = @(location.horizontalAccuracy);
                    resultDic[@"verticalAccuracy"]   = @(location.verticalAccuracy);
                    resultDic[@"latitude"]           = @(location.coordinate.latitude);
                    resultDic[@"longitude"]          = @(location.coordinate.longitude);
                    resultDic[@"altitude"]           = @(location.altitude);
                    
                    if (regeocode) {
                        resultDic[@"address"]   = regeocode.formattedAddress ? : [NSNull null];
                        resultDic[@"country"]   = regeocode.country ? : [NSNull null];
                        resultDic[@"province"]  = regeocode.province ? : [NSNull null];
                        resultDic[@"city"]      = regeocode.city ? : [NSNull null];
                        resultDic[@"district"]  = regeocode.district ? : [NSNull null];
                        resultDic[@"cityCode"]  = regeocode.citycode ? : [NSNull null];
                        resultDic[@"adCode"]    = regeocode.adcode ? : [NSNull null];
                        resultDic[@"street"]    = regeocode.street ? : [NSNull null];
                        resultDic[@"number"]    = regeocode.number ? : [NSNull null];
                        resultDic[@"poiName"]   = regeocode.POIName ? : [NSNull null];
                        resultDic[@"aoiName"]   = regeocode.AOIName ? : [NSNull null];
                    }
                } else {
                    resultDic[kErrorCodeKey] = @(-1);
                    resultDic[kErrorInfoKey] = @"定位结果不存在";
                }
            }
            
            if (weakSelf.isgetState) {
                
                weakSelf.resolveBack(resultDic);
                [weakSelf.locationManager stopUpdatingLocation];
            }else{
                [weakSelf.bridge.eventDispatcher sendAppEventWithName:LocationChangeEvent
                                                             body:resultDic];
            }
        };
    }
    return _completionBlock;
}

#pragma mark - AMapLocationManagerDelegate
- (void)amapLocationManager:(AMapLocationManager *)manager didFailWithError:(NSError *)error {
    if (self.completionBlock) {
        self.completionBlock(nil, nil, error);
    }
}

- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location {
    if (self.completionBlock) {
        self.completionBlock(location, nil, nil);
        
    }
}

- (void)amapLocationManager:(AMapLocationManager *)manager
          didUpdateLocation:(CLLocation *)location reGeocode:(AMapLocationReGeocode *)reGeocode {
    
    if (self.completionBlock) {
        
        self.completionBlock(location, reGeocode, nil);
    }
}

#pragma mark searchManager

- (AMapSearchAPI *)searchManager {
    if (!_searchManager) {
        _searchManager = [[AMapSearchAPI alloc] init];
        _searchManager.delegate = self;
    }
    return _searchManager;
}

- (void)setupAMapReGeocodeSearch:(NSDictionary *)location{
    AMapReGeocodeSearchRequest *regeo = [[AMapReGeocodeSearchRequest alloc] init];
    CLLocationDegrees latitude = [[location objectForKey:@"lat"] doubleValue];
    CLLocationDegrees longitude = [[location objectForKey:@"lng"] doubleValue];
    regeo.location = [AMapGeoPoint locationWithLatitude:latitude longitude:longitude];
    regeo.requireExtension = YES;
    
    [self.searchManager AMapReGoecodeSearch:regeo];
}

#pragma mark ---AMapSearchDelegate

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response{
    if (response.regeocode != nil)
    {
        //获得地址
        NSMutableDictionary *addressDict = [NSMutableDictionary dictionary];
        NSString *strAddress = response.regeocode.formattedAddress;
        [addressDict setObject:strAddress forKey:@"address"];
//        [addressDict setObject:response.regeocode.roads forKey:@"roads"];///道路信息 AMapRoad 数组
//        [addressDict setObject:response.regeocode.roadinters forKey:@"roadinters"];///道路路口信息 AMapRoadInter 数组
//        [addressDict setObject:response.regeocode.pois forKey:@"pois"];///兴趣点信息 AMapPOI 数组
        NSArray *poisArr = response.regeocode.pois;//兴趣点
        if(poisArr.count){
            AMapPOI *poi = poisArr.firstObject;
            NSMutableDictionary *poiDict = [NSMutableDictionary dictionary];
            [poiDict setObject:poi.uid forKey:@"uid"];///POI全局唯一ID
            [poiDict setObject:poi.name forKey:@"name"];///名称
            [poiDict setObject:poi.type forKey:@"type"];///兴趣点类型
            [poiDict setObject:poi.typecode forKey:@"typecode"];///类型编码
            [poiDict setObject:[NSString stringWithFormat:@"%f",poi.location.latitude] forKey:@"latitude"];///纬度(垂直方向）
            [poiDict setObject:[NSString stringWithFormat:@"%f",poi.location.longitude] forKey:@"longitude"];///经度（水平方向）
            [poiDict setObject:poi.address forKey:@"address"];///地址
            [poiDict setObject:poi.tel forKey:@"tel"];///电话
            [poiDict setObject:[NSString stringWithFormat:@"%zd",poi.distance] forKey:@"distance"];///距中心点的距离，单位米。在周边搜索时有效
            [poiDict setObject:poi.parkingType forKey:@"parkingType"];///停车场类型，地上、地下、路边
            
            [poiDict setObject:poi.shopID forKey:@"shopID"];///商铺id
            [poiDict setObject:poi.postcode forKey:@"postcode"];///邮编
            [poiDict setObject:poi.website forKey:@"website"];///网址
            [poiDict setObject:poi.email forKey:@"email"];///电子邮件
            [poiDict setObject:poi.province forKey:@"province"];///省
            [poiDict setObject:poi.pcode forKey:@"pcode"];///省编码
            [poiDict setObject:poi.city forKey:@"city"];///城市名称
            [poiDict setObject:poi.citycode forKey:@"citycode"];///城市编码
            [poiDict setObject:poi.district forKey:@"district"];///区域名称
            [poiDict setObject:poi.adcode forKey:@"adcode"];///区域编码
            
            [poiDict setObject:poi.gridcode forKey:@"gridcode"];///地理格ID
            [poiDict setObject:[NSString stringWithFormat:@"%f",poi.enterLocation.latitude] forKey:@"enterLatitude"];///入口纬度
            [poiDict setObject:[NSString stringWithFormat:@"%f",poi.enterLocation.longitude] forKey:@"enterLongitude"];///入口经度
            [poiDict setObject:[NSString stringWithFormat:@"%f",poi.exitLocation.latitude] forKey:@"exitLatitude"];///出口纬度
            [poiDict setObject:[NSString stringWithFormat:@"%f",poi.exitLocation.longitude] forKey:@"exitLongitude"];///出口经度
            [poiDict setObject:poi.direction forKey:@"direction"];///方向
            [poiDict setObject:[NSNumber numberWithBool:poi.hasIndoorMap] forKey:@"hasIndoorMap"];///是否有室内地图
            [poiDict setObject:poi.businessArea forKey:@"businessArea"];///所在商圈
            [addressDict setObject:poiDict forKey:@"pois"];///方向

        }
//        [addressDict setObject:response.regeocode.aois forKey:@"aois"];///兴趣区域信息 AMapAOI 数组
        
        AMapAddressComponent *addressComponent = response.regeocode.addressComponent;
//        NSMutableDictionary *componentDict = [NSMutableDictionary dictionary];
        [addressDict setObject:addressComponent.province forKey:@"province"];///省/直辖市
        [addressDict setObject:addressComponent.city forKey:@"city"];///市
        [addressDict setObject:addressComponent.citycode forKey:@"citycode"];///城市编码
        [addressDict setObject:addressComponent.district forKey:@"district"];///区
        [addressDict setObject:addressComponent.adcode forKey:@"adcode"];///区域编码
        [addressDict setObject:addressComponent.township forKey:@"township"];///乡镇街道
        [addressDict setObject:addressComponent.towncode forKey:@"towncode"];///乡镇街道编码
        [addressDict setObject:addressComponent.neighborhood forKey:@"neighborhood"];///社区
        [addressDict setObject:addressComponent.building forKey:@"building"];///建筑
//        [componentDict setObject:addressComponent.businessAreas forKey:@"businessAreas"];///商圈列表 AMapBusinessArea 数组
        
        AMapStreetNumber *streetNumber = addressComponent.streetNumber;
//        NSMutableDictionary *streetNumberDict = [NSMutableDictionary dictionary];
        [addressDict setObject:streetNumber.street forKey:@"street"];///街道名称
        [addressDict setObject:streetNumber.number forKey:@"number"];///门牌号
        [addressDict setObject:[NSString stringWithFormat:@"%f",streetNumber.location.longitude] forKey:@"streetLongitude"];///坐标点
        [addressDict setObject:[NSString stringWithFormat:@"%f",streetNumber.location.latitude] forKey:@"streetLatitude"];///坐标点
        [addressDict setObject:[NSString stringWithFormat:@"%zd",streetNumber.distance] forKey:@"distance"];///距离（单位：米）
        [addressDict setObject:streetNumber.direction forKey:@"direction"];///方向
//        [componentDict setObject:streetNumberDict forKey:@"streetNumber"];///门牌信息
//        [addressDict setObject:componentDict forKey:@"AMapAddressComponent"];///地址组成要素
        NSLog(@"----------addressDict:%@",addressDict);
        if (self.resolveBackAddress) {
            self.resolveBackAddress(addressDict);
        }
    }
}

- (void)AMapSearchRequest:(id)request didFailWithError:(NSError *)error
{
    if (self.resolveBackAddress) {
        NSMutableDictionary *addressDict = [NSMutableDictionary dictionary];
        self.resolveBackAddress(addressDict);
    }
}


@end
