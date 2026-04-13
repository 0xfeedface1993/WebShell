import Foundation

public enum RuleBundleFixtures {
    public static let defaultBundle: RuleBundle = {
        do {
            return try loadMergedBundle(
                named: [
                    "auth-workflows.bundle",
                    "auth-sites.bundle",
                ],
                bundleVersion: "2026.04.13.catalog.koolaayun.3"
            )
        } catch {
            preconditionFailure("Failed to load bundled rule fixture: \(error)")
        }
    }()

    public static func loadMergedBundle(
        named resourceNames: [String],
        subdirectory: String = "RuleBundles",
        bundleVersion: String
    ) throws -> RuleBundle {
        let bundles = try resourceNames.map { try loadBundle(named: $0, subdirectory: subdirectory) }
        return try merge(bundles: bundles, bundleVersion: bundleVersion)
    }

    public static func loadBundle(
        named resourceName: String,
        subdirectory: String = "RuleBundles"
    ) throws -> RuleBundle {
        let candidates = [
            Bundle.module.url(
                forResource: resourceName,
                withExtension: "json",
                subdirectory: subdirectory
            ),
            Bundle.module.url(
                forResource: resourceName,
                withExtension: "json"
            ),
        ]

        guard let url = candidates.compactMap({ $0 }).first else {
            throw FixtureBundleError.missingResource("\(subdirectory)/\(resourceName).json")
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RuleBundle.self, from: data)
    }

    private static func merge(
        bundles: [RuleBundle],
        bundleVersion: String
    ) throws -> RuleBundle {
        guard let schemaVersion = bundles.first?.schemaVersion else {
            throw FixtureBundleError.emptyBundleList
        }
        guard bundles.allSatisfy({ $0.schemaVersion == schemaVersion }) else {
            throw FixtureBundleError.schemaVersionMismatch
        }

        let mergedCapabilities = bundles
            .flatMap(\.capabilityRefs)
            .reduce(into: [String: CapabilityReference]()) { partialResult, reference in
                if let existing = partialResult[reference.name] {
                    partialResult[reference.name] = CapabilityReference(
                        name: reference.name,
                        required: existing.required || reference.required
                    )
                } else {
                    partialResult[reference.name] = reference
                }
            }

        return RuleBundle(
            schemaVersion: schemaVersion,
            bundleVersion: bundleVersion,
            providers: bundles.flatMap(\.providers),
            sharedFragments: bundles.flatMap(\.sharedFragments),
            authWorkflows: bundles.flatMap(\.authWorkflows),
            downloadWorkflows: bundles.flatMap(\.downloadWorkflows),
            capabilityRefs: mergedCapabilities.values.sorted { $0.name < $1.name }
        )
    }
}

private enum FixtureBundleError: LocalizedError {
    case missingResource(String)
    case emptyBundleList
    case schemaVersionMismatch

    var errorDescription: String? {
        switch self {
        case .missingResource(let path):
            return "Missing bundled fixture resource \(path)"
        case .emptyBundleList:
            return "No bundled fixture resources were provided."
        case .schemaVersionMismatch:
            return "Bundled fixture resources have mismatched schema versions."
        }
    }
}
