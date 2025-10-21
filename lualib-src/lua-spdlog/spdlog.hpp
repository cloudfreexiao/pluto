#pragma once

// https://github.com/bodgergely/spdlog-python

#include <spdlog/async.h>
#include <spdlog/async_logger.h>
#include <spdlog/details/null_mutex.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/daily_file_sink.h>
#include <spdlog/sinks/dist_sink.h>
#include <spdlog/sinks/dup_filter_sink.h>
#include <spdlog/sinks/null_sink.h>
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/sinks/stdout_sinks.h>
#include <spdlog/sinks/tcp_sink.h>
#include <spdlog/spdlog.h>

#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace pluto {

class Logger;

bool g_async_mode_on = false;
auto g_async_overflow_policy = spdlog::async_overflow_policy::block;

std::unordered_map<std::string, Logger*> g_loggers;
std::mutex mutex_loggers;

void register_logger(const std::string& name, Logger* logger) {
    std::lock_guard<std::mutex> lck(mutex_loggers);
    g_loggers[name] = logger;
}

Logger* access_logger(const std::string& name) {
    std::lock_guard<std::mutex> lck(mutex_loggers);
    return g_loggers[name];
}

void remove_logger(const std::string& name) {
    std::lock_guard<std::mutex> lck(mutex_loggers);
    g_loggers[name] = nullptr;
    g_loggers.erase(name);
}

void remove_logger_all() {
    std::lock_guard<std::mutex> lck(mutex_loggers);
    g_loggers.clear();
}

class LogLevel {
public:
    const static int trace { (int)spdlog::level::trace };
    const static int debug { (int)spdlog::level::debug };
    const static int info { (int)spdlog::level::info };
    const static int warn { (int)spdlog::level::warn };
    const static int err { (int)spdlog::level::err };
    const static int critical { (int)spdlog::level::critical };
    const static int off { (int)spdlog::level::off };
};

class Sink {
public:
    Sink() = default;
    explicit Sink(const spdlog::sink_ptr& sink): _sink(sink) {}
    virtual ~Sink() {}
    virtual void log(const spdlog::details::log_msg& msg) {
        _sink->log(msg);
    }
    bool should_log(int msg_level) const {
        return _sink->should_log((spdlog::level::level_enum)msg_level);
    }
    void set_level(int log_level) {
        _sink->set_level((spdlog::level::level_enum)log_level);
    }
    int level() const {
        return (int)_sink->level();
    }
    spdlog::sink_ptr get_sink() const {
        return _sink;
    }

protected:
    spdlog::sink_ptr _sink { nullptr };
};

class stdout_sink_st: public Sink {
public:
    stdout_sink_st() {
        _sink = std::make_shared<spdlog::sinks::stdout_sink_st>();
    }
};

class stdout_sink_mt: public Sink {
public:
    stdout_sink_mt() {
        _sink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
    }
};

class stdout_color_sink_st: public Sink {
public:
    stdout_color_sink_st() {
        _sink = std::make_shared<spdlog::sinks::stdout_color_sink_st>();
    }
};

class stdout_color_sink_mt: public Sink {
public:
    stdout_color_sink_mt() {
        _sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
    }
};

class stderr_sink_st: public Sink {
public:
    stderr_sink_st() {
        _sink = std::make_shared<spdlog::sinks::stderr_sink_st>();
    }
};

class stderr_sink_mt: public Sink {
public:
    stderr_sink_mt() {
        _sink = std::make_shared<spdlog::sinks::stderr_sink_mt>();
    }
};

class stderr_color_sink_st: public Sink {
public:
    stderr_color_sink_st() {
        _sink = std::make_shared<spdlog::sinks::stderr_color_sink_st>();
    }
};

class stderr_color_sink_mt: public Sink {
public:
    stderr_color_sink_mt() {
        _sink = std::make_shared<spdlog::sinks::stderr_color_sink_mt>();
    }
};

class basic_file_sink_st: public Sink {
public:
    basic_file_sink_st(const std::string& base_filename, bool truncate) {
        _sink = std::make_shared<spdlog::sinks::basic_file_sink_st>(base_filename, truncate);
    }
};

class basic_file_sink_mt: public Sink {
public:
    basic_file_sink_mt(const std::string& base_filename, bool truncate) {
        _sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(base_filename, truncate);
    }
};

class daily_file_sink_mt: public Sink {
public:
    daily_file_sink_mt(const std::string& base_filename, int rotation_hour, int rotation_minute) {
        _sink = std::make_shared<spdlog::sinks::daily_file_sink_mt>(
            base_filename,
            rotation_hour,
            rotation_minute
        );
    }
};

class daily_file_sink_st: public Sink {
public:
    daily_file_sink_st(const std::string& base_filename, int rotation_hour, int rotation_minute) {
        _sink = std::make_shared<spdlog::sinks::daily_file_sink_st>(
            base_filename,
            rotation_hour,
            rotation_minute
        );
    }
};

