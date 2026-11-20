const std = @import("std");
const rand48 = @import("rand48");

test "Tests equivalent to the examples on the OpenGroup page" {
    // Shortcuts for rand48 structs
    const Rand = rand48.Rand;
    const RandOnPosixC = rand48.RandOnPosixC;
    const RandUnderPosixC = rand48.RandUnderPosixC;

    // Helpers functions and types for this test only
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
