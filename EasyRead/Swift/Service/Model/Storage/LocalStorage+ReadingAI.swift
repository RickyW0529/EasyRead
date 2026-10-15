// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Foundation

extension LocalStorage {
    /// Removes the duplicate AI result card while preserving its credentials and
    /// ensuring legacy default installations retain a non-AI translation service.
    func migrateReadingAIServiceTypes(_ storedTypes: [String], windowType: EZWindowType) -> [String] {
        var migrated = storedTypes.filter {
            $0.split(separator: "#", maxSplits: 1).first.map(String.init) != ServiceType.deepSeek.rawValue
        }
        guard migrated != storedTypes else { return storedTypes }
        if !migrated.contains(ServiceType.google.rawValue) {
            migrated.append(ServiceType.google.rawValue)
            // A removed Google entry may still have disabled metadata. The newly
            // inserted fallback must be usable even in that legacy state.
            setServiceInfo(QueryServiceConfiguration(type: .google, windowType: windowType), windowType: windowType)
        }
        setAllServiceTypes(migrated, windowType: windowType)
        return migrated
    }
}