class rotating_file_sink_mt: public Sink {
public:
    rotating_file_sink_mt(const std::string& filename, size_t max_file_size, size_t max_files) {
        _sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>(
            filename,
            max_file_size,
            max_files
        );
    }
};

class rotating_file_sink_st: public Sink {
public:
    rotating_file_sink_st(const std::string& filename, size_t max_file_size, size_t max_files) {
        _sink = std::make_shared<spdlog::sinks::rotating_file_sink_st>(
            filename,
            max_file_size,
            max_files
        );
    }
};

template<typename Mutex>
class dist_sink: public Sink {
public:
    dist_sink() {
        _sink = std::make_shared<spdlog::sinks::dist_sink<Mutex>>();
    }
    dist_sink(std::vector<Sink> sinks) {
        std::vector<spdlog::sink_ptr> sink_vec;
        for (const auto & sink : sinks) {
            sink_vec.push_back(sink.get_sink());
        }
        _sink = std::make_shared<spdlog::sinks::dist_sink<Mutex>>(sink_vec);
    }
    void add_sink(const Sink& sink) {
        std::dynamic_pointer_cast<spdlog::sinks::dist_sink<Mutex>>(_sink)->add_sink(sink.get_sink()
        );
    }

    void remove_sink(const Sink& sink) {
        std::dynamic_pointer_cast<spdlog::sinks::dist_sink<Mutex>>(_sink)->remove_sink(
            sink.get_sink()
        );
    }

    void set_sinks(std::vector<Sink> sinks) {
        std::vector<spdlog::sink_ptr> sink_vec;
        for (const auto & sink : sinks) {
            sink_vec.push_back(sink.get_sink());
        }
        std::dynamic_pointer_cast<spdlog::sinks::dist_sink<Mutex>>(_sink)->set_sinks(sink_vec);
    }

    std::vector<spdlog::sink_ptr>& sinks() {
        return std::dynamic_pointer_cast<spdlog::sinks::dist_sink<Mutex>>(_sink)->sinks();
    }
};

using dist_sink_mt = dist_sink<std::mutex>;
using dist_sink_st = dist_sink<spdlog::details::null_mutex>;

class dup_filter_sink_mt: public dist_sink_mt {
public:
    dup_filter_sink_mt(float max_skip_duration_sec) {
        _sink = std::make_shared<spdlog::sinks::dup_filter_sink_mt>(
            std::chrono::milliseconds((int)(max_skip_duration_sec * 1000.0))
        );
    }
};

class dup_filter_sink_st: public dist_sink_st {
public:
    dup_filter_sink_st(float max_skip_duration_sec) {
        _sink = std::make_shared<spdlog::sinks::dup_filter_sink_st>(
            std::chrono::milliseconds((int)(max_skip_duration_sec * 1000.0))
        );
    }
};

class null_sink_st: public Sink {
public:
    null_sink_st() {
        _sink = std::make_shared<spdlog::sinks::null_sink_st>();
    }
};

class null_sink_mt: public Sink {
public:
    null_sink_mt() {
        _sink = std::make_shared<spdlog::sinks::null_sink_mt>();
    }
};

class Logger {
public:
    using async_factory_nb =
        spdlog::async_factory_impl<spdlog::async_overflow_policy::overrun_oldest>;

    Logger(const std::string& name, bool async_mode): _name(name), _async(async_mode) {
        register_logger(name, this);
    }

    virtual ~Logger() {}
    std::string name() const {
        if (_logger) {
            return _logger->name();
        } else {
            return "NULL";
        }
    }
    void log(int level, const std::string& msg) const {
        this->_logger->log((spdlog::level::level_enum)level, msg);
    }
    void trace(const std::string& msg) const {
        this->_logger->trace(msg);
    }
    void debug(const std::string& msg) const {
        this->_logger->debug(msg);
    }
    void info(const std::string& msg) const {
        this->_logger->info(msg);
    }
    void warn(const std::string& msg) const {
        this->_logger->warn(msg);
    }
    void error(const std::string& msg) const {
        this->_logger->error(msg);
    }
    void critical(const std::string& msg) const {
        this->_logger->critical(msg);
    }

    bool should_log(int level) const {
        return _logger->should_log((spdlog::level::level_enum)level);
    }

    void set_level(int level) {
        _logger->set_level((spdlog::level::level_enum)level);
    }

    int level() const {
        return (int)_logger->level();
    }

    void set_pattern(
        const std::string& pattern,
        spdlog::pattern_time_type type = spdlog::pattern_time_type::local
    ) {
        _logger->set_pattern(pattern, type);
    }

    // automatically call flush() if message level >= log_level
    void flush_on(int log_level) {
        _logger->flush_on((spdlog::level::level_enum)log_level);
    }

