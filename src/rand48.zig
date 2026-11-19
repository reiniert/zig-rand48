//! The `rand48` module provides an idiomatic Zig version of the
//! [POSIX rand48 family of functions](https://pubs.opengroup.org/onlinepubs/9799919799/functions/drand48.html),
//! implemented to provide the same functionality but with Zig-native
//! types and more comprehensible names. As prescribed, it uses a Linear
//! Congruential Generator (LCG) based on 48-bit arithmetic internally.
//!
//! `rand48` exposes the following:
//! - [`Rand`](#Rand): The main struct for using the Zig-idiomatic interface.
//! - [`LcgState`](#LcgState): A struct for holding and passing the state of the LCG.
//! - [`RandOverPosixC`](#RandOverPosixC): An implementation of the Zig-idiomatic interface relying on the platform's implementation of the `rand48` functions.
//! - [`RandUnderPosixC`](#RandUnderPosixC): A struct containing functions exposing the native Zig implementation with a C ABI for the POSIX functions.
//!
//! The implemented behavior is as prescribed by POSIX, with the following remarks:
//! - Its implementation is not thread-safe.
//!   - This is allowed by the spec.
//! - Every instance of the struct instantiates its own LCG.
//!   - The spec does not have this concept, the LCG is global.
//!   - To mimic the POSIX behavior, use a single global instance of [`Rand`](#Rand).
//! - The C ABI is intended as a drop-in for existing C code using these functions.
//!   - The idea is that linking with this library is all that is needed.
//!
//! This is a toy project, for educational purposes only.
const std = @import("std");

/// The main struct for using the Zig-idiomatic interface to the rand48 family of functions,
/// with a pure Zig-native implementation.
pub const Rand = struct {
    /// Internal LCG state used by this instance.
    _lcg: Lcg = Lcg{},

    /// Helper function if you prefer to work with 16-bit chunks instead of a 48-bit integer.
    pub fn u48FromU16s(values: [3]u16) u48 {
        var result: u48 = values[2];
        result = (result << 16) + values[1];
        result = (result << 16) + values[0];
        return result;
    }

    /// Helper function if you prefer to work with 16-bit chunks instead of a 48-bit integer.
    pub fn u16sFromU48(state: u48) [3]u16 {
        return [3]u16{
            @truncate(state >> 0),
            @truncate(state >> 16),
            @truncate(state >> 32),
        };
    }

    /// Extracts differently typed values from 48 bits state.
    fn extractValue(state: u48, comptime T: type) T {
        // Extraction logic per type, based on the 48-bit LCG state.
        switch (T) {
            f64 => {
                // Range [0.0, 1.0)
                // Construct IEEE 754 double-precision float in [1.0, 2.0) and subtract 1
                const exponent: u64 = 0x3FF << 52;
                const mantissa: u64 = state;
                // 48 bits do not fill 52-bit mantissa, shifting left per POSIX
                const one_two: f64 = @bitCast(exponent | (mantissa << 4));
                // For IEEE 754 floats, this is an exact subtraction
                return one_two - 1.0;
            },
            u31 => {
                // Range [0, 2³¹)
                // Use the lefmost 31 bits.
                return @truncate(state >> 17);
            },
            i32 => {
                // Range [-2³¹, 2³¹)
                // Use the lefmost 32 bits.
                const shifted: u32 = @truncate(state >> 16);
                return @bitCast(shifted);
            },
            else => @compileError("Unsupported type for Rand48.next(). Use f64, u31, or i32."),
        }
    }

    /// `drand48` equivalent: returns a floating-point number in [0.0, 1.0).
    pub fn nextFloat(self: *Rand) f64 {
        return extractValue(self._lcg.next(), f64);
    }

    /// `erand48` equivalent: returns a floating-point number in [0.0, 1.0) from a given state
    /// and updates the contents of the given bits with the subsequent LCG state,
    /// without updating the internal LCG state itself.
    pub fn nextFloatWithBits(self: Rand, bits: *u48) f64 {
        bits.* = self._lcg.nextWithBits(bits.*);
        return extractValue(bits.*, f64);
    }

    /// `lrand48` equivalent: returns an unsigned integer in [0, 2³¹).
    pub fn nextUnsigned(self: *Rand) u31 {
        return extractValue(self._lcg.next(), u31);
    }

    /// `nrand48` equivalent: returns an unsigned integer in [0, 2³¹) from a given state
    /// and updates the contents of the given bits with the subsequent LCG state,
    /// without updating the internal LCG state itself.
    pub fn nextUnsignedWithBits(self: Rand, bits: *u48) u31 {
        bits.* = self._lcg.nextWithBits(bits.*);
        return extractValue(bits.*, u31);
    }

    /// `mrand48` equivalent: returns a signed integer in [-2³¹, 2³¹)
    ///  and updates the internal LCG state accordingly.
    pub fn nextSigned(self: *Rand) i32 {
        return extractValue(self._lcg.next(), i32);
    }

    /// `jrand48` equivalent: returns a signed integer in [-2³¹, 2³¹) from a given state
    /// and updates the contents of the given bits with the subsequent LCG state,
    /// without updating the internal LCG state itself.
    pub fn nextSignedWithBits(self: Rand, bits: *u48) i32 {
        bits.* = self._lcg.nextWithBits(bits.*);
        return extractValue(bits.*, i32);
    }

    /// `lcong48` equivalent: sets the LCG state, multiplier, and addend.
    pub fn initState(self: *Rand, state: LcgState) void {
        self._lcg.initState(state);
    }

    /// `srand48` equivalent: initializes the generator with a given value
    /// and resets the multiplier and addend to their default values.
    pub fn initRand(self: *Rand, value: u32) void {
        self._lcg.initRand(value);
    }

    /// `seed48` equivalent: sets the LCG state and resets the multiplier and addend
    /// and returns the previous state.
    pub fn initSeed(self: *Rand, bits: u48) u48 {
        return self._lcg.initSeed(bits);
    }
};

