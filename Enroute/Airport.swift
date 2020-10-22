//
//  Airport.swift
//  Enroute
//
//  Created by Samuel Pinheiro Junior on 01/10/20.
//  Copyright © 2020 Stanford University. All rights reserved.
//

import CoreData
import Combine

extension Airport {
    static func withICAO(_ icao: String, context: NSManagedObjectContext) -> Airport {
        
        let request = self.fetchRequest(NSPredicate(format: "icao_ = %@", icao))
        let airports = try? (context.fetch(request)) 
        if let airport = airports?.first {
            return airport
        } else {
            let airport = Airport(context: context)
            airport.icao = icao
            AirportInfoRequest.fetch(icao) { airportinfo in
                self.update(from: airportinfo, context: context)
            }
            return airport
        }
    }
    
    static func update(from info: AirportInfo, context: NSManagedObjectContext) {
        if let icao = info.icao {
            let airport = withICAO(icao, context: context)
            airport.latitude = info.latitude
            airport.location = info.location
            airport.name = info.name
            airport.longetude = info.longitude
            airport.timezone = info.timezone
            airport.objectWillChange.send()
            airport.flightsTo.forEach{ $0.objectWillChange.send() }
            airport.flightsFrom.forEach{ $0.objectWillChange.send() }
            try? context.save()
        }
    }
    
    var flightsTo: Set<Flight> {
        get{ (flightsTo_ as? Set<Flight>) ?? [] }
        set{ flightsTo_ = newValue as NSSet}
    }
    var flightsFrom: Set<Flight> {
        get{ (flightsFrom_ as? Set<Flight>) ?? [] }
        set{ flightsFrom_ = newValue as NSSet}
    }
}

extension Airport: Comparable {
    var icao: String {
        get{ icao_! }
        set{ icao_ = newValue }
    }
    
    var friendlyName: String {
        let friendly = AirportInfo.friendlyName(name: self.name ?? "", location: self.location ?? "")
        return friendly.isEmpty ? icao : friendly
        
    }
    
    public static func < (lsh: Airport, rsh: Airport) -> Bool {
        lsh.location ?? lsh.friendlyName < rsh.location ?? rsh.friendlyName
    }
    
}

extension Airport {
    static func fetchRequest(_ predicate: NSPredicate) -> NSFetchRequest<Airport> {
        let request = NSFetchRequest<Airport>(entityName: "Airport")
        request.sortDescriptors = [NSSortDescriptor(key: "location", ascending: true)]
        request.predicate = predicate
        return request
    }
}

extension Airport {
    func fetchIncamingFlight() {
        Self.flightAwareRequest?.stopFetching()
        if let context = managedObjectContext {
            Self.flightAwareRequest = EnrouteRequest.create(airport: icao, howMany: 120)
            Self.flightAwareRequest?.fetch(andRepeatEvery: 10)
            Self.flightAwareResultsCancellable = Self.flightAwareRequest?.results.sink { results in
                for faflight in results {
                    Flight.update(from: faflight, in: context)
                }
                do {
                    try context.save()
                } catch(let error) {
                    print("Couldan't save flight update to CoreData: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private static var flightAwareRequest: EnrouteRequest!
    private static var flightAwareResultsCancellable: AnyCancellable?
}
