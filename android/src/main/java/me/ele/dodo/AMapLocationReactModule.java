package me.ele.dodo;

import com.amap.api.location.AMapLocation;
import com.amap.api.location.AMapLocationClient;
import com.amap.api.location.AMapLocationClientOption;
import com.amap.api.location.AMapLocationClientOption.AMapLocationMode;
import com.amap.api.location.AMapLocationListener;
import com.amap.api.services.core.AMapException;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.core.PoiItem;
import com.amap.api.services.geocoder.GeocodeResult;
import com.amap.api.services.geocoder.GeocodeSearch;
import com.amap.api.services.geocoder.RegeocodeAddress;
import com.amap.api.services.geocoder.RegeocodeQuery;
import com.amap.api.services.geocoder.RegeocodeResult;
import com.amap.api.services.geocoder.StreetNumber;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.annotation.Nullable;


public class AMapLocationReactModule extends ReactContextBaseJavaModule implements AMapLocationListener, LifecycleEventListener {
    private static final String MODULE_NAME = "RNGeolocation";
    private AMapLocationClient mLocationClient;
    private AMapLocationListener mLocationListener = this;
    private final ReactApplicationContext mReactContext;
    // 是否显示详细信息
    private boolean needDetail = false;

    private GeocodeSearch geocoderSearch;

    private void sendEvent(String eventName,
                           @Nullable WritableMap params) {
        if (mReactContext != null) {
            mReactContext
                    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                    .emit(eventName, params);
        }
    }