/// This structure is used to represent the complete state of the LCG
/// including the current state, the multiplier, and the addend.
/// Nothing else about the LCG is exposed in this module.
pub const LcgState = struct {
    bits: u48,
    a: u48,
    c: u16,
};

/// Linear Congruential Generator (LCG) state structure
/// is the basis for all variations of this rand family.
const Lcg = struct {

    // POSIX defines default bits, multiplier and addend.
    const state_default = LcgState{
        .bits = 0x330E,
        .a = 0x5DEECE66D,
        .c = 0x0B,
    };

    _state: LcgState = state_default,

    /// Advance one step from the given state with the specified multiplier and addend.
    fn nextWithState(state: LcgState) u48 {
        // Promote to double the width to avoid overflow
        const wide_state: u96 = state.bits;
        const intermediate = wide_state * state.a + state.c;
        // Truncating at 48 bits is the same as doing mod 2⁴⁸
        return @truncate(intermediate);
    }

    /// Advance one step from the given state using the current multiplier and addend.
    fn nextWithBits(self: Lcg, bits: u48) u48 {
        return Lcg.nextWithState(.{
            .bits = bits,
            .a = self._state.a,
            .c = self._state.c,
        });
    }

    /// Advance one step from internal state and update it as well.
    fn next(self: *Lcg) u48 {
        self._state.bits = Lcg.nextWithState(self._state);
        return self._state.bits;
    }

    /// Query the LCG parameters (state, multiplier, and addend).<br>
    /// The POSIX functions do not need this, but it seems useful to
    /// have for users of this struct.
    fn getState(self: Lcg) LcgState {
        return LcgState{
            .bits = self._state.bits,
            .a = self._state.a,
            .c = self._state.c,
        };
    }

    /// Set all LCG parameters (state, multiplier, and addend).
    fn initState(self: *Lcg, state: LcgState) void {
        self._state = state;
    }

    /// Set the LCG state, reset the multiplier and addend to their default values,
    /// and return the previous state value.
    fn initSeed(self: *Lcg, bits: u48) u48 {
        const old_state = self._state.bits;
        self.initState(LcgState{
            .bits = bits,
            .a = Lcg.state_default.a,
            .c = Lcg.state_default.c,
        });
        return old_state;
    }

    /// Set the LCG state using an integer following the POSIX convention
    /// and reset its multiplier and addend to their default values.
    fn initRand(self: *Lcg, value: u32) void {
        const bits: u48 = value;
        _ = self.initSeed((bits << 16) + Lcg.state_default.bits);
    }
};

