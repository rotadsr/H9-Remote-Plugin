import Foundation

/// The 3 golden program-dump fixtures recovered as literal message-box
/// contents from `H9 Remote 1.1.5.amxd`, decoded byte-for-byte.
///
/// Note: the original patch's header line format uses "5 4" as the trailing
/// two fields for the Hall/HRMDLO fixtures but "5 2" for I WALK ALONE. The
/// header regex only captures algorithm and module number (`\[(\d+)\]
/// (\d+) \d \d`), so the exact value of those trailing two fields does not
/// affect parsing; this file preserves the original literal values.
enum H9ProgramDumpFixtures {
    static let hall =
        "[1] 0 5 4\r\n" +
        " 0 2500 3ff0 3ff0 2c92 293c 3226 3458 b12 5656 3eb6 0\r\n" +
        " 0 0 0 0 0 0 0 0 0 0 0 0 3459 2c38 0 0 5657 6fcf 7088 6264 2000 0 0 0 0 0 0 0 0 0\r\n" +
        " 0 136 0 14 9 8 4 0\r\n" +
        " 65000 65000 65000 65000 65000 65000 65000 65000 65000 65000 65000 65000\r\n" +
        "C_032c\r\n" +
        "Hall\r\n"

    static let iWalkAlone =
        "[14] 6 5 2\r\n" +
        " 6 612f 133 2aa0 3326 0 43c6 3ff0 7fe0 0 7fe0 3ff0\r\n" +
        " 0 0 0 0 0 0 0 0 0 0 0 0 3ccf 48fe 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\r\n" +
        " 0 4673 1 0 7 4 6 0\r\n" +
        " 75.24 0.93 0.5 4 0 4.77 22 99 0 99 65000 65000\r\n" +
        "C_4ce5\r\n" +
        "I WALK ALONE\r\n"

    static let hrmdlo =
        "[82] 8 5 5\r\n" +
        " 8 3ff0 3ff0 3ff0 2c92 293c 3226 3458 b12 5656 3eb6 0\r\n" +
        " 0 0 0 0 0 0 0 0 0 0 0 0 3459 2c38 0 0 5657 6fcf 7088 6264 23cf 0 0 0 0 0 0 0 0 0\r\n" +
        " 0 c42 0 14 9 8 4 0\r\n" +
        " 100 100 100 73.1981 32.2475 82.3594 709.7908 2.3379 0.5228 0.4904 65000 65000\r\n" +
        "C_469d\r\n" +
        "HRMDLO\r\n" +
        "\u{0}"
}
