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
    @State private var useCurrentLocation = false
    @State private var showingNavigationOptions = false
    @State private var selectedPlaceCoordinate: CLLocationCoordinate2D?
    @State private var isMapViewShown = true
    
    var body: some View {
        ZStack {
            VStack {
                TextField("Enter place name", text: $cityName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(10)
                    .onChange(of: cityName) {
                        fetchPlaceSuggestions(query: cityName) { fetchedSuggestions in
                            suggestions = fetchedSuggestions
                        }
                    }
                
                HStack {
                    Button(action: {
                        useCurrentLocation.toggle()
                        updatePlaceNumbersAndRoute()
                    }) {
                        Image(systemName: useCurrentLocation ? "checkmark.square" : "square")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                    Text("Use Current Location as Start Point")
                    Spacer()
                }
                .padding()
                
                Picker("Transport Type", selection: $selectedTransportType) {
                    ForEach(TransportType.allCases, id: \.self) { type in
                        type.icon.tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedTransportType) {
                    updatePlaceNumbersAndRoute()
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
                        MapView(places: $places, totalDistance: $totalDistance, totalTime: $totalTime, transportType: $selectedTransportType, useCurrentLocation: $useCurrentLocation, cityCoordinate: $cityCoordinate)
                            .edgesIgnoringSafeArea(.bottom)
                    }
                } else {
                    HStack {
                        Text("Places to visit")
                            .padding(.vertical, 1)
                            .padding(.horizontal, 10)
                        Spacer()
                    }
                    ScrollView {
                        VStack {
                            ForEach(places.indices, id: \.self) { index in
                                HStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 0) {
                                        Spacer()
                                        
                                        Button(action: {
                                            places[index].isSelected.toggle()
                                            updatePlaceNumbersAndRoute()
                                        }) {
                                            Image(systemName: places[index].isSelected ? "checkmark.square" : "square")
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
                                            .overlay(Text("\(index + 1)").foregroundColor(.white))
                                        
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: 2)
                                            .layoutPriority(-1) // Ensure it doesn't affect the height of the VStack
                                            .background(
                                                GeometryReader { geometry in
                                                    Color.clear
                                                        .frame(width: 2, height: geometry.size.height)
                                                }
                                            )
                                    }
                                    .padding(.trailing, 5)

                                    
                                    VStack(alignment: .leading) {
                                        Text(places[index].name)
                                            .padding(.bottom, 10)
                                        if let photo = places[index].photo {
                                            ScrollView(.horizontal) {
                                                HStack {
                                                    Image(uiImage: photo)
                                                        .resizable()
                                                        .frame(width: 50, height: 50)
                                                        .cornerRadius(5)
                                                }
                                            }
                                        } else if let photoReference = places[index].photoReference {
                                            ProgressView()
                                                .frame(width: 50, height: 50)
                                                .onAppear {
                                                    fetchPlacePhoto(photoReference: photoReference) { image in
                                                        if let image = image {
                                                            DispatchQueue.main.async {
                                                                places[index].photo = image
                                                            }
                                                        } else {
                                                            print("Failed to fetch photo for place: \(places[index].name)")
                                                        }
                                                    }
                                                }
                                        }
                                        // Place details
                                        Text("Address: \(places[index].address ?? "N/A")")
                                            .padding(.top, 5)
                                        Text("Rating: \(places[index].rating ?? 0)/5")
                                            .padding(.top, 5)
                                        if let reviews = places[index].reviews {
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
                                        // Opening hours
                                        if let openingHours = places[index].openingHours {
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
                                            selectedPlaceCoordinate = places[index].coordinate
                                            showingNavigationOptions = true
                                        }) {
                                            HStack {
                                                Text("Navigate")
                                                Image(systemName: "arrow.right.circle")
                                            }
                                        }
                                        .disabled(places[index].isSelected ? false : true)
                                        Divider()
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 1)
                                .padding(.horizontal, 10)
                                .background(places[index].isSelected ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.95))
                            }
                        }
                        .background(Color.black)
                    }
                    .background(Color.black)
                }
                Spacer()
            }
            .background(Color.black)
            .zIndex(0)
            
            if suggestions.count > 0 {
                VStack {
                    List(suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                            .onTapGesture {
                                cityName = suggestion
                                fetchCityCoordinates(city: suggestion) { coordinate in
                                    if let coordinate = coordinate {
                                        cityCoordinate = coordinate
                                        fetchTouristPlaces(at: coordinate) { fetchedPlaces in
                                            places = fetchedPlaces
                                            updatePlaceNumbersAndRoute()
                                            showMapView = true
                                            suggestions = [] // Clear suggestions after selection
                                        }
                                    } else {
                                        print("Failed to get coordinates for city: \(suggestion)")
                                        cityCoordinate = nil
                                        showMapView = false
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
        .onChange(of: places) {
            updatePlaceNumbersAndRoute()
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
        
        if useCurrentLocation, let currentLocation = userLocation {
            let source = currentLocation
            let destination = selectedPlaces.first!.coordinate
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = selectedTransportType.mkTransportType
            
            let directions = MKDirections(request: request)
            group.enter()
            directions.calculate { response, error in
                if let error = error as NSError? {
                    print("Error calculating directions: \(error.localizedDescription)")
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("Underlying error: \(underlyingError.localizedDescription)")
                    }
                    print("Error code: \(error.code)")
                    print("Error domain: \(error.domain)")
                } else if let route = response?.routes.first {
                    totalTime += route.expectedTravelTime
                    totalDistance += route.distance
                    print("Route found: \(route)")
                } else {
                    print("No routes found")
                }
                group.leave()
            }
        }
        
        for i in 0..<(selectedPlaces.count - 1) {
            let source = selectedPlaces[i].coordinate
            let destination = selectedPlaces[i + 1].coordinate
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = selectedTransportType.mkTransportType
            
            let directions = MKDirections(request: request)
            group.enter()
            directions.calculate { response, error in
                if let error = error as NSError? {
                    print("Error calculating directions: \(error.localizedDescription)")
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("Underlying error: \(underlyingError.localizedDescription)")
                    }
                    print("Error code: \(error.code)")
                    print("Error domain: \(error.domain)")
                } else if let route = response?.routes.first {
                    totalTime += route.expectedTravelTime
                    totalDistance += route.distance
                    print("Route found: \(route)")
                } else {
                    print("No routes found")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("Total travel time: \(self.totalTime) seconds")
            print("Total distance: \(self.totalDistance) meters")
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
        guard useCurrentLocation else { return nil }
        return CLLocationManager().location?.coordinate
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
    @Binding var useCurrentLocation: Bool
    @Binding var cityCoordinate: CLLocationCoordinate2D?
    @State private var locationManager = CLLocationManager()
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var mapView: MKMapView? = nil // Store map view instance
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
      //  self.mapView = mapView // Assign map view instance
        mapView.delegate = context.coordinator
        
        locationManager.delegate = context.coordinator
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        if useCurrentLocation, let userLocation = userLocation {
            print("Updating UI View with user location: \(userLocation.latitude), \(userLocation.longitude)")
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
        if useCurrentLocation, let userLocation = userLocation {
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
        
        if useCurrentLocation, let userLocation = userLocation {
            coordinates.insert(userLocation, at: 0)
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
        
        if useCurrentLocation, let userLocation = userLocation {
            coordinates.insert(userLocation, at: 0)
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

func fetchTouristPlaces(at coordinate: CLLocationCoordinate2D, completion: @escaping ([Place]) -> Void) {
    let apiKey = "AIzaSyCLt4IgoURwoqW1DgIAUklDvHAZDJaR3bo"
    let location = "\(coordinate.latitude),\(coordinate.longitude)"
    let radius = 500
    let type = "tourist_attraction"
    
    let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location)&radius=\(radius)&type=\(type)&key=\(apiKey)"
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
        
        // Print the raw API response for debugging
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
