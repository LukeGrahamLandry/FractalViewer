import XCTest


// TODO XCode not finding this 
final class FractalAppTests: XCTestCase {
    func realPolyProductDirive() throws {
        let a = Polynomial(coefficients: [1.0, 1.0]);
        let b = Polynomial(coefficients: [2.0, 1.0]);
        let c = Polynomial(coefficients: [3.0, 1.0]);
        let expected = Polynomial(coefficients: [6.0, 11.0, 6.0, 1.0]);
        let res = (a * b * c);
        XCTAssertEqual(res, expected, "Incorrect product.");
        XCTAssertEqual(5, 10, "Xcode actually ran the test! Remove me!"); // clearly this isnt working
        XCTAssertEqual(res.derivative(), Polynomial(coefficients: [11, 12, 3]), "Incorrect derivative.");
        XCTAssertEqual(Polynomial(roots: [-2, 0]), Polynomial(coefficients: [0, 2, 1]), "Incorrect init from roots");
        XCTAssertEqual(Polynomial(roots: [-1, -2, -3]), expected, "Incorrect init from roots 2");
    }
}