/// POSIX-compliant C ABI for the Rand48 family of functions, with its implementation
/// provided by the [`Rand`](#Rand) struct in this module. It is usable from within
/// zig as well, although that does not seem to have any advantage over using the
/// [`Rand`](#Rand) struct directly.<br>
/// The public functions on this struct have the following properties:
/// - All of them operate on a global instance of the Zig Rand48 state.
///   - This state is shared across all users of this struct in the same process.
///   - This state is not protected against concurrent access so the functions are not thread-safe.
///   - This is in line with the behavior of the standard POSIX rand48 functions.
/// - They are all namespaced functions, not member functions of the struct.
///   - They are therefore intended to be invoked like `RandPosixC.function_name(...)`.
/// - They are exported and accessible from a POSIX-compliant C applications, as a drop-in.
pub const RandUnderPosixC = struct {

    // Private global instance of the Zig Rand48 state.
    // Note that this is shared across all users of this class in the same process.
    // No effort has been made to make this thread-safe.
    var _zrand = Rand{};

    /// Helper function for working with 48-bit integers instead of ushort arrays.
    fn u48FromUshorts(ushorts: [3]c_ushort) u48 {
        // Per the spec, we need the low-order 16 bits of each value
        var result: u48 = @as(u16, @truncate(ushorts[2]));
        result = (result << 16) + @as(u16, @truncate(ushorts[1]));
        result = (result << 16) + @as(u16, @truncate(ushorts[0]));
        return result;
    }

    /// Helper function for working with 48-bit integers instead of ushort arrays.
    fn ushortsFromU48(state: u48) [3]c_ushort {
        // The spec prescribes that only the lowest 16 bits should be set
        return [3]c_ushort{
            @as(u16, @truncate(state >> 0)),
            @as(u16, @truncate(state >> 16)),
            @as(u16, @truncate(state >> 32)),
        };
    }

    /// Helper function for working with a state struct as opposed to ushort array
    fn lcgStateFromShorts(param: [7]c_ushort) LcgState {
        const bits = u48FromUshorts(param[0..3].*);
        const a = u48FromUshorts(param[3..6].*);
        const c: u16 = @intCast(param[6] & 0xFFFF);
        return .{ .bits = bits, .a = a, .c = c };
    }

    /// Helper function for working with a state struct as opposed to ushort array
    fn shortsFromLcgState(state: LcgState) [7]c_ushort {
        const bit_shorts = ushortsFromU48(state.bits);
        const a_shorts = ushortsFromU48(state.a);
        return .{ bit_shorts.*, a_shorts.*, state.c };
    }

    /// Shim for C POSIX-compliant implementation of
    /// `double drand48(void);`<br>
    /// Returns a floating-point number in [0.0, 1.0) from the internal LCG state,
    /// updating it in the process.
    pub export fn drand48() f64 {
        return _zrand.nextFloat();
    }

    /// Shim for C POSIX-compliant implementation of
    /// `double erand48(unsigned short xsubi[3]);`<br>
    /// Returns a floating-point number in [0.0, 1.0) from the given state,
    /// without updating the internal LCG state.
    pub export fn erand48(xsubi: *[3]c_ushort) f64 {
        var zbits: u48 = u48FromUshorts(xsubi.*);
        const zres = _zrand.nextFloatWithBits(&zbits);
        xsubi.* = ushortsFromU48(zbits);
        return zres;
    }

    /// Shim for C POSIX-compliant implementation of
    /// `long int jrand48(unsigned short xsubi[3]);`<br>
    /// Returns an integer value in [0, 2³¹) from the given state,
    /// without updating the internal LCG state.
    pub export fn jrand48(xsubi: *[3]c_ushort) c_long {
        var zbits = u48FromUshorts(xsubi.*);
        const zres = _zrand.nextSignedWithBits(&zbits);
        xsubi.* = ushortsFromU48(zbits);
        return zres;
    }

    /// Shim for C POSIX-compliant implementation of
    /// `long int lrand48(void);`<br>
    /// Returns an integer value in [0, 2³¹) from the internal LCG state,
    /// updating it in the process.
    pub export fn lrand48() c_long {
        return _zrand.nextUnsigned();
    }

    /// Shim for C POSIX-compliant implementation of
    /// `long int mrand48(void);`<br>
    /// Returns an integer value in [-2³¹, 2³¹) from the internal LCG state,
    /// updating it in the process.
    pub export fn mrand48() c_long {
        return _zrand.nextSigned();
    }

    /// Shim for C POSIX-compliant implementation of
    /// `long int nrand48(unsigned short xsubi[3]);`<br>
    /// Returns an integer value in [0, 2³¹) from the given state value,
    /// without updating the internal LCG state.
    pub export fn nrand48(xsubi: *[3]c_ushort) c_long {
        var zbits = u48FromUshorts(xsubi.*);
        const zres = _zrand.nextUnsignedWithBits(&zbits);
        xsubi.* = ushortsFromU48(zbits);
        return @intCast(zres);
    }

    // Private buffer of C unsigned shorts, used and exposed by seed48
    var _last_seed_shorts: [3]c_ushort = undefined;

    /// Shim for C POSIX-compliant implementation of
    /// `unsigned short *seed48(unsigned short seed16v[3]);`<br>
    /// Sets the internal LCG state based on the given seed array.<br>
    /// Note that the returned pointer as well as the provided
    /// seed16v pointer should be considered `const` but we stick with
    /// the original POSIX definition here.
    pub export fn seed48(seed16v: *[3]c_ushort) *[3]c_ushort {
        const zbits = u48FromUshorts(seed16v.*);
        const old_zstate = _zrand.initSeed(zbits);
        _last_seed_shorts = ushortsFromU48(old_zstate);
        return &_last_seed_shorts;
    }

    /// Shim for C POSIX-compliant implementation of
    /// `void srand48(long int seedval);`<br>
    /// Sets the internal LCG state based on the given seed value.
    pub export fn srand48(seedval: c_long) void {
        // Only take the 32 low-order bits, as prescribed
        const zval: u32 = @intCast(seedval & 0xFFFFFFFF);
        _zrand.initRand(zval);
    }

    /// Shim for C POSIX-compliant implementation of
    /// `void lcong48(unsigned short param[7]);`<br>
    /// Sets the internal LCG state and generator parameters based on
    /// the given array of unsigned shorts.<br>
    /// Note that the provided seed16v pointer should be considered
    /// `const`, but we stick with the original POSIX definition here.
    pub export fn lcong48(param: *[7]c_ushort) void {
        const lcgState = RandUnderPosixC.lcgStateFromShorts(param.*);
        _zrand.initState(lcgState);
    }
};

