#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>

#include <string>

static unsigned factorial(unsigned n) { return n <= 1 ? 1 : n * factorial(n - 1); }

TEST_CASE("factorials", "[smoke]") {
    REQUIRE(factorial(0) == 1);
    REQUIRE(factorial(5) == 120);
    REQUIRE(factorial(10) == 3628800);
}

TEST_CASE("generators", "[smoke]") {
    auto n = GENERATE(1, 2, 3);
    REQUIRE(std::to_string(n).size() == 1);
}
