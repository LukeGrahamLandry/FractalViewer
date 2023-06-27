#ifndef float_float_h
#define float_float_h


// /////////////////////////////////////////////////////////////////////////////
// START PAPER
// Extended-Precision Floating-Point Numbers for GPU Computation, Andrew Thall
// https://andrewthall.org/papers/df64_qf128.pdf
// /////////////////////////////////////////////////////////////////////////////

float4 twoSumComp( float2 ari , float2 bri ) {
    float2 s=ari+bri;
    float2 v=s-ari;
    float2 e=(ari-(s-v))+(bri-v);
    return float4(s.x, e.x, s.y, e.y);
}

// Assumes a > b
// TODO: can they be equal?
float2 quickTwoSum( float a , float b ){
    float s=a+b;
    float e=b-(s-a);
    return float2(s, e);
}

float2 df64_add(float2 a, float2 b) {
    float4 st;
    st = twoSumComp(a, b);
    st.y += st.z;
    st.xy = quickTwoSum(st.x, st.y);
    st.y += st.w;
    st.xy = quickTwoSum(st.x, st.y);
    return st.xy;
}

#define df64_diff(a, b) df64_add(a, -b)

float2 split(float a) {
    const float split = 4097; // (1 << 12) + 1;
    float t = a*split;
    float ahi=t-(t-a);
    float alo=a-ahi;
    return float2(ahi, alo);
}
    
float4 splitComp(float2 c) {
    const float split = 4097; // (1 << 12) + 1;
    float2 t = c * split;
    float2 chi=t-(t-c);
    float2 clo=c-chi;
    return float4(chi.x, clo.x, chi.y, clo.y);
}


float2 twoProd(float a, float b) {
    float p = a*b;
    float2 aS = split(a);
    float2 bS = split(b);
    float err = ((aS.x*bS.x - p)
    + aS.x*bS.y + aS.y*bS.x)
    + aS.y*bS.y;
    return float2(p, err);
}

float2 df64_mult(float2 a, float2 b) {
    float2 p;
    p = twoProd(a.x, b.x);
    p.y += a.x * b.y;
    p.y += a.y * b.x;
    p = quickTwoSum(p.x, p.y);
    return p;
}

float2 df64_div ( float2 B, float2 A) {
    float xn = 1.0f/A.x;
    float yn = B.x*xn;
    float diff = (df64_diff(B, df64_mult(A, yn))).x;
    float2 prod = twoProd(xn, diff);
    return df64_add(yn , prod);
}

bool df64_lt(float2 a, float2 b) {
    return (a.x < b.x || (a.x == b.x && a.y < b.y));
}

bool df64_eq(float2 a, float2 b) {
    return all(a == b);
}

//float2 df64_log(float2 a) {
//    float2 xi = float2 (0.0, 0.0);
//    if (!df64_eq(a, 1.0f)) {
//        // TODO: make sure this just never happens and take it out
//        if (a.x <= 0.0) {
//            xi = float2(NAN, NAN);
//        } else {
//            xi.x = log(a.x);
//            xi = df64_add(df64_add(xi, df64_mult ( df64_exp(-xi ) , a )) , -1.0);
//        }
//    }
//    return xi;
//}

// /////////////////////////////////////////////////////////////////////////////
// END PAPER
// /////////////////////////////////////////////////////////////////////////////

// TODO: look at how the paper does quad floats. can I just use the above functions with (n)float to get (n+1)float? is that just slow? what does the renormalization do? maybe it keeps all the mantisa chunks consecutive?

typedef struct df64 {
    float2 v;
    
    df64(){
        v = { 0, 0 };
    }
    df64(float vv){
        v = { vv, 0 };
    }

    df64 operator+(df64 other) {
        return { df64_add(this->v, other.v) };
    }
    df64 operator-(df64 other) {
        return { df64_diff(this->v, other.v) };
    }
    df64 operator*(df64 other) {
        return { df64_mult(this->v, other.v) };
    }
    df64 operator/(df64 other) {
        return { df64_div(this->v, other.v) };
    }
    bool operator<(df64 other) {
        return df64_lt(this->v, other.v);
    }
    
    float toFloat() const {
        return v.x;
    }
private:
    df64(float2 vv){
        v = vv;
    }
} df64;

// TODO: this should be a float4. with new specialized versions of the other functions if I don't trust the compiler.
typedef struct df64_2 {
    df64 x;
    df64 y;
    
    df64_2(df64 xx, df64 yy) {
        x = xx;
        y = yy;
    }
    
    df64_2(float v){
        x = df64(v);
        y = df64(v);
    }
   
    df64_2(df64 v){
        x = v;
        y = v;
    }
   
    df64_2(float2 v){
        x = df64(v.x);
        y = df64(v.y);
    }
   
    df64_2 operator+(df64_2 other) {
        return { this->x + other.x, this->y + other.y};
    }
    df64_2 operator-(df64_2 other) {
        return { this->x - other.x, this->y - other.y};
    }
    df64_2 operator*(df64_2 other) {
        return { this->x * other.x, this->y * other.y};
    }
    df64_2 operator/(df64_2 other) {
        return { this->x / other.x, this->y / other.y};
    }
    
    float2 toFloat2() const {
        return { x.toFloat(), y.toFloat() };
    }
} df64_2;


#endif
