import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {

    let locationManager: CLLocationManager
    let dcContext: DcContext
    var lastLocation: CLLocation?

    init(context: DcContext) {
        dcContext = context
        locationManager = CLLocationManager()
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        //locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true
        //TODO: check which activity Type is needed
        locationManager.activityType = CLActivityType.other
        super.init()
        locationManager.delegate = self

    }

    func shareLocation(chatId: Int, duration: Int) {
        dcContext.sendLocationsToChat(chatId: chatId, seconds: duration)
        if duration > 0 {
            startLocationTracking()
        } else {
            stopLocationTracking()
        }
    }

    func startLocationTracking() {
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()

    }

    func stopLocationTracking() {
        locationManager.stopUpdatingLocation()

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
            dcContext.setLocation(latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude, accuracy: newLocation.horizontalAccuracy)
            lastLocation = newLocation
        }
    }

    func isBetterLocation(newLocation: CLLocation, lastLocation: CLLocation?) -> Bool {
        guard let lastLocation = lastLocation else {
            return !isNewLocationOutdated(newLocation: newLocation) && hasValidAccuracy(newLocation: newLocation)
        }

        return !isNewLocationOutdated(newLocation: newLocation) &&
            hasValidAccuracy(newLocation: newLocation) &&
            (isSignificantlyMoreAccurate(newLocation: newLocation, lastLocation: lastLocation) ||
            isMoreAccurate(newLocation: newLocation, lastLocation: lastLocation) && hasLocationChanged(newLocation: newLocation, lastLocation: lastLocation) ||
            hasLocationSignificantlyChanged(newLocation: newLocation, lastLocation: lastLocation))
    }

    func hasValidAccuracy(newLocation: CLLocation) -> Bool {
        logger.debug("LOCATION: hasValidAccuracy: \(newLocation.horizontalAccuracy > 0)")
        return newLocation.horizontalAccuracy > 0
    }

    func isSignificantlyMoreAccurate(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
        logger.debug("LOCATION isSignificantlyMoreAccurate: \(lastLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 25)")
        return lastLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 25
    }

    func isMoreAccurate(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
        logger.debug("LOCATION: isMoreAccurate \(lastLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 0)")
        return lastLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 0
    }

    func hasLocationChanged(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
        logger.debug("LOCATION: hasLocationChanged \(newLocation.distance(from: lastLocation) > 10)")
        return newLocation.distance(from: lastLocation) > 10
    }

    func hasLocationSignificantlyChanged(newLocation: CLLocation, lastLocation: CLLocation) -> Bool {
        logger.debug("LOCATION: hasLocationSignificantlyChanged \(newLocation.distance(from: lastLocation) > 30)")
        return newLocation.distance(from: lastLocation) > 30
    }

    /**
        Locations can be cached by iOS, timestamp comparison checks if the location has been tracked within the last 5 minutes
     */
    func isNewLocationOutdated(newLocation: CLLocation) -> Bool{
        let timeDelta = DateUtils.getRelativeTimeInSeconds(timeStamp: Double(newLocation.timestamp.timeIntervalSince1970))
        return timeDelta < Double(Time.fiveMinutes)
    }
    
}