    public AMapLocationReactModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.mReactContext = reactContext;
    }

    @Override
    public String getName() {
        return MODULE_NAME;
    }

    @Override
    public Map<String, Object> getConstants() {
        final Map<String, Object> constants = new HashMap<>();
        return constants;
    }

    @ReactMethod
    public void startLocation(@Nullable ReadableMap options) {
        mLocationClient = new AMapLocationClient(mReactContext);
        mLocationClient.setLocationListener(mLocationListener);
        mReactContext.addLifecycleEventListener(this);
        AMapLocationClientOption mLocationOption = new AMapLocationClientOption();
        needDetail = true;
        if (options != null) {
            // if (options.hasKey("needDetail")) {
            //     needDetail = options.getBoolean("needDetail");
            // }
            if (options.hasKey("accuracy")) {
                //设置定位模式为高精度模式，Battery_Saving为低功耗模式，Device_Sensors是仅设备模式
                switch (options.getString("accuracy")) {
                    case "BatterySaving":
                        mLocationOption.setLocationMode(AMapLocationMode.Battery_Saving);
                        break;
                    case "DeviceSensors":
                        mLocationOption.setLocationMode(AMapLocationMode.Device_Sensors);
                        break;
                    case "HighAccuracy":
                        mLocationOption.setLocationMode(AMapLocationMode.Hight_Accuracy);
                        break;
                    default:
                        break;
                }
            }
            if (options.hasKey("needAddress")) {
                //设置是否返回地址信息（默认返回地址信息）
                mLocationOption.setNeedAddress(options.getBoolean("needAddress"));
            }
            if (options.hasKey("onceLocation")) {
                //设置是否只定位一次,默认为false
                mLocationOption.setOnceLocation(options.getBoolean("onceLocation"));
            }
            if (options.hasKey("onceLocationLatest")) {
                //获取最近3s内精度最高的一次定位结果
                mLocationOption.setOnceLocationLatest(options.getBoolean("onceLocationLatest"));
            }
            if (options.hasKey("wifiActiveScan")) {
                //设置是否强制刷新WIFI，默认为强制刷新
                //模式为仅设备模式(Device_Sensors)时无效
                mLocationOption.setWifiActiveScan(options.getBoolean("wifiActiveScan"));
            }
            if (options.hasKey("mockEnable")) {
                //设置是否允许模拟位置,默认为false，不允许模拟位置
                //模式为低功耗模式(Battery_Saving)时无效
                mLocationOption.setMockEnable(options.getBoolean("mockEnable"));
            }
            if (options.hasKey("interval")) {
                //设置定位间隔,单位毫秒,默认为2000ms
                mLocationOption.setInterval(options.getInt("interval"));
            }
            if (options.hasKey("httpTimeOut")) {
                //设置联网超时时间
                //默认值：30000毫秒
                //模式为仅设备模式(Device_Sensors)时无效
                mLocationOption.setHttpTimeOut(options.getInt("httpTimeOut"));
            }
            if (options.hasKey("protocol")) {
                switch (options.getString("protocol")) {
                    case "http":
                        mLocationOption.setLocationProtocol(AMapLocationClientOption.AMapLocationProtocol.HTTP);
                        break;
                    case "https":
                        mLocationOption.setLocationProtocol(AMapLocationClientOption.AMapLocationProtocol.HTTPS);
                        break;
                    default:
                        break;
                }
            }
            if (options.hasKey("locationCacheEnable")) {
                mLocationOption.setLocationCacheEnable(options.getBoolean("locationCacheEnable"));
            }
        }
        this.mLocationClient.setLocationOption(mLocationOption);
        this.mLocationClient.startLocation();
    }

    @ReactMethod
    public void stopLocation() {
        if (this.mLocationClient != null) {
            this.mLocationClient.stopLocation();
        }
    }

    @ReactMethod
    public void destroyLocation() {
        if (this.mLocationClient != null) {
            this.mLocationClient.onDestroy();
        }
    }

    @Override
    public void onLocationChanged(AMapLocation amapLocation) {
        if (amapLocation != null) {
            sendEvent("onLocationChangedEvent", amapLocationToObject(amapLocation));
        }
    }

    private WritableMap amapLocationToObject(AMapLocation amapLocation) {
        WritableMap map = Arguments.createMap();
        Integer errorCode = amapLocation.getErrorCode();
        if (errorCode > 0) {
            map.putInt("errorCode", errorCode);
            map.putString("errorInfo", amapLocation.getErrorInfo());
        } else {
            Double latitude = amapLocation.getLatitude();
            Double longitude = amapLocation.getLongitude();
            map.putInt("locationType", amapLocation.getLocationType());
            map.putDouble("latitude", latitude);
            map.putDouble("longitude", longitude);
            if (needDetail) {
                // GPS Only
                map.putDouble("accuracy", amapLocation.getAccuracy());
                map.putDouble("altitude", amapLocation.getAltitude());
                map.putDouble("speed", amapLocation.getSpeed());
                map.putDouble("bearing", amapLocation.getBearing());
                map.putString("address", amapLocation.getAddress());
                map.putString("adCode", amapLocation.getAdCode());
                map.putString("country", amapLocation.getCountry());
                map.putString("province", amapLocation.getProvince());
                map.putString("poiName", amapLocation.getPoiName());
                map.putString("aoiName", amapLocation.getAoiName());
                map.putString("street", amapLocation.getStreet());
                map.putString("streetNum", amapLocation.getStreetNum());
                map.putString("city", amapLocation.getCity());
                map.putString("cityCode", amapLocation.getCityCode());
                map.putString("district", amapLocation.getDistrict());
                map.putInt("gpsStatus", amapLocation.getGpsAccuracyStatus());
                map.putString("locationDetail", amapLocation.getLocationDetail());
            }
        }
        return map;
    }

    @ReactMethod
    public void getLocation(@Nullable ReadableMap options, final Promise promise) {
        AMapLocationClient mLocationClient = new AMapLocationClient(mReactContext);
        mLocationClient.setLocationListener(new AMapLocationListener() {
            @Override
            public void onLocationChanged(AMapLocation amapLocation) {
                if (amapLocation != null) {
                    promise.resolve(amapLocationToObject(amapLocation));
                } else {
                    promise.reject("-1", "null");
                }
            }
        });
        mReactContext.addLifecycleEventListener(this);
        AMapLocationClientOption mLocationOption = makeClientOption(options, true);
        mLocationClient.setLocationOption(mLocationOption);
        mLocationClient.startLocation();

    }

    AMapLocationClientOption makeClientOption(@Nullable ReadableMap options, boolean onceLocation) {
        AMapLocationClientOption mLocationOption = new AMapLocationClientOption();
        mLocationOption.setOnceLocation(onceLocation);
        needDetail = true;
        if (options != null) {
            // if (options.hasKey("needDetail")) {
            //     needDetail = options.getBoolean("needDetail");
            // }
            if (options.hasKey("accuracy")) {
                //设置定位模式为高精度模式，Battery_Saving为低功耗模式，Device_Sensors是仅设备模式
                switch (options.getString("accuracy")) {
                    case "BatterySaving":
                        mLocationOption.setLocationMode(AMapLocationMode.Battery_Saving);
                        break;
                    case "DeviceSensors":
                        mLocationOption.setLocationMode(AMapLocationMode.Device_Sensors);
                        break;
                    case "HighAccuracy":
                        mLocationOption.setLocationMode(AMapLocationMode.Hight_Accuracy);
                        break;
                    default:
                        break;
                }
            }
            if (options.hasKey("needAddress")) {
                //设置是否返回地址信息（默认返回地址信息）
                mLocationOption.setNeedAddress(options.getBoolean("needAddress"));
            }
            if (options.hasKey("onceLocation")) {
                //设置是否只定位一次,默认为false
//                mLocationOption.setOnceLocation(options.getBoolean("onceLocation"));
            }
            if (options.hasKey("onceLocationLatest")) {
                //获取最近3s内精度最高的一次定位结果
                mLocationOption.setOnceLocationLatest(options.getBoolean("onceLocationLatest"));
            }
            if (options.hasKey("wifiActiveScan")) {
                //设置是否强制刷新WIFI，默认为强制刷新
                //模式为仅设备模式(Device_Sensors)时无效
                mLocationOption.setWifiActiveScan(options.getBoolean("wifiActiveScan"));
            }
            if (options.hasKey("mockEnable")) {
                //设置是否允许模拟位置,默认为false，不允许模拟位置
                //模式为低功耗模式(Battery_Saving)时无效
                mLocationOption.setMockEnable(options.getBoolean("mockEnable"));
            }
            if (options.hasKey("interval")) {
                //设置定位间隔,单位毫秒,默认为2000ms
                mLocationOption.setInterval(options.getInt("interval"));
            }
            if (options.hasKey("httpTimeOut")) {
                //设置联网超时时间
                //默认值：30000毫秒
                //模式为仅设备模式(Device_Sensors)时无效
                mLocationOption.setHttpTimeOut(options.getInt("httpTimeOut"));
            }
            if (options.hasKey("protocol")) {
                switch (options.getString("protocol")) {
                    case "http":
                        mLocationOption.setLocationProtocol(AMapLocationClientOption.AMapLocationProtocol.HTTP);
                        break;
                    case "https":
                        mLocationOption.setLocationProtocol(AMapLocationClientOption.AMapLocationProtocol.HTTPS);
                        break;
                    default:
                        break;
                }
            }
            if (options.hasKey("locationCacheEnable")) {
                mLocationOption.setLocationCacheEnable(options.getBoolean("locationCacheEnable"));
            }
        }
        return mLocationOption;
    }

    @ReactMethod
    public void getAddress(ReadableMap map, final Promise promise) {
        double lat = 0;
        double lng = 0;
        if (map.hasKey("lat")) {
            lat = map.getDouble("lat");
        }
        if (map.hasKey("lng")) {
            lng = map.getDouble("lng");
        }
        if (geocoderSearch == null) {
            geocoderSearch = new GeocodeSearch(mReactContext);
        }
        geocoderSearch.setOnGeocodeSearchListener(new GeocodeSearch.OnGeocodeSearchListener() {
            @Override
            public void onRegeocodeSearched(RegeocodeResult regeocodeResult, int code) {//

                if (code == AMapException.CODE_AMAP_SUCCESS) {
                    double lat;
                    double lng;

                    RegeocodeAddress addr = regeocodeResult.getRegeocodeAddress();
                    WritableMap result = Arguments.createMap();
                    result.putString("address", addr.getFormatAddress());
                    result.putString("province", addr.getProvince());
                    result.putString("city", addr.getCity());
                    result.putString("citycode", addr.getCityCode());
                    result.putString("district", addr.getDistrict());
                    result.putString("adcode", addr.getAdCode());
                    result.putString("township", addr.getTownship());
                    result.putString("towncode", addr.getTowncode());
                    result.putString("neighborhood", addr.getNeighborhood());
                    result.putString("building", addr.getBuilding());

                    StreetNumber streetNumber = addr.getStreetNumber();
                    result.putString("street", streetNumber.getStreet());
                    result.putString("number", streetNumber.getNumber());


                    LatLonPoint point = streetNumber.getLatLonPoint();
                    if (point != null) {
                        lat = point.getLatitude();
                        lng = point.getLongitude();
                    } else {
                        lat = 0.0F;
                        lng = 0.0F;
                    }
                    result.putDouble("streetLatitude", lat);
                    result.putDouble("streetLongitude", lng);
                    result.putString("distance", String.valueOf(streetNumber.getDistance()));
                    result.putString("direction", streetNumber.getDirection());

                    List<PoiItem> list = addr.getPois();
                    if (list != null && list.size() > 0) {
                        PoiItem first = list.get(0);
                        WritableMap pois = Arguments.createMap();
                        pois.putString("uid", first.getPoiId());//POI全局唯一ID
                        pois.putString("name", first.getAdName());///名称
                        pois.putString("uid", first.getTypeDes());//兴趣点类型
                        pois.putString("uid", first.getTypeCode());//类型编码

                        point = first.getLatLonPoint();
                        if (point != null) {
                            lat = point.getLatitude();
                            lng = point.getLongitude();
                        } else {
                            lat = 0.0F;
                            lng = 0.0F;
                        }
                        pois.putDouble("latitude", lat);//纬度(垂直方向）
                        pois.putDouble("longitude", lng);//经度（水平方向）

                        pois.putString("address", first.getTitle());//地址
                        pois.putString("tel", first.getTel());//电话
                        pois.putString("distance", String.valueOf(first.getDistance()));///距中心点的距离，单位米。在周边搜索时有效

                        pois.putString("parkingType", first.getParkingType());///停车场类型，地上、地下、路边
                        pois.putString("shopID", first.getShopID());//商铺id
                        pois.putString("postcode", first.getPostcode());//邮编
                        pois.putString("website", first.getWebsite());//网址
                        pois.putString("email", first.getEmail());//电子邮件
                        pois.putString("province", first.getProvinceName());//省
                        pois.putString("pcode", first.getProvinceCode());//省编码
                        pois.putString("city", first.getCityName());//城市
                        pois.putString("pcode", first.getCityCode());//城市编码
                        pois.putString("district", first.getAdName());///区域名称
                        pois.putString("adcode", first.getAdCode());//城区域名称

                        pois.putString("gridcode", first.getTypeCode());
                        pois.putString("direction", first.getDirection());
                        pois.putString("hasIndoorMap", first.isIndoorMap() ? "1" : "0 ");//是否有室内地图
                        pois.putString("businessArea", first.getBusinessArea());//所在商圈

                        point = first.getEnter();
                        if (point != null) {
                            lat = point.getLatitude();
                            lng = point.getLongitude();
                        } else {
                            lat = 0.0F;
                            lng = 0.0F;
                        }
                        pois.putDouble("enterLatitude", lat);
                        pois.putDouble("enterLongitude", lng);
                        point = first.getEnter();
                        if (point != null) {
                            lat = point.getLatitude();
                            lng = point.getLongitude();
                        } else {
                            lat = 0.0F;
                            lng = 0.0F;
                        }
                        pois.putDouble("exitLatitude", lat);
                        pois.putDouble("exitLongitude", lng);

                        result.putMap("pois", pois);
                        //兴趣区域信息 AMapAOI 数组
                    }
                    promise.resolve(result);
                }
            }

            @Override
            public void onGeocodeSearched(GeocodeResult geocodeResult, int code) {

            }
        });
        LatLonPoint latLonPoint = new LatLonPoint(lat, lng);
        RegeocodeQuery query = new RegeocodeQuery(latLonPoint, 200, GeocodeSearch.AMAP);

        geocoderSearch.getFromLocationAsyn(query);
    }

    @Override
    public void onHostResume() {

    }

    @Override
    public void onHostPause() {

    }

    @Override
    public void onHostDestroy() {
        if (this.mLocationClient != null) {
            this.mLocationClient.onDestroy();
        }
    }
}
