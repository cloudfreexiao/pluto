#pragma once

#include "quill/Backend.h"
#include "quill/Frontend.h"
#include "quill/LogMacros.h"
#include "quill/Logger.h"
#include "quill/sinks/ConsoleSink.h"


namespace pluto {

class Quill {
public:
    Quill() {}

    ~Quill() {
        // quill::Backend::start();
        quill::Frontend::remove_logger(logger_);
    }

private:
    quill::Logger* logger_ = nullptr;
};

} // namespace pluto