// This is needed to ensure that the RandPosixC struct is analyzed at compile time
// and the symbols in the struct are exported at all.
comptime {
    _ = RandUnderPosixC;
}

/// An alternative struct for using the Zig-idiomatic interface to the rand48 family of functions,
/// that forwards all calls to the platform's standard POSIX C rand48 implementation.
pub const RandOnPosixC = struct {
    // For the sake of simplicity, define the function prototypes manually here.
    // See https://pubs.opengroup.org/onlinepubs/9799919799/functions/drand48.html
    extern "c" fn drand48() f64;
    extern "c" fn erand48(xsubi: *[3]c_ushort) f64;
    extern "c" fn jrand48(xsubi: *[3]c_ushort) c_long;
    extern "c" fn lcong48(param: *[7]c_ushort) void;
    extern "c" fn lrand48() c_long;
    extern "c" fn mrand48() c_long;
    extern "c" fn nrand48(xsubi: *[3]c_ushort) c_long;
    extern "c" fn seed48(seed16v: *[3]c_ushort) *[3]c_ushort;
    extern "c" fn srand48(seedval: c_long) void;

    /// `drand48` equivalent: returns a floating-point number in [0.0, 1.0).
    pub fn nextFloat(_: *RandOnPosixC) f64 {
        return drand48();
    }

    /// `erand48` equivalent: returns a floating-point number in [0.0, 1.0) from a given state
    /// and updates the contents of the given bits with the subsequent LCG state,
    /// without updating the internal LCG state itself.
    pub fn nextFloatWithBits(_: RandOnPosixC, bits: *u48) f64 {
        var xsubi = RandUnderPosixC.ushortsFromU48(bits.*);
        const result = erand48(&xsubi);
        bits.* = RandUnderPosixC.u48FromUshorts(xsubi);
        return result;
    }

    /// `lrand48` equivalent: returns an unsigned integer in [0, 2³¹).
    pub fn nextUnsigned(_: *RandOnPosixC) u31 {
        const result = lrand48();
        return @intCast(result);
    }

    /// `nrand48` equivalent: returns an unsigned integer in [0, 2³¹) from a given state
    /// and updates the contents of the given bits with the subsequent LCG state,
    /// without updating the internal LCG state itself.
    pub fn nextUnsignedWithBits(_: RandOnPosixC, bits: *u48) u31 {
        var xsubi = RandUnderPosixC.ushortsFromU48(bits.*);
        const result = nrand48(&xsubi);
        bits.* = RandUnderPosixC.u48FromUshorts(xsubi);
        return @intCast(result);
    }

    /// `mrand48` equivalent: returns a signed integer in [-2³¹, 2³¹)
    ///  and updates the internal LCG state accordingly.
    pub fn nextSigned(_: *RandOnPosixC) i32 {
        const result = mrand48();
        return @intCast(result);
    }

    /// `jrand48` equivalent: returns a signed integer in [-2³¹, 2³¹) from a given state
    /// and updates the contents of the given bits with the subsequent LCG state,
    /// without updating the internal LCG state itself.
    pub fn nextSignedWithBits(_: RandOnPosixC, bits: *u48) i32 {
        var xsubi = RandUnderPosixC.ushortsFromU48(bits.*);
        const result = jrand48(&xsubi);
        bits.* = RandUnderPosixC.u48FromUshorts(xsubi);
        return @intCast(result);
    }

    /// `lcong48` equivalent: sets the LCG state, multiplier, and addend.
    pub fn initState(_: *RandOnPosixC, state: LcgState) void {
        const param_shorts = RandUnderPosixC.shortsFromLcgState(state);
        lcong48(&param_shorts);
    }

    /// `srand48` equivalent: initializes the generator with a given value
    /// and resets the multiplier and addend to their default values.
    pub fn initRand(_: *RandOnPosixC, value: u32) void {
        srand48(value);
    }

    /// `seed48` equivalent: sets the LCG state and resets the multiplier and addend
    /// and returns the previous state.
    pub fn initSeed(_: *RandOnPosixC, bits: u48) u48 {
        const seed_shorts = RandUnderPosixC.shortsFromU48(bits);
        const seed_ptr = seed48(&seed_shorts);
        return RandUnderPosixC.u48FromUshorts(seed_ptr.*);
    }
};

