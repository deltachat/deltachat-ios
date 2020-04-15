import Foundation
import CoreLocation
import DcCore

class LocationManager: NSObject, CLLocationManagerDelegate {

    let locationManager: CLLocationManager
    let dcContext: DcContext
    var lastLocation: CLLocation?

    init(context: DcContext) {
        dcContext = context
        locationManager = CLLocationManager()
        locationManager.distanceFilter = 25
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = CLActivityType.fitness
        super.init()
        locationManager.delegate = self

    }

    func shareLocation(chatId: Int, duration: Int) {
        dcContext.sendLocationsToChat(chatId: chatId, seconds: duration)
        if duration > 0 {
            locationManager.requestAlwaysAuthorization()
        } else {
            if !dcContext.isSendingLocationsToChat(chatId: 0) {
                locationManager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.debug("LOCATION: didUpdateLocations")

        guard let newLocation = locations.last else {
            logger.debug("LOCATION: new location is emtpy")
            return
        }

        let isBetter = isBetterLocation(newLocation: newLocation, lastLocation: lastLocation)
        logger.debug("LOCATION: isBetterLocation: \(isBetter)")
        if isBetter {
            if dcContext.isSendingLocationsToChat(chatId: 0) {
                dcContext.setLocation(latitude: newLocation.coordinate.latitude,
                                      longitude: newLocation.coordinate.longitude,
                                      accuracy: newLocation.horizontalAccuracy)
                lastLocation = newLocation
            } else {
                locationManager.stopUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            logger.warning("LOCATION MANAGER: didFailWithError: \(error.localizedDescription)")
           // Location updates are not authorized.
           disableLocationStreamingInAllChats()
           return
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        logger.debug("LOCATION MANAGER: didChangeAuthorization: \(status)")
        switch status {
        case .denied, .restricted:
            disableLocationStreamingInAllChats()
        case .authorizedWhenInUse:
            logger.warning("Location streaming will only work as long as the app is in foreground.")
            locationManager.startUpdatingLocation()
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func disableLocationStreamingInAllChats() {
        if dcContext.isSendingLocationsToChat(chatId: 0) {
            let dcChatlist = dcContext.getChatlist(flags: 0, queryString: nil, queryId: 0)
            for i in 0...dcChatlist.length {
                let chatId = dcChatlist.getChatId(index: i)
                if dcContext.isSendingLocationsToChat(chatId: chatId) {
                    dcContext.sendLocationsToChat(chatId: chatId, seconds: 0)
                }
            }
            locationManager.stopUpdatingLocation()
        }
    }

    func isBetterLocation(newLocation: CLLocation, lastLocation: CLLocation?) -> Bool {
        guard let lastLocation = lastLocation else {
            return !isNewLocationOutdated(newLocation: newLocation) && hasValidAccuracy(newLocation: newLocation)
        }

        return !isNewLocationOutdated(newLocation: newLocation) &&
            hasValidAccuracy(newLocation: newLocation) &&
            (isMoreAccurate(newLocation: newLocation, lastLocation: lastLocation) && hasLocationChanged(newLocation: newLocation, lastLocation: lastLocation) ||
            hasLocationSignificantlyChanged(newLocation: newLocation, lastLocation: lastLocation))
    }

    func hasValidAccuracy(newLocation: CLLocation) -> Bool {
        return newLocation.horizontalAccuracy >= 0
    }

    func isMoreAccurate(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
//        logger.debug("LOCATION: isMoreAccurate \(lastLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 0)")
        return lastLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 0
    }

    func hasLocationChanged(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
//        logger.debug("LOCATION: hasLocationChanged \(newLocation.distance(from: lastLocation) > 10)")
        return newLocation.distance(from: lastLocation) > 10
    }

    func hasLocationSignificantlyChanged(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
//        logger.debug("LOCATION: hasLocationSignificantlyChanged \(newLocation.distance(from: lastLocation) > 30)")
        return newLocation.distance(from: lastLocation) > 30
    }

    /**
        Locations can be cached by iOS, timestamp comparison checks if the location has been tracked within the last 5 minutes
     */
    func isNewLocationOutdated(newLocation: CLLocation) -> Bool {
        let timeDelta = DateUtils.getRelativeTimeInSeconds(timeStamp: Double(newLocation.timestamp.timeIntervalSince1970))
 //       logger.debug("LOCATION: isLocationOutdated timeDelta: \(timeDelta) -> \(Double(Time.fiveMinutes)) -> \(timeDelta < Double(Time.fiveMinutes))")
        return timeDelta > Double(Time.fiveMinutes)
    }
    
}
