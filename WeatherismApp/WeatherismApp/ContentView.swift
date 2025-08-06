//
//  ContentView.swift
//  WeatherismApp
//
//  Created by Agustinus Pongoh on 05/08/25.
//

import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var cityName = ""
    @State private var showEmptyFieldError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background gradient based on weather condition
                backgroundGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: viewModel.currentWeatherCondition)
                
                VStack(spacing: 20) {
                    // Search bar
                    VStack(spacing: 8) {
                        HStack {
                            TextField("Enter city name", text: $cityName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    searchWeather()
                                }
                                .submitLabel(.search)
                                .onChange(of: cityName) { _, _ in
                                    // Hide error when user starts typing
                                    if showEmptyFieldError {
                                        showEmptyFieldError = false
                                    }
                                }
                            
                            Button("Search") {
                                searchWeather()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isLoading)
                        }
                        
                        // Show empty field error
                        if showEmptyFieldError {
                            HStack {
                                Text("Please enter a city name")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Loading weather...")
                                .foregroundColor(.white)
                                .padding(.top, 8)
                        }
                    } else if viewModel.hasError, let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // Retry button
                            Button("Try Again") {
                                viewModel.requestCurrentLocationWeather()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if viewModel.hasWeatherData, let weather = viewModel.weatherData {
                        WeatherView(weather: weather, viewModel: viewModel)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "location.circle")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            Text("Welcome to Weatherism")
                                .font(.title)
                                .foregroundColor(.white)
                            Text("Getting weather for your location...")
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Weatherism")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.refreshWeather()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                // Automatically get current location weather when app appears
                viewModel.requestCurrentLocationWeather()
            }
        }
    }
    
    // MARK: - Private Methods
    private func searchWeather() {
        let trimmedCity = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedCity.isEmpty {
            showEmptyFieldError = true
            return
        }
        
        showEmptyFieldError = false
        viewModel.searchWeather(for: trimmedCity)
    }
    
    // MARK: - Computed Properties
    private var backgroundGradient: LinearGradient {
        if viewModel.hasWeatherData {
            return viewModel.currentWeatherCondition.backgroundGradient
        } else {
            // Default gradient when no weather data
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
