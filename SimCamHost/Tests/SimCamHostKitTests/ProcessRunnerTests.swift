import XCTest
import Foundation
@testable import SimCamHostKit

/// Contenedor thread-safe para acumular chunks desde colas de fondo.
private final class Box: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: String = ""
    var value: String { lock.withLock { _value } }
    func append(_ s: String) { lock.withLock { _value += s } }
}

final class ProcessRunnerTests: XCTestCase {
    func test_run_capturesStdoutAndZeroExit() throws {
        let r = try ProcessRunner.run("/bin/echo", ["hola"], env: nil)
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hola")
    }

    func test_run_capturesNonZeroExit() throws {
        let r = try ProcessRunner.run("/bin/sh", ["-c", "exit 3"], env: nil)
        XCTAssertEqual(r.exitCode, 3)
        XCTAssertFalse(r.ok)
    }

    func test_run_passesEnvToChild() throws {
        let r = try ProcessRunner.run("/bin/sh", ["-c", "echo $SIMCAM_TEST"], env: ["SIMCAM_TEST": "xyz"])
        XCTAssertEqual(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "xyz")
    }

    /// Verifica que `onOutput` recibe los chunks en tiempo real y que `r.stdout` también los contiene.
    func test_run_streamsOutputViaCallback() throws {
        let box = Box()
        let r = try ProcessRunner.run(
            "/bin/sh", ["-c", "echo a; echo b; echo c"],
            env: nil,
            onOutput: { box.append($0) }
        )
        let streamed = box.value
        XCTAssertTrue(streamed.contains("a"), "El callback debe haber recibido 'a', recibido: \(streamed)")
        XCTAssertTrue(streamed.contains("b"), "El callback debe haber recibido 'b', recibido: \(streamed)")
        XCTAssertTrue(streamed.contains("c"), "El callback debe haber recibido 'c', recibido: \(streamed)")
        XCTAssertTrue(r.stdout.contains("a"))
        XCTAssertTrue(r.stdout.contains("b"))
        XCTAssertTrue(r.stdout.contains("c"))
    }

    /// Escribe ~1 MB en stderr. Con la implementación serial (stdout primero, stderr después)
    /// este test se cuelga porque el hijo llena el buffer del pipe de stderr mientras nosotros
    /// seguimos bloqueados en readDataToEndOfFile() de stdout. Con el drenado concurrente pasa.
    func test_run_largeStderrDoesNotDeadlock() throws {
        // Vuelca ~1 MB a stderr (sin nada en stdout)
        let r = try ProcessRunner.run("/bin/sh", ["-c", "yes x | head -c 1000000 1>&2"], env: nil)
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertGreaterThanOrEqual(r.stderr.utf8.count, 1_000_000,
            "Se esperaban >= 1 MB en stderr, se recibieron \(r.stderr.utf8.count) bytes")
    }
}
