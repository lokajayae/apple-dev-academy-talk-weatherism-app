//
//  LocationManager.swift
//  WeatherismApp
//
//  Created by Evan Lokajaya on 05/08/25.
//

import Foundation
import CoreLocation

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var isRequestingLocation = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        errorMessage = nil
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            return
            
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable location access in Settings."
            return
            
        case .authorizedWhenInUse, .authorizedAlways:
            isRequestingLocation = true
            locationManager.requestLocation()
            
        @unknown default:
            errorMessage = "Unknown location authorization status"
            return
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isRequestingLocation = false
        location = locations.first
        errorMessage = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequestingLocation = false
        
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                errorMessage = "Unable to find location. Please try again."
            case .denied:
                errorMessage = "Location access denied. Please enable location access in Settings."
            case .network:
                errorMessage = "Network error. Please check your connection and try again."
            default:
                errorMessage = "Location error: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Location error: \(error.localizedDescription)"
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Permission granted, automatically request location
                self.requestLocation()
                
            case .denied, .restricted:
                self.errorMessage = "Location access denied. Please enable location access in Settings."
                
            case .notDetermined:
                // Still waiting for user decision
                break
                
            @unknown default:
                self.errorMessage = "Unknown location authorization status"
            }
        }
    }
}