    void flush() {
        _logger->flush();
    }

    bool async() {
        return _async;
    }

    void close() {
        remove_logger(_name);
        _logger = nullptr;
        spdlog::drop(_name);
    }

    std::vector<Sink> sinks() const {
        std::vector<Sink> snks;
        for (const spdlog::sink_ptr& sink: _logger->sinks()) {
            snks.emplace_back(sink);
        }
        return snks;
    }

    void set_error_handler(spdlog::err_handler handler) {
        _logger->set_error_handler(handler);
    }

    std::shared_ptr<spdlog::logger> get_underlying_logger() {
        return _logger;
    }

protected:
    const std::string _name;
    bool _async;
    std::shared_ptr<spdlog::logger> _logger { nullptr };
};

class ConsoleLogger: public Logger {
public:
    ConsoleLogger(
        const std::string& logger_name,
        bool multithreaded,
        bool standard_out,
        bool colored,
        bool async_mode = g_async_mode_on
    ):
        Logger(logger_name, async_mode) {
        if (standard_out) {
            if (multithreaded) {
                if (colored) {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stdout_color_mt<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stdout_color_mt<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stdout_color_mt(logger_name);
                    }
                } else {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stdout_logger_mt<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stdout_logger_mt<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stdout_logger_mt(logger_name);
                    }
                }
            } else {
                if (colored) {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stdout_color_st<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stdout_color_st<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stdout_color_st(logger_name);
                    }
                } else {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stdout_logger_st<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stdout_logger_st<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stdout_logger_st(logger_name);
                    }
                }
            }

        } else {
            if (multithreaded) {
                if (colored) {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stderr_color_mt<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stderr_color_mt<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stderr_color_mt(logger_name);
                    }
                } else {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stderr_logger_mt<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stderr_logger_mt<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stderr_logger_mt(logger_name);
                    }
                }
            } else {
                if (colored) {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stderr_color_st<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stderr_color_st<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stderr_color_st(logger_name);
                    }
                } else {
                    if (async_mode) {
                        if (g_async_overflow_policy
                            == spdlog::async_overflow_policy::overrun_oldest)
                        {
                            _logger = spdlog::stderr_logger_st<async_factory_nb>(logger_name);
                        } else {
                            _logger = spdlog::stderr_logger_st<spdlog::async_factory>(logger_name);
                        }
                    } else {
                        _logger = spdlog::stderr_logger_st(logger_name);
                    }
                }
            }
        }
    }
};

class FileLogger: public Logger {
public:
    FileLogger(
        const std::string& logger_name,
        const std::string& filename,
        bool multithreaded,
        bool truncate = false,
        bool async_mode = g_async_mode_on
    ):
        Logger(logger_name, async_mode) {
        if (multithreaded) {
            if (async_mode) {
                if (g_async_overflow_policy == spdlog::async_overflow_policy::overrun_oldest) {
                    _logger =
                        spdlog::basic_logger_mt<async_factory_nb>(logger_name, filename, truncate);
                } else {
                    _logger = spdlog::basic_logger_mt<spdlog::async_factory>(
                        logger_name,
                        filename,
                        truncate
                    );
                }
            } else {
                _logger = spdlog::basic_logger_mt(logger_name, filename, truncate);
            }
        } else {
            if (async_mode) {
                if (g_async_overflow_policy == spdlog::async_overflow_policy::overrun_oldest) {
                    _logger =
                        spdlog::basic_logger_st<async_factory_nb>(logger_name, filename, truncate);
                } else {
                    _logger = spdlog::basic_logger_st<spdlog::async_factory>(
                        logger_name,
                        filename,
                        truncate
                    );
                }
            } else {
                _logger = spdlog::basic_logger_st(logger_name, filename, truncate);
            }
        }
    }
};

class RotatingLogger: public Logger {
public:
    RotatingLogger(
        const std::string& logger_name,
        const std::string& filename,
        bool multithreaded,
        size_t max_file_size,
        size_t max_files,
        bool async_mode = g_async_mode_on
    ):
        Logger(logger_name, async_mode) {
        if (multithreaded) {
            if (async_mode) {
                if (g_async_overflow_policy == spdlog::async_overflow_policy::overrun_oldest) {
                    _logger = spdlog::rotating_logger_mt<async_factory_nb>(
                        logger_name,
                        filename,
                        max_file_size,
                        max_files
                    );
                } else {
                    _logger = spdlog::rotating_logger_mt<spdlog::async_factory>(
                        logger_name,
                        filename,
                        max_file_size,
                        max_files
                    );
                }
            } else {
                _logger =
                    spdlog::rotating_logger_mt(logger_name, filename, max_file_size, max_files);
            }
        } else {
            if (async_mode) {
                if (g_async_overflow_policy == spdlog::async_overflow_policy::overrun_oldest) {
                    _logger = spdlog::rotating_logger_st<async_factory_nb>(
                        logger_name,
                        filename,
                        max_file_size,
                        max_files
                    );
                } else {
                    _logger = spdlog::rotating_logger_st<spdlog::async_factory>(
                        logger_name,
                        filename,
                        max_file_size,
                        max_files
                    );
                }
            } else {
                _logger =
                    spdlog::rotating_logger_st(logger_name, filename, max_file_size, max_files);
            }
        }
    }
};

