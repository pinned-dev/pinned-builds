#include <fmt/format.h>
#include <spdlog/sinks/ostream_sink.h>
#include <spdlog/spdlog.h>

#include <memory>
#include <sstream>

int main() {
    std::ostringstream os;
    auto sink = std::make_shared<spdlog::sinks::ostream_sink_mt>(os);
    spdlog::logger logger("smoke", sink);
    logger.set_pattern("%l %v");
    logger.info("{} + {} = {}", 2, 3, 2 + 3);
    logger.flush();
    const std::string want = fmt::format("info {}\n", "2 + 3 = 5");
    if (os.str() != want) {
        fmt::print(stderr, "unexpected log line: {:?}\n", os.str());
        return 1;
    }
    fmt::print("cmake-chain smoke OK: {}", os.str());
    return 0;
}
