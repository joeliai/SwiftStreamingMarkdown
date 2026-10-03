//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import MapKit
import UIKit

/// A map reply: an interactive map centered on a place, with a marker. Once
/// the map loads, its button adds markers for nearby places and expands the
/// map, both with animation.
final class MapMessageCell: UICollectionViewCell, MKMapViewDelegate {

  /// Called when the user shows or hides the nearby places.
  var onExpandedChange: ((Bool) -> Void)?

  private static let collapsedHeight: CGFloat = 220
  private static let expandedHeight: CGFloat = 360

  private let mapView = MKMapView()
  private let nearbyButton = UIButton(configuration: .filled())
  private lazy var heightConstraint = mapView.heightAnchor.constraint(equalToConstant: Self.collapsedHeight)
  private var place: ChatWidget.Place?
  private var nearbyMarkers: [MKPointAnnotation] = []
  private var isExpanded = false
  private var isLoadingMap = false
  private var revealButtonTask: Task<Void, Never>?

  override init(frame: CGRect) {
    super.init(frame: frame)
    mapView.delegate = self
    mapView.layer.cornerRadius = 16
    mapView.layer.cornerCurve = .continuous
    mapView.clipsToBounds = true
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    mapView.register(
      MKMarkerAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
    )
    configureNearbyButton()

    for view in [mapView, nearbyButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(view)
    }
    // Below the required priority, so that it gives way to the estimated
    // height that a new cell starts with.
    let bottom = mapView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
    bottom.priority = .required - 1
    NSLayoutConstraint.activate([
      mapView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
      bottom,
      mapView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      mapView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      heightConstraint,
      nearbyButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 10),
      nearbyButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -10)
    ])
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    onExpandedChange = nil
    // Clear the previous map, as if loading a different one.
    place = nil
    nearbyMarkers = []
    mapView.removeAnnotations(mapView.annotations)
    revealButtonTask?.cancel()
    isLoadingMap = false
    setNearbyButtonVisible(false, animated: false)
    setExpanded(false)
  }

  func configure(place: ChatWidget.Place, isExpanded: Bool) {
    guard place != self.place else { return }
    self.place = place
    mapView.accessibilityLabel = "Map of \(place.name)"
    mapView.removeAnnotations(mapView.annotations)
    setNearbyButtonVisible(false, animated: false)

    let marker = MKPointAnnotation()
    marker.coordinate = place.coordinate
    marker.title = place.name
    mapView.addAnnotation(marker)
    nearbyMarkers = place.nearby.map { nearbyPlace in
      let nearbyMarker = MKPointAnnotation()
      nearbyMarker.coordinate = nearbyPlace.coordinate
      nearbyMarker.title = nearbyPlace.name
      return nearbyMarker
    }

    setExpanded(isExpanded)
    if isExpanded {
      mapView.addAnnotations(nearbyMarkers)
      mapView.showAnnotations(mapView.annotations, animated: false)
    } else {
      mapView.setRegion(Self.region(around: place), animated: false)
    }
    revealNearbyButtonIfLoaded()
  }

  // MARK: - Nearby places

  private func configureNearbyButton() {
    var configuration = UIButton.Configuration.filled()
    configuration.cornerStyle = .capsule
    configuration.buttonSize = .small
    configuration.baseBackgroundColor = .systemBackground
    configuration.baseForegroundColor = .label
    configuration.imagePadding = 4
    nearbyButton.configuration = configuration
    nearbyButton.addAction(UIAction { [weak self] _ in self?.toggleNearbyPlaces() }, for: .touchUpInside)
  }

  /// Shows the button once the map has loaded. MapKit doesn't report
  /// loading a region whose map data it already has, so if loading hasn't
  /// started shortly after the region is set, the map counts as loaded.
  private func revealNearbyButtonIfLoaded() {
    revealButtonTask?.cancel()
    revealButtonTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled, let self, !self.isLoadingMap else { return }
      self.setNearbyButtonVisible(true, animated: true)
    }
  }

  private func setNearbyButtonVisible(_ isVisible: Bool, animated: Bool) {
    let isVisible = isVisible && !nearbyMarkers.isEmpty
    nearbyButton.isUserInteractionEnabled = isVisible
    let changes = {
      self.nearbyButton.alpha = isVisible ? 1 : 0
    }
    if animated {
      UIView.animate(withDuration: 0.25, animations: changes)
    } else {
      changes()
    }
  }

  private func toggleNearbyPlaces() {
    guard let place else { return }
    let expanded = !isExpanded
    onExpandedChange?(expanded)
    if !expanded {
      mapView.removeAnnotations(nearbyMarkers)
    }
    animateResize {
      self.setExpanded(expanded)
    } completion: { [weak self] in
      // Update the map once it has its new size, unless the cell was reused
      // or toggled again in the meantime.
      guard let self, self.place == place, self.isExpanded == expanded else { return }
      if expanded {
        // The markers animate in as they're added.
        self.mapView.addAnnotations(self.nearbyMarkers)
        self.mapView.showAnnotations(self.mapView.annotations, animated: true)
      } else {
        self.mapView.setRegion(Self.region(around: place), animated: true)
      }
    }
  }

  private func setExpanded(_ expanded: Bool) {
    isExpanded = expanded
    heightConstraint.constant = expanded ? Self.expandedHeight : Self.collapsedHeight
    nearbyButton.configuration?.title = expanded ? "Hide nearby" : "Show nearby"
    nearbyButton.configuration?.image = UIImage(systemName: expanded ? "mappin.slash" : "mappin.and.ellipse")
  }

  private static func region(around place: ChatWidget.Place) -> MKCoordinateRegion {
    MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 1_500, longitudinalMeters: 1_500)
  }

  // MARK: - MKMapViewDelegate

  func mapViewWillStartLoadingMap(_ mapView: MKMapView) {
    isLoadingMap = true
  }

  func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
    isLoadingMap = false
    setNearbyButtonVisible(true, animated: true)
  }

  func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
    isLoadingMap = false
    // Nearby places still work without map tiles.
    setNearbyButtonVisible(true, animated: true)
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    let view = mapView.dequeueReusableAnnotationView(
      withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier,
      for: annotation
    )
    if let marker = view as? MKMarkerAnnotationView {
      let isNearby = nearbyMarkers.contains { $0 === annotation }
      marker.markerTintColor = isNearby ? .systemBlue : nil
      marker.animatesWhenAdded = isNearby
    }
    return view
  }
}

private extension ChatWidget.Place {
  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
