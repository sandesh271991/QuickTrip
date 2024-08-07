import SwiftUI
import MapKit
import CoreLocation

enum TransportType: Int, CaseIterable {
    case automobile, walking, transit
    
    var icon: Image {
        switch self {
        case .automobile: return Image(systemName: "car.fill")
        case .walking: return Image(systemName: "figure.walk")
        case .transit: return Image(systemName: "bus.fill")
        }
    }
    
    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
    
    var googleTransportType: String {
        switch self {
        case .automobile: return "driving"
        case .walking: return "walking"
        case .transit: return "transit"
        }
    }
}

struct SeasonBoxView: View {
    let title: String
    let info: String
    
    var body: some View {
        
        // create hstack
        
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
                .foregroundColor(.red)
            Text(info)
                .font(.subheadline)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct SeasonInfo: Decodable {
    let peakSeason: String
    let shoulderSeason: String
    let offSeason: String
}

struct ContentView: View {
    @State private var cityName: String = ""
    @State private var cityCoordinate: CLLocationCoordinate2D?
    @State private var places: [Place] = []
    @State private var suggestions: [String] = []
    @State private var showMapView = false
    @State private var totalDistance: CLLocationDistance = 0
    @State private var totalTime: TimeInterval = 0
    @State private var selectedTransportType: TransportType = .automobile
    @State private var useCurrentLocationAsStart = false
    @State private var useCurrentLocationAsEnd = false
    @State private var showingNavigationOptions = false
    @State private var selectedPlaceCoordinate: CLLocationCoordinate2D?
    @State private var isMapViewShown = true
    @State private var seasonInformation: SeasonInfo?
    @State private var searchRadius: Double = 10.0 // New state for search radius
    
    var body: some View {
        ScrollView {
            ZStack {
                VStack {
                    TextField("Enter place name", text: $cityName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(10)
                        .onChange(of: cityName) { newValue in
                            if !newValue.isEmpty {
                                fetchPlaceSuggestions(query: newValue) { fetchedSuggestions in
                                    suggestions = fetchedSuggestions
                                }
                            } else {
                                suggestions = []
                            }
                        }
                        .onTapGesture {
                            if cityName.isEmpty {
                                suggestions = ["Your Location"]
                            }
                        }
                    
                    HStack {
                        Button(action: {
                            useCurrentLocationAsStart.toggle()
                            updatePlaceNumbersAndRoute()
                        }) {
                            Image(systemName: useCurrentLocationAsStart ? "checkmark.square" : "square")
                                .foregroundColor(.blue)
                                .imageScale(.large)
                        }
                        Text("Use Current Location as Start Point")
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: {
                            useCurrentLocationAsEnd.toggle()
                            updatePlaceNumbersAndRoute()
                        }) {
                            Image(systemName: useCurrentLocationAsEnd ? "checkmark.square" : "square")
                                .foregroundColor(.blue)
                                .imageScale(.large)
                        }
                        Text("Use Current Location as End Point")
                        Spacer()
                    }
                    
                    Picker("Transport Type", selection: $selectedTransportType) {
                        ForEach(TransportType.allCases, id: \.self) { type in
                            type.icon.tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onChange(of: selectedTransportType) { _ in
                        if selectedTransportType == .transit {
                            updatePublicTransportRoute()
                        } else {
                            updatePlaceNumbersAndRoute()
                        }
                    }
                    
                    // Slider for search radius
                    VStack {
                        Text("Search Radius: \(Int(searchRadius)) km")
                        Slider(value: $searchRadius, in: 1...100, step: 1)
                            .padding()
                            .onChange(of: searchRadius) { newRadius in
                                if let coordinate = cityCoordinate {
                                    fetchTouristPlaces(at: coordinate, radius: newRadius) { fetchedPlaces in
                                        places = fetchedPlaces
                                        updatePlaceNumbersAndRoute()
                                    }
                                }
                            }
                    }
                    
                    if totalTime > 0 {
                        HStack {
                            Text("Total Time: \(formattedTime(totalTime))")
                                .padding()
                            
                            Spacer()
                            Button(action: {
                                isMapViewShown.toggle()
                            }) {
                                Image(systemName: isMapViewShown ? "list.bullet" : "map")
                                    .foregroundColor(.blue)
                                    .imageScale(.large)
                            }
                        }
                    }
                    
                    if isMapViewShown {
                        if showMapView {
                            MapView(places: $places, totalDistance: $totalDistance, totalTime: $totalTime, transportType: $selectedTransportType, useCurrentLocationAsStart: $useCurrentLocationAsStart, useCurrentLocationAsEnd: $useCurrentLocationAsEnd, cityCoordinate: $cityCoordinate)
                                .edgesIgnoringSafeArea(.bottom)
                                .frame(height: 400)
                        }
                    } else {
                        HStack {
                            // AI-assisted function generation
                            // create test for name
                            Text("Places to visit")
                                .padding(.vertical, 1)
                                .padding(.horizontal, 10)
                            Spacer()
                        }
                        ScrollView {
                            VStack {
                                ForEach(places.indices, id: \.self) { index in
                                    PlaceRow(
                                        place: $places[index],
                                        updateRoute: updatePlaceNumbersAndRoute,
                                        selectedPlaceCoordinate: $selectedPlaceCoordinate,
                                        showingNavigationOptions: $showingNavigationOptions
                                    )
                                }
                            }
                        }
                        .frame(height: 400)
                    }
                    
                    Spacer()
                    
                    if let seasonInformation = seasonInformation {
                        HStack(alignment: .top, spacing: 10) {
                            SeasonBoxView(title: "Peak Season", info: seasonInformation.peakSeason)
                            SeasonBoxView(title: "Shoulder Season", info: seasonInformation.shoulderSeason)
                            SeasonBoxView(title: "Off Season", info: seasonInformation.offSeason)
                        }
                        .padding()
                    }
                }
                .zIndex(0)
                
                if suggestions.count > 0 {
                    VStack {
                        List(suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .onTapGesture {
                                    if suggestion == "Your Location" {
                                        cityName = "Your Location"
                                        if let currentLocation = userLocation {
                                            cityCoordinate = currentLocation
                                            fetchTouristPlaces(at: currentLocation, radius: searchRadius) { fetchedPlaces in
                                                places = fetchedPlaces
                                                updatePlaceNumbersAndRoute()
                                                showMapView = true
                                                suggestions = []
                                            }
                                            fetchSeasonInfo(for: "Your Location") { info in
                                                if let info = info {
                                                    DispatchQueue.main.async {
                                                        self.seasonInformation = info
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        cityName = suggestion
                                        fetchCityCoordinates(city: suggestion) { coordinate in
                                            if let coordinate = coordinate {
                                                cityCoordinate = coordinate
                                                fetchTouristPlaces(at: coordinate, radius: searchRadius) { fetchedPlaces in
                                                    places = fetchedPlaces
                                                    updatePlaceNumbersAndRoute()
                                                    showMapView = true
                                                    suggestions = [] // Clear suggestions after selection
                                                }
                                                fetchSeasonInfo(for: suggestion) { info in
                                                    if let info = info {
                                                        DispatchQueue.main.async {
                                                            self.seasonInformation = info
                                                        }
                                                    }
                                                }
                                            } else {
                                                print("Failed to get coordinates for city: \(suggestion)")
                                                cityCoordinate = nil
                                                showMapView = false
                                            }
                                        }
                                    }
                                }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .frame(maxHeight: 300)
                        .padding(.top, 50)
                        Spacer()
                    }
                    .zIndex(1)
                }
            }
            .actionSheet(isPresented: $showingNavigationOptions) {
                ActionSheet(title: Text("Choose Navigation App"), buttons: [
                    .default(Text("Apple Maps")) {
                        startNavigation(to: selectedPlaceCoordinate, useGoogleMaps: false)
                    },
                    .default(Text("Google Maps")) {
                        startNavigation(to: selectedPlaceCoordinate, useGoogleMaps: true)
                    },
                    .cancel()
                ])
            }
            .onChange(of: places) { _ in
                updatePlaceNumbersAndRoute()
            }
        }
    }
    
    func updatePublicTransportRoute() {
        totalTime = 0
        totalDistance = 0
        
        let selectedPlaces = places.filter { $0.isSelected }
        guard selectedPlaces.count > 0 else { return }
        
        let group = DispatchGroup()
        
        if useCurrentLocationAsStart, let currentLocation = userLocation {
            calculateRoute(group: group, from: currentLocation, to: selectedPlaces.first!.coordinate, transportType: .transit)
        } else if let startCoordinate = cityCoordinate {
            calculateRoute(group: group, from: startCoordinate, to: selectedPlaces.first!.coordinate, transportType: .transit)
        }
        
        for i in 0..<(selectedPlaces.count - 1) {
            calculateRoute(group: group, from: selectedPlaces[i].coordinate, to: selectedPlaces[i + 1].coordinate, transportType: .transit)
        }
        
        if useCurrentLocationAsEnd, let currentLocation = userLocation {
            calculateRoute(group: group, from: selectedPlaces.last!.coordinate, to: currentLocation, transportType: .transit)
        }
        
        group.notify(queue: .main) {
            print("Total travel time: \(self.totalTime) seconds")
            print("Total distance: \(self.totalDistance) meters")
        }
    }
    
    func formattedTime(_ totalTime: Double) -> String {
        let totalMinutes = Int(totalTime / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func updatePlaceNumbersAndRoute() {
        let selectedPlaces = places.filter { $0.isSelected }
        for (index, place) in selectedPlaces.enumerated() {
            if let placeIndex = places.firstIndex(where: { $0.id == place.id }) {
                places[placeIndex].number = index + 1
            }
        }
        calculateTotalDistanceAndTime()
    }
    
    private func calculateTotalDistanceAndTime() {
        totalTime = 0
        totalDistance = 0
        
        let selectedPlaces = places.filter { $0.isSelected }
        guard selectedPlaces.count > 0 else { return }
        
        let group = DispatchGroup()
        
        if useCurrentLocationAsStart, let currentLocation = userLocation {
            calculateRoute(group: group, from: currentLocation, to: selectedPlaces.first!.coordinate, transportType: selectedTransportType)
        } else if let startCoordinate = cityCoordinate {
            calculateRoute(group: group, from: startCoordinate, to: selectedPlaces.first!.coordinate, transportType: selectedTransportType)
        }
        
        for i in 0..<(selectedPlaces.count - 1) {
            calculateRoute(group: group, from: selectedPlaces[i].coordinate, to: selectedPlaces[i + 1].coordinate, transportType: selectedTransportType)
        }
        
        if useCurrentLocationAsEnd, let currentLocation = userLocation {
            calculateRoute(group: group, from: selectedPlaces.last!.coordinate, to: currentLocation, transportType: selectedTransportType)
        }
        
        group.notify(queue: .main) {
            print("Total travel time: \(self.totalTime) seconds")
            print("Total distance: \(self.totalDistance) meters")
        }
    }
    
    private func calculateRoute(group: DispatchGroup, from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: TransportType) {
        group.enter()
        if transportType == .transit {
            fetchPublicTransportTime(from: source, to: destination, transportType: transportType) { time in
                if let time = time {
                    self.totalTime += time
                }
                group.leave()
            }
        } else {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = transportType.mkTransportType
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                if let route = response?.routes.first {
                    self.totalTime += route.expectedTravelTime
                    self.totalDistance += route.distance
                }
                group.leave()
            }
        }
    }
    
    private func startNavigation(to destinationCoordinate: CLLocationCoordinate2D?, useGoogleMaps: Bool) {
        guard let destinationCoordinate = destinationCoordinate else {
            print("Destination coordinate is nil")
            return
        }
        
        if let currentCoordinate = cityCoordinate ?? userLocation {
            if useGoogleMaps {
                let url = URL(string: "comgooglemaps://?saddr=\(currentCoordinate.latitude),\(currentCoordinate.longitude)&daddr=\(destinationCoordinate.latitude),\(destinationCoordinate.longitude)&directionsmode=driving")!
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    // Fallback to Google Maps website if the app is not installed
                    let webUrl = URL(string: "https://www.google.com/maps/dir/?api=1&origin=\(currentCoordinate.latitude),\(currentCoordinate.longitude)&destination=\(destinationCoordinate.latitude),\(destinationCoordinate.longitude)&travelmode=driving")!
                    UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                }
            } else {
                let destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
                let options = [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ]
                destination.openInMaps(launchOptions: options)
            }
        } else {
            print("Current location is not available.")
        }
    }
    
    var userLocation: CLLocationCoordinate2D? {
        return CLLocationManager().location?.coordinate
    }
    
    func parseSeasonInfo(_ info: String) -> SeasonInfo {
        // Example parsing logic. Adjust based on the actual response format.
        let lines = info.split(separator: "\n")
        var peakSeason = ""
        var shoulderSeason = ""
        var offSeason = ""
        
        for line in lines {
            if line.contains("Peak Season") {
                peakSeason = String(line.replacingOccurrences(of: "Peak Season:", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            } else if line.contains("Shoulder Season") {
                shoulderSeason = String(line.replacingOccurrences(of: "Shoulder Season:", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            } else if line.contains("Off Season") {
                offSeason = String(line.replacingOccurrences(of: "Off Season:", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        return SeasonInfo(peakSeason: peakSeason, shoulderSeason: shoulderSeason, offSeason: offSeason)
    }
    
    //gpt-4o-mini
    func fetchSeasonInfo(for place: String, completion: @escaping (SeasonInfo?) -> Void) {
       // let apiKey = "AOcnds82Nz6l0jtTujAwT3BlbkFJpUOnhfFuIU7cBTSxEYXZ"
        
        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Provide the peak season, shoulder season, and off-season for tourists to travel to \(place) in JSON format with keys "peakSeason", "shoulderSeason", and "offSeason".
        """
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 200,
            "temperature": 0.5
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to serialize request body: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let seasonInfoData = content.data(using: .utf8) {
                    
                    let decoder = JSONDecoder()
                    let seasonInfo = try decoder.decode(SeasonInfo.self, from: seasonInfoData)
                    completion(seasonInfo)
                } else {
                    print("Failed to parse response: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                    completion(nil)
                }
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }
}

struct PlaceRow: View {
    @Binding var place: Place
    var updateRoute: () -> Void
    @Binding var selectedPlaceCoordinate: CLLocationCoordinate2D?
    @Binding var showingNavigationOptions: Bool
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                Button(action: {
                    place.isSelected.toggle()
                    updateRoute()
                }) {
                    Image(systemName: place.isSelected ? "checkmark.square" : "square")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.trailing, 5)
            
            VStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .overlay(Text("\(place.number)").foregroundColor(.white))
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 2)
                    .layoutPriority(-1)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .frame(width: 2, height: geometry.size.height)
                        }
                    )
            }
            .padding(.trailing, 5)
            
            VStack(alignment: .leading) {
                Text(place.name)
                    .padding(.bottom, 10)
                if let photo = place.photo {
                    ScrollView(.horizontal) {
                        HStack {
                            Image(uiImage: photo)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(5)
                        }
                    }
                } else if let photoReference = place.photoReference {
                    ProgressView()
                        .frame(width: 50, height: 50)
                        .onAppear {
                            fetchPlacePhoto(photoReference: photoReference) { image in
                                if let image = image {
                                    DispatchQueue.main.async {
                                        place.photo = image
                                    }
                                } else {
                                    print("Failed to fetch photo for place: \(place.name)")
                                }
                            }
                        }
                }
                Text("Address: \(place.address ?? "N/A")")
                    .padding(.top, 5)
                Text("Rating: \(place.rating ?? 0)/5")
                    .padding(.top, 5)
                if let reviews = place.reviews {
                    ForEach(reviews.prefix(3), id: \.authorName) { review in
                        VStack(alignment: .leading) {
                            Text("Review by \(review.authorName):")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(review.text)
                                .font(.subheadline)
                                .italic()
                        }
                        .padding(.top, 5)
                    }
                }
                if let openingHours = place.openingHours {
                    Text("Opening Hours:")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.top, 5)
                    ForEach(openingHours.weekday_text ?? [""], id: \.self) { dayText in
                        Text(dayText)
                            .font(.subheadline)
                    }
                }
                Spacer()
                Button(action: {
                    selectedPlaceCoordinate = place.coordinate
                    showingNavigationOptions = true
                }) {
                    HStack {
                        Text("Navigate")
                        Image(systemName: "arrow.right.circle")
                    }
                }
                .disabled(place.isSelected ? false : true)
                Divider()
            }
            Spacer()
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 10)
        .background(place.isSelected ? Color.white : Color(red: 0.95, green: 0.95, blue: 0.95))
    }
}

struct CustomAnnotationView: View {
    let number: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 30, height: 30)
            Text("\(number)")
                .foregroundColor(.white)
                .fontWeight(.bold)
        }
    }
}

struct RouteAnnotationView: View {
    let time: TimeInterval
    
    var body: some View {
        Text(formattedTime(time))
            .foregroundColor(.white)
            .fontWeight(.bold)
            .background(Color.black.opacity(0.75))
            .cornerRadius(5)
    }
    
    func formattedTime(_ time: TimeInterval) -> String {
        let totalMinutes = Int(time / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

struct MapView: UIViewRepresentable {
    @Binding var places: [Place]
    @Binding var totalDistance: CLLocationDistance
    @Binding var totalTime: TimeInterval
    @Binding var transportType: TransportType
    @Binding var useCurrentLocationAsStart: Bool
    @Binding var useCurrentLocationAsEnd: Bool
    @Binding var cityCoordinate: CLLocationCoordinate2D?
    @State private var locationManager = CLLocationManager()
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var mapView: MKMapView? = nil // Store map view instance
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        locationManager.delegate = context.coordinator
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        if useCurrentLocationAsStart, let userLocation = userLocation {
            uiView.setCenter(userLocation, animated: true)
            cityCoordinate = userLocation
        } else if let cityCoordinate = cityCoordinate {
            uiView.setCenter(cityCoordinate, animated: true)
        }
        updateAnnotationsAndRoute(mapView: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func addAnnotations(mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations)
        if useCurrentLocationAsStart, let userLocation = userLocation {
            let currentLocationAnnotation = MKPointAnnotation()
            currentLocationAnnotation.coordinate = userLocation
            currentLocationAnnotation.title = "Current Location"
            mapView.addAnnotation(currentLocationAnnotation)
        }
        let selectedPlaces = places.filter { $0.isSelected }
        for place in selectedPlaces {
            let annotation = CustomAnnotation(number: place.number, title: place.name, coordinate: place.coordinate)
            mapView.addAnnotation(annotation)
        }
    }
    
    func showShortestRoute(mapView: MKMapView) {
        let selectedPlaces = places.filter { $0.isSelected }
        var coordinates = selectedPlaces.map { $0.coordinate }
        
        if useCurrentLocationAsStart, let userLocation = userLocation {
            coordinates.insert(userLocation, at: 0)
        }
        if useCurrentLocationAsEnd, let userLocation = userLocation {
            coordinates.append(userLocation)
        }
        
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        // Calculate and add route annotations
        for i in 0..<(coordinates.count - 1) {
            let source = coordinates[i]
            let destination = coordinates[i + 1]
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = transportType.mkTransportType
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                guard let route = response?.routes.first else { return }
                let midpoint = CLLocationCoordinate2D(
                    latitude: (source.latitude + destination.latitude) / 2,
                    longitude: (source.longitude + destination.longitude) / 2
                )
                let annotation = RouteAnnotation(distance: route.distance, time: route.expectedTravelTime, coordinate: midpoint)
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    func updateAnnotationsAndRoute(mapView: MKMapView) {
        addAnnotations(mapView: mapView)
        mapView.removeOverlays(mapView.overlays)
        showShortestRoute(mapView: mapView)
        
        let selectedPlaces = places.filter { $0.isSelected }
        var coordinates = selectedPlaces.map { $0.coordinate }
        
        if useCurrentLocationAsStart, let userLocation = userLocation {
            coordinates.insert(userLocation, at: 0)
        }
        if useCurrentLocationAsEnd, let userLocation = userLocation {
            coordinates.append(userLocation)
        }
        
        if !coordinates.isEmpty {
            let rect = mapView.mapRectThatFits(MKPolygon(coordinates: coordinates, count: coordinates.count).boundingMapRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50))
            mapView.setVisibleMapRect(rect, animated: true)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let customAnnotation = annotation as? CustomAnnotation {
                let identifier = "CustomAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: customAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = customAnnotation
                }
                
                let customAnnotationView = UIHostingController(rootView: CustomAnnotationView(number: customAnnotation.number)).view
                customAnnotationView?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                annotationView?.addSubview(customAnnotationView!)
                annotationView?.frame = customAnnotationView!.frame
                
                return annotationView
            } else if let routeAnnotation = annotation as? RouteAnnotation {
                let identifier = "RouteAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: routeAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = routeAnnotation
                }
                
                let routeAnnotationView = UIHostingController(rootView: RouteAnnotationView(time: routeAnnotation.time)).view
                routeAnnotationView?.frame = CGRect(x: 0, y: 0, width: 80, height: 40)
                routeAnnotationView?.layer.cornerRadius = 10
                annotationView?.addSubview(routeAnnotationView!)
                annotationView?.frame = routeAnnotationView!.frame
                
                return annotationView
            } else if annotation.title == "Current Location" {
                let identifier = "CurrentLocation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    (annotationView as? MKMarkerAnnotationView)?.markerTintColor = .green
                } else {
                    annotationView?.annotation = annotation
                }
                
                return annotationView
            }
            return nil
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.first {
                print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                parent.userLocation = location.coordinate
                parent.cityCoordinate = location.coordinate // Ensure the city coordinate is also updated
                if let mapView = parent.mapView {
                    parent.updateAnnotationsAndRoute(mapView: mapView) // Update annotations and route
                }
                manager.stopUpdatingLocation()
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            print("Location authorization status changed: \(status.rawValue)")
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            } else {
                print("Location authorization not granted.")
            }
        }
        
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Location manager failed with error: \(error.localizedDescription)")
        }
    }
}

class CustomAnnotation: NSObject, MKAnnotation {
    let number: Int
    let title: String?
    let coordinate: CLLocationCoordinate2D
    
    init(number: Int, title: String, coordinate: CLLocationCoordinate2D) {
        self.number = number
        self.title = title
        self.coordinate = coordinate
    }
}

class RouteAnnotation: NSObject, MKAnnotation {
    let distance: CLLocationDistance
    let time: TimeInterval
    let coordinate: CLLocationCoordinate2D
    
    init(distance: CLLocationDistance, time: TimeInterval, coordinate: CLLocationCoordinate2D) {
        self.distance = distance
        self.time = time
        self.coordinate = coordinate
    }
}

struct Itinerary: Identifiable {
    var id = UUID()
    var name: String
    var places: [Place]
}

struct Place: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
    var isSelected: Bool = true
    var number: Int = 0
    var photoReference: String?
    var photo: UIImage?
    var address: String?
    var rating: Double?
    var reviews: [Review]?
    var openingHours: OpeningHours?
    
    static func == (lhs: Place, rhs: Place) -> Bool {
        return lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.isSelected == rhs.isSelected &&
        lhs.number == rhs.number
    }
}

struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
}

struct GooglePlace: Codable {
    let name: String
    let geometry: Geometry
    let photos: [GooglePhoto]?
    let vicinity: String?
    let rating: Double?
    let user_ratings_total: Int?
    let reviews: [GoogleReview]?
    let opening_hours: OpeningHours?
}

struct Geometry: Codable {
    let location: Location
}

struct Location: Codable {
    let lat: Double
    let lng: Double
}

struct GooglePhoto: Codable {
    let photoReference: String
    let width: Int
    let height: Int
    
    enum CodingKeys: String, CodingKey {
        case photoReference = "photo_reference"
        case width
        case height
    }
}

struct GoogleReview: Codable {
    let author_name: String
    let text: String
}

struct OpeningHours: Codable {
    let open_now: Bool
    let periods: [Period]?
    let weekday_text: [String]?
}

struct Period: Codable {
    let open: DayTime
    let close: DayTime
}

struct DayTime: Codable {
    let day: Int
    let time: String
}

struct Review: Identifiable {
    let id = UUID()
    let authorName: String
    let text: String
}

func fetchCityCoordinates(city: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
    let geocoder = CLGeocoder()
    geocoder.geocodeAddressString(city) { placemarks, error in
        if let placemark = placemarks?.first, let location = placemark.location {
            print("Coordinates for \(city): \(location.coordinate)")
            completion(location.coordinate)
        } else {
            print("Failed to get coordinates for city: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
        }
    }
}

func fetchPlaceSuggestions(query: String, completion: @escaping ([String]) -> Void) {
    let apiKey = "AIzaSyCLt4IgoURwoqW1DgIAUklDvHAZDJaR3bo"
    let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(query)&key=\(apiKey)"
    
    guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
        completion([])
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error fetching suggestions: \(error.localizedDescription)")
            completion([])
            return
        }
        
        guard let data = data else {
            print("No data received")
            completion([])
            return
        }
        
        do {
            let result = try JSONDecoder().decode(GoogleAutocompleteResponse.self, from: data)
            let suggestions = result.predictions.map { $0.description }
            DispatchQueue.main.async {
                completion(suggestions)
            }
        } catch {
            print("Error decoding response: \(error.localizedDescription)")
            completion([])
        }
    }.resume()
}

struct GoogleAutocompleteResponse: Codable {
    let predictions: [Prediction]
}

struct Prediction: Codable {
    let description: String
}

func fetchPlacePhoto(photoReference: String, completion: @escaping (UIImage?) -> Void) {
    let apiKey = "AIzaSyCLt4IgoURwoqW1DgIAUklDvHAZDJaR3bo"
    let urlString = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(photoReference)&key=\(apiKey)"
    print("Fetching photo from URL: \(urlString)")
    
    guard let url = URL(string: urlString) else {
        completion(nil)
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error fetching photo: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        if let data = data, let image = UIImage(data: data) {
            print("Photo fetched successfully")
            DispatchQueue.main.async {
                completion(image)
            }
        } else {
            print("Failed to fetch photo")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }.resume()
}

func fetchTouristPlaces(at coordinate: CLLocationCoordinate2D, radius: Double, completion: @escaping ([Place]) -> Void) {
    let apiKey = "AIzaSyCLt4IgoURwoqW1DgIAUklDvHAZDJaR3bo"
    let location = "\(coordinate.latitude),\(coordinate.longitude)"
    let type = "tourist_attraction"
    
    let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location)&radius=\(Int(radius * 1000))&type=\(type)&rankby=prominence&key=\(apiKey)"
    
    print("Request URL: \(urlString)")
    
    guard let url = URL(string: urlString) else {
        completion([])
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error fetching places: \(error.localizedDescription)")
            completion([])
            return
        }
        
        guard let data = data else {
            print("No data received")
            completion([])
            return
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw API response: \(jsonString)")
        }
        
        do {
            let result = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
            print("API Response: \(result)")
            var places = result.results.map { place in
                Place(
                    name: place.name,
                    coordinate: CLLocationCoordinate2D(latitude: place.geometry.location.lat, longitude: place.geometry.location.lng),
                    photoReference: place.photos?.first?.photoReference,
                    address: place.vicinity,
                    rating: place.rating,
                    reviews: place.reviews?.map { Review(authorName: $0.author_name, text: $0.text) },
                    openingHours: place.opening_hours
                )
            }
            
            let dispatchGroup = DispatchGroup()
            
            for i in 0..<places.count {
                if let photoReference = places[i].photoReference {
                    dispatchGroup.enter()
                    fetchPlacePhoto(photoReference: photoReference) { image in
                        places[i].photo = image
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("All photos fetched")
                completion(places)
            }
        } catch {
            print("Error decoding response: \(error.localizedDescription)")
            completion([])
        }
    }.resume()
}

func fetchPublicTransportTime(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: TransportType, completion: @escaping (TimeInterval?) -> Void) {
    let apiKey = "AIzaSyCLt4IgoURwoqW1DgIAUklDvHAZDJaR3bo"
    let origin = "\(source.latitude),\(source.longitude)"
    let destination = "\(destination.latitude),\(destination.longitude)"
    let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&mode=\(transportType.googleTransportType)&key=\(apiKey)"
    
    guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
        completion(nil)
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error fetching public transport time: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let data = data else {
            print("No data received")
            completion(nil)
            return
        }
        
        do {
            let result = try JSONDecoder().decode(GoogleDirectionsResponse.self, from: data)
            if let duration = result.routes.first?.legs.first?.duration.value {
                print("Public transport duration: \(duration) seconds")
                completion(TimeInterval(duration))
            } else {
                print("No duration found in response")
                completion(nil)
            }
        } catch {
            print("Error decoding response: \(error.localizedDescription)")
            completion(nil)
        }
    }.resume()
}

struct GoogleDirectionsResponse: Codable {
    let routes: [Route]
    
    struct Route: Codable {
        let legs: [Leg]
    }
    
    struct Leg: Codable {
        let duration: Duration
        let distance: Distance
    }
    
    struct Duration: Codable {
        let value: Int
    }
    
    struct Distance: Codable {
        let value: Int
    }
}
