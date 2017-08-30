'use strict';

var ReactNative = require('react-native');

var {
    NativeModules,
    DeviceEventEmitter
} = ReactNative;

const RNGeolocation = NativeModules.RNGeolocation;
const onLocationChanged = 'onLocationChangedEvent';

module.exports = {
    startLocation: function (options) {
        RNGeolocation.startLocation(options);
    },
    stopLocation: function () {
        RNGeolocation.stopLocation();
    },
    destroyLocation: function () {
        RNGeolocation.destroyLocation();
    },
    addEventListener: function (handler) {
        const listener = DeviceEventEmitter.addListener(
            onLocationChanged,
            handler
        );
        return listener;
    },
    getLocation: function (options) {
      return  RNGeolocation.getLocation(options).then(data => data);
    }
};