test "Tests equivalent to the examples on the OpenGroup page" {
    const Helper = struct {

        // Type-specific struct to capture the expected result
        fn Expected(comptime T: type) type {
            return struct {
                value: T,
                bits: u48,

                fn init(val: T, xsubi: [3]u16) @This() {
                    return .{
                        .value = val,
                        .bits = Rand.u48FromU16s(xsubi),
                    };
                }
            };
        }

        // An array of the above structs, accompanied by a starting value for the LCG state bits.
        pub fn ExpectedGroup(comptime T: type) type {
            return struct {
                pub fn Sized(comptime N: usize) type {
                    return struct {
                        initial_bits: [3]u16,
                        cases: [N]Expected(T),
                    };
                }

                pub fn init(initial_bits: [3]u16, cases: anytype) Sized(cases.len) {
                    return .{
                        .initial_bits = initial_bits,
                        .cases = cases,
                    };
                }
            };
        }

        // Helper function for comparing floating-point and integer values with a tolerance for floats.
        fn isEqualIsh(val: anytype, expected_val: @TypeOf(val)) bool {
            return switch (@typeInfo(@TypeOf(val))) {
                .float => (expected_val <= val) and (val <= expected_val + 0.01),
                .int => val == expected_val,
                else => @compileError("Unsupported type for inRange: " ++ @typeName(@TypeOf(val))),
            };
        }
    };

    // Test vectors as found in the POSIX rand48 speciifcation
    const erand_vectors = Helper.ExpectedGroup(f64).init(
        .{ 37174, 64810, 11603 },
        [_]Helper.Expected(f64){
            .init(0.896, .{ 22537, 47966, 58735 }),
            .init(0.337, .{ 37344, 32911, 22119 }),
            .init(0.647, .{ 23659, 29872, 42445 }),
            .init(0.500, .{ 31642, 7875, 32802 }),
            .init(0.506, .{ 64669, 14399, 33170 }),
        },
    );

    const jrand_vectors = Helper.ExpectedGroup(i32).init(
        .{ 25175, 11052, 45015 },
        [_]Helper.Expected(i32){
            .init(1699503220, .{ 2326, 23668, 25932 }),
            .init(-992276007, .{ 41577, 4569, 50395 }),
            .init(-19535776, .{ 31936, 59488, 65237 }),
            .init(79438377, .{ 40395, 8745, 1212 }),
            .init(-1258917728, .{ 37242, 28832, 46326 }),
        },
    );

    const nrand_vectors = Helper.ExpectedGroup(u31).init(
        .{ 546, 33817, 23389 },
        [_]Helper.Expected(u31){
            .init(914920692, .{ 29829, 10728, 27921 }),
            .init(754104482, .{ 6828, 28997, 23013 }),
            .init(609453945, .{ 58183, 3826, 18599 }),
            .init(1878644360, .{ 36678, 44304, 57331 }),
            .init(2114923686, .{ 58585, 22861, 64542 }),
        },
    );

    // The Zig-style Rand instance with Zig implementation
    // It is instatiated with the default parameters
    var rand = Rand{};
    // The bits variable is reused across all Zig-style tests
    var bits: u48 = undefined;

    // The Zig-style Rand interface with POSIX implementation
    // It relies on the libc implememtation and does not maintain any state itself.
    var randOnPosix = RandOnPosixC{};
    // The bits variable is reused across all Zig-style tests with POSIX implementation
    var bits_posix: u48 = undefined;

    // The POSIX-C-based implementation need xsubi arrays as opposed to u48 values
    // The xsubi array is reused across all POSIX-C-based tests
    var xsubi: [3]c_ushort = undefined;

    bits = Rand.u48FromU16s(erand_vectors.initial_bits);
    bits_posix = bits;
    xsubi = RandUnderPosixC.ushortsFromU48(bits);
    for (erand_vectors.cases) |expected| {
        const d = rand.nextFloatWithBits(&bits);
        try std.testing.expect(Helper.isEqualIsh(d, expected.value));
        try std.testing.expect(Helper.isEqualIsh(bits, expected.bits));
        const d_posix = randOnPosix.nextFloatWithBits(&bits_posix);
        try std.testing.expect(Helper.isEqualIsh(d_posix, expected.value));
        try std.testing.expect(Helper.isEqualIsh(bits_posix, expected.bits));
        const d_c = RandUnderPosixC.erand48(&xsubi);
        try std.testing.expect(Helper.isEqualIsh(d_c, expected.value));
        try std.testing.expect(Helper.isEqualIsh(RandUnderPosixC.u48FromUshorts(xsubi), expected.bits));
    }

    bits = Rand.u48FromU16s(jrand_vectors.initial_bits);
    bits_posix = bits;
    xsubi = RandUnderPosixC.ushortsFromU48(bits);
    for (jrand_vectors.cases) |expected| {
        const j = rand.nextSignedWithBits(&bits);
        try std.testing.expect(Helper.isEqualIsh(j, expected.value));
        try std.testing.expect(Helper.isEqualIsh(bits, expected.bits));
        const j_posix = randOnPosix.nextSignedWithBits(&bits_posix);
        try std.testing.expect(Helper.isEqualIsh(j_posix, expected.value));
        try std.testing.expect(Helper.isEqualIsh(bits_posix, expected.bits));
        const j_c = RandUnderPosixC.jrand48(&xsubi);
        try std.testing.expect(Helper.isEqualIsh(j_c, expected.value));
        try std.testing.expect(Helper.isEqualIsh(RandUnderPosixC.u48FromUshorts(xsubi), expected.bits));
    }

    bits = Rand.u48FromU16s(nrand_vectors.initial_bits);
    bits_posix = bits;
    xsubi = RandUnderPosixC.ushortsFromU48(bits);
    for (nrand_vectors.cases) |expected| {
        const n = rand.nextUnsignedWithBits(&bits);
        try std.testing.expect(Helper.isEqualIsh(n, expected.value));
        try std.testing.expect(Helper.isEqualIsh(bits, expected.bits));
        const n_posix = randOnPosix.nextUnsignedWithBits(&bits_posix);
        try std.testing.expect(Helper.isEqualIsh(n_posix, expected.value));
        try std.testing.expect(Helper.isEqualIsh(bits_posix, expected.bits));
        const n_c = RandUnderPosixC.nrand48(&xsubi);
        try std.testing.expect(Helper.isEqualIsh(n_c, expected.value));
        try std.testing.expect(Helper.isEqualIsh(RandUnderPosixC.u48FromUshorts(xsubi), expected.bits));
    }
}