class DailyLogger: public Logger {
public:
    DailyLogger(
        const std::string& logger_name,
        const std::string& filename,
        bool multithreaded = false,
        int hour = 0,
        int minute = 0,
        bool async_mode = g_async_mode_on
    ):
        Logger(logger_name, async_mode) {
        if (multithreaded) {
            if (async_mode) {
                if (g_async_overflow_policy == spdlog::async_overflow_policy::overrun_oldest) {
                    _logger = spdlog::daily_logger_mt<async_factory_nb>(
                        logger_name,
                        filename,
                        hour,
                        minute
                    );
                } else {
                    _logger = spdlog::daily_logger_mt<spdlog::async_factory>(
                        logger_name,
                        filename,
                        hour,
                        minute
                    );
                }
            } else {
                _logger = spdlog::daily_logger_mt(logger_name, filename, hour, minute);
            }
        } else {
            if (async_mode) {
                if (g_async_overflow_policy == spdlog::async_overflow_policy::overrun_oldest) {
                    _logger = spdlog::daily_logger_st<async_factory_nb>(
                        logger_name,
                        filename,
                        hour,
                        minute
                    );
                } else {
                    _logger = spdlog::daily_logger_st<spdlog::async_factory>(
                        logger_name,
                        filename,
                        hour,
                        minute
                    );
                }
            } else {
                _logger = spdlog::daily_logger_st(logger_name, filename, hour, minute);
            }
        }
    }
};

class AsyncOverflowPolicy {
public:
    const static int block { (int)spdlog::async_overflow_policy::block };
    const static int overrun_oldest { (int)spdlog::async_overflow_policy::overrun_oldest };
};

void set_async_mode(
    size_t queue_size = spdlog::details::default_async_q_size,
    size_t thread_count = 1,
    int async_overflow_policy = AsyncOverflowPolicy::block
) {
    // Initialize/replace the global spdlog thread pool.
    auto& registry = spdlog::details::registry::instance();
    std::lock_guard<std::recursive_mutex> tp_lck(registry.tp_mutex());
    auto tp = std::make_shared<spdlog::details::thread_pool>(queue_size, thread_count);
    registry.set_tp(tp);

    g_async_overflow_policy = static_cast<spdlog::async_overflow_policy>(async_overflow_policy);
    g_async_mode_on = true;
}

std::shared_ptr<spdlog::details::thread_pool> thread_pool() {
    auto& registry = spdlog::details::registry::instance();
    std::lock_guard<std::recursive_mutex> tp_lck(registry.tp_mutex());
    auto tp = registry.get_tp();
    if (tp == nullptr) {
        set_async_mode();
        auto tp = registry.get_tp();
    }

    return tp;
}

class SinkLogger: public Logger {
public:
    SinkLogger(const std::string& logger_name, const Sink& sink, bool async_mode = g_async_mode_on):
        Logger(logger_name, async_mode) {
        if (async_mode) {
            _logger = std::make_shared<spdlog::async_logger>(
                logger_name,
                sink.get_sink(),
                thread_pool(),
                g_async_overflow_policy
            );
        } else {
            _logger = std::make_shared<spdlog::logger>(logger_name, sink.get_sink());
        }
    }
    SinkLogger(
        const std::string& logger_name,
        const std::vector<Sink>& sink_list,
        bool async_mode = g_async_mode_on
    ):
        Logger(logger_name, async_mode) {
        std::vector<spdlog::sink_ptr> sinks;
        for (auto sink: sink_list) {
            sinks.push_back(sink.get_sink());
        }

        if (async_mode) {
            _logger = std::make_shared<spdlog::async_logger>(
                logger_name,
                sinks.begin(),
                sinks.end(),
                thread_pool(),
                g_async_overflow_policy
            );
        } else {
            _logger = std::make_shared<spdlog::logger>(logger_name, sinks.begin(), sinks.end());
        }
    }
};

Logger get(const std::string& name) {
    Logger* logger = access_logger(name);
    if (logger != nullptr) {
        return *logger;
    } else {
        throw std::runtime_error(std::string("Logger name: " + name + " could not be found"));
    }
}

void drop(const std::string& name) {
    remove_logger(name);
    spdlog::drop(name);
}

void drop_all() {
    remove_logger_all();
    spdlog::drop_all();
}

} // namespace pluto