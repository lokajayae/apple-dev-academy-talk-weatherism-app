//
//  WeatherViewModel.swift
//  WeatherismApp
//
//  Created by Agustinus Pongoh on 05/08/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Weather ViewModel
@MainActor
class WeatherViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var weatherData: WeatherResponse?
    @Published var currentLocation: GeocodingResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let weatherService: WeatherServiceProtocol
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(weatherService: WeatherServiceProtocol = WeatherService()) {
        self.weatherService = weatherService
        setupLocationObserver()
    }
    
    // MARK: - Private Setup Methods
    private func setupLocationObserver() {
        // Observe successful location updates
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                Task {
                    await self?.fetchWeatherForLocation(location)
                }
            }
            .store(in: &cancellables)
        
        // Observe location manager errors
        locationManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.isLoading = false
                self?.errorMessage = error
            }
            .store(in: &cancellables)
        
        // Observe loading state from location manager
        locationManager.$isRequestingLocation
            .sink { [weak self] isRequesting in
                if isRequesting {
                    self?.isLoading = true
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func searchWeather(for city: String) {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else {
            errorMessage = "Please enter a city name"
            return
        }
        
        Task {
            await fetchWeather(for: trimmedCity)
        }
    }
    
    func refreshWeather() {
        if let location = currentLocation {
            Task {
                await fetchWeather(for: location.name)
            }
        } else {
            requestCurrentLocationWeather()
        }
    }
    
    func requestCurrentLocationWeather() {
        errorMessage = nil
        
        // Check authorization status first
        switch locationManager.authorizationStatus {
        case .notDetermined:
            // Request permission first
            locationManager.requestLocationPermission()
            
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable location access in Settings to get weather for your current location."
            
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission already granted, request location
            locationManager.requestLocation()
            
        @unknown default:
            errorMessage = "Unable to access location services"
        }
    }
    
    // MARK: - Private Methods
    private func fetchWeather(for city: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (weather, location) = try await weatherService.fetchWeather(for: city)
            
            weatherData = weather
            currentLocation = location
        } catch {
            errorMessage = error.localizedDescription
            weatherData = nil
            currentLocation = nil
        }
        
        isLoading = false
    }
    
    private func fetchWeatherForLocation(_ location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use reverse geocoding to get city name from coordinates
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                errorMessage = "Could not determine location information"
                isLoading = false
                return
            }
            
            // Try to get the best available location name
            let cityName = placemark.locality
                ?? placemark.administrativeArea
                ?? placemark.subAdministrativeArea
                ?? placemark.country
                ?? "Unknown Location"
            
            let (weather, locationResult) = try await weatherService.fetchWeather(for: cityName)
            
            weatherData = weather
            currentLocation = locationResult
        } catch {
            errorMessage = error.localizedDescription
            weatherData = nil
            currentLocation = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    func weatherIconName(for weatherCode: Int) -> String {
        switch weatherCode {
        case 0: return "sun.max" // Clear sky
        case 1, 2, 3: return "cloud.sun" // Mainly clear, partly cloudy, and overcast
        case 45, 48: return "cloud.fog" // Fog and depositing rime fog
        case 51, 53, 55: return "cloud.drizzle" // Drizzle: Light, moderate, and dense intensity
        case 56, 57: return "cloud.sleet" // Freezing Drizzle: Light and dense intensity
        case 61, 63, 65: return "cloud.rain" // Rain: Slight, moderate and heavy intensity
        case 66, 67: return "cloud.sleet" // Freezing Rain: Light and heavy intensity
        case 71, 73, 75: return "cloud.snow" // Snow fall: Slight, moderate, and heavy intensity
        case 77: return "cloud.snow" // Snow grains
        case 80, 81, 82: return "cloud.heavyrain" // Rain showers: Slight, moderate, and violent
        case 85, 86: return "cloud.snow" // Snow showers slight and heavy
        case 95: return "cloud.bolt" // Thunderstorm: Slight or moderate
        case 96, 99: return "cloud.bolt.rain" // Thunderstorm with slight and heavy hail
        default: return "sun.max"
        }
    }
    
    func weatherDescription(for weatherCode: Int) -> String {
        switch weatherCode {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Depositing rime fog"
        case 51: return "Light drizzle"
        case 53: return "Moderate drizzle"
        case 55: return "Dense drizzle"
        case 56: return "Light freezing drizzle"
        case 57: return "Dense freezing drizzle"
        case 61: return "Slight rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 66: return "Light freezing rain"
        case 67: return "Heavy freezing rain"
        case 71: return "Slight snow fall"
        case 73: return "Moderate snow fall"
        case 75: return "Heavy snow fall"
        case 77: return "Snow grains"
        case 80: return "Slight rain showers"
        case 81: return "Moderate rain showers"
        case 82: return "Violent rain showers"
        case 85: return "Slight snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96: return "Thunderstorm with slight hail"
        case 99: return "Thunderstorm with heavy hail"
        default: return "Unknown weather"
        }
    }
    
    // MARK: - Computed Properties
    var hasWeatherData: Bool {
        weatherData != nil
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
    
    var locationDisplayName: String {
        guard let location = currentLocation else { return "Current Location" }
        return "\(location.name), \(location.country)"
    }
    
    var currentWeatherCondition: WeatherCondition {
        guard let weatherCode = weatherData?.current.weatherCode else {
            return .clear
        }
        return weatherCondition(for: weatherCode)
    }
    
    // MARK: - Weather Condition Logic
    func weatherCondition(for weatherCode: Int) -> WeatherCondition {
        switch weatherCode {
        case 0: return .clear // Clear sky
        case 1, 2: return .partlyCloudy // Mainly clear, partly cloudy
        case 3: return .cloudy // Overcast
        case 45, 48: return .foggy // Fog
        case 51, 53, 55, 56, 57: return .drizzle // Drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82: return .rainy // Rain
        case 71, 73, 75, 77, 85, 86: return .snowy // Snow
        case 95, 96, 99: return .stormy // Thunderstorm
        default: return .clear
        }
    }
}
