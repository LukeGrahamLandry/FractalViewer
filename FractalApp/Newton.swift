import Foundation

typealias float2 = SIMD2<Float64>;

struct Polynomial: Equatable {
    var coefficients: Array<float2>;
    
    init(degree: Int) {
        assert(degree >= 0);
        self.coefficients = Array(repeating: float2(0.0, 0.0), count: degree + 1);
    }
    
    // 0 is constants, 1 is x, 2 is x^2, etc.
    init(coefficients: Array<Float64>) {
        self.coefficients = Array(repeating: float2(0.0, 0.0), count: coefficients.count);
        for (c, val) in coefficients.enumerated() {
            self.coefficients[c] += float2(val, 0.0);
        }
    }
    
    init(roots: Array<Float64>) {
        self = Polynomial(coefficients: [-roots[0], 1.0]);
        for i in 1...roots.count-1 {
            self = self * Polynomial(coefficients: [-roots[i], 1.0]);
        }
    }
    
    func derivative() -> Polynomial {
        var result = Polynomial(degree: self.coefficients.count - 1);
        for c in 1...self.coefficients.count-1 {
            let val = self.coefficients[c];
            // TODO: complex mul
            result.coefficients[c - 1] += complex_mul(val, float2(Float64(c), 0.0));
        }
        return result;
    }
}

func +(lhs: Polynomial, rhs: Polynomial) -> Polynomial {
    var result = Polynomial(degree: max(lhs.coefficients.count, rhs.coefficients.count));
    for (c, val) in lhs.coefficients.enumerated() {
        result.coefficients[c] += val;
    }
    for (c, val) in rhs.coefficients.enumerated() {
        result.coefficients[c] += val;
    }
    return result;
}

func -(lhs: Polynomial, rhs: Polynomial) -> Polynomial {
    var result = Polynomial(degree: max(lhs.coefficients.count, rhs.coefficients.count));
    for (c, val) in lhs.coefficients.enumerated() {
        result.coefficients[c] -= val;
    }
    for (c, val) in rhs.coefficients.enumerated() {
        result.coefficients[c] -= val;
    }
    return result;
}

func *(lhs: Polynomial, rhs: Polynomial) -> Polynomial {
    var result = Polynomial(degree: lhs.coefficients.count + rhs.coefficients.count);
    for (lC, lVal) in lhs.coefficients.enumerated() {
        for (rC, rVal) in rhs.coefficients.enumerated() {
            // TODO: complex multiply!
            result.coefficients[rC + lC] += complex_mul(rVal, lVal);
        }
    }
    return result;
}

func ==(lhs: Polynomial, rhs: Polynomial) -> Bool  {
    let degreeP1 = min(lhs.coefficients.count, rhs.coefficients.count);
    for c in 0...degreeP1-1 {
        if lhs.coefficients[c] != rhs.coefficients[c]{
            return false;
        }
    }
    
    if lhs.coefficients.count > degreeP1 {
        for c in degreeP1...lhs.coefficients.count-1 {
            if lhs.coefficients[c] != float2(0.0, 0.0) {
                return false;
            }
        }
    } else if rhs.coefficients.count > degreeP1 {
        for c in degreeP1...rhs.coefficients.count-1 {
            if rhs.coefficients[c] != float2(0.0, 0.0) {
                return false;
            }
        }
    }
    
    return true;
}

func complex_mul(_ a: float2, _ b: float2) -> float2 {
    return float2(
        a.x * b.x - a.y * b.y,
        a.x * b.y + b.x * a.y);
}